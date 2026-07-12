// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as cors;

import '../models/provider_model.dart';
import '../models/model_info.dart';
import '../models/ip_rule.dart';
import 'protocol_converter.dart';

/// 内部HTTP服务器 - 对外暴露OpenAI兼容API
class ServerService {
  HttpServer? _server;
  bool _running = false;
  final int port;
  List<LLMProvider> _providers = [];
  List<ModelInfo> _models = [];
  List<IpRule> _ipRules = [];
  String _apiKey = ''; // 对外访问密钥，空 = 不校验
  bool _restrictToWhitelist = true; // 严格白名单：无规则时除本机外全部拒绝
  bool _trustProxyHeaders = false; // 是否信任 X-Forwarded-For / X-Real-IP

  /// 请求超时时间（秒）
  static const int _requestTimeoutSeconds = 120;

  /// 请求统计回调
  void Function(String ip, String model, int statusCode)? onRequest;

  ServerService({this.port = 9998});

  bool get isRunning => _running;

  void updateData({
    required List<LLMProvider> providers,
    required List<ModelInfo> models,
    required List<IpRule> ipRules,
    String apiKey = '',
    bool restrictToWhitelist = true,
    bool trustProxyHeaders = false,
  }) {
    _providers = providers;
    _models = models;
    _ipRules = ipRules;
    _apiKey = apiKey;
    _restrictToWhitelist = restrictToWhitelist;
    _trustProxyHeaders = trustProxyHeaders;
  }

  /// 校验请求携带的访问密钥。
  /// 兼容 OpenAI（`Authorization: Bearer key`）与 Claude（`x-api-key: key`）两种头。
  /// 未配置密钥时恒返回 true。
  bool _checkApiKey(shelf.Request request) {
    if (_apiKey.isEmpty) return true;
    final auth = request.headers['authorization'] ??
        request.headers['Authorization'];
    if (auth != null) {
      final token = auth.startsWith('Bearer ') ? auth.substring(7) : auth;
      if (token.trim() == _apiKey) return true;
    }
    final xApiKey =
        request.headers['x-api-key'] ?? request.headers['X-Api-Key'];
    if (xApiKey != null && xApiKey.trim() == _apiKey) return true;
    return false;
  }

  Future<void> start() async {
    if (_running) return;

    final router = shelf_router.Router();

    // 模型列表端点
    router.get('/v1/models', _handleListModels);
    router.get('/models', _handleListModels);

    // Chat Completions（OpenAI 入口）
    router.post('/v1/chat/completions', _handleChatCompletions);
    router.post('/chat/completions', _handleChatCompletions);

    // Messages（Claude 入口）
    router.post('/v1/messages', _handleClaudeMessages);
    router.post('/messages', _handleClaudeMessages);

    // 健康检查
    router.get('/health', _handleHealth);
    router.get('/', _handleHealth);

    // CORS 中间件：仅注入跨域相关头，不要强加 Content-Type，
    // 否则会覆盖流式响应的 text/event-stream，导致客户端解析失败。
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(cors.corsHeaders(
          headers: {
            cors.ACCESS_CONTROL_ALLOW_ORIGIN: '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers':
                'Origin, Content-Type, Authorization, x-api-key, anthropic-version',
          },
        ))
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _running = true;
  }

  Future<void> stop() async {
    if (!_running) return;
    await _server?.close(force: true);
    _server = null;
    _running = false;
  }

  // ============= 处理器 =============

  Future<shelf.Response> _handleListModels(shelf.Request request) async {
    final clientIp = _getClientIp(request);
    if (!_checkIpAccess(clientIp)) {
      return shelf.Response.forbidden(
        jsonEncode({'error': 'IP not in whitelist: $clientIp'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (!_checkApiKey(request)) {
      return shelf.Response(401,
          body: jsonEncode({
            'error': {
              'message': 'Invalid API key',
              'type': 'authentication_error',
              'code': 'invalid_api_key',
            }
          }),
          headers: {'Content-Type': 'application/json'});
    }

    // 列出该 IP 允许的全部启用模型（不按对外协议过滤）。
    // /v1/models 只是模型目录，OpenAI 与 Claude 客户端都用它发现模型；
    // 具体协议是否匹配由 /v1/chat/completions 和 /v1/messages 各自强制校验。
    final allowedModels = _getAllowedModels(clientIp);

    final modelsList = allowedModels.map((m) {
      final provider = _findProvider(m.providerId);
      return {
        'id': m.name,
        'object': 'model',
        'created': m.createdAt.millisecondsSinceEpoch ~/ 1000,
        'owned_by': provider?.name ?? 'unknown',
      };
    }).toList();

    return shelf.Response.ok(
      jsonEncode({'object': 'list', 'data': modelsList}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<shelf.Response> _handleChatCompletions(
      shelf.Request request) async {
    final clientIp = _getClientIp(request);

    // 检查白名单
    if (!_checkIpAccess(clientIp)) {
      return shelf.Response.forbidden(
        jsonEncode({
          'error': {
            'message': 'IP not authorized: $clientIp',
            'type': 'authentication_error',
            'code': 'ip_not_whitelisted',
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 校验访问密钥
    if (!_checkApiKey(request)) {
      return shelf.Response(401,
          body: jsonEncode({
            'error': {
              'message': 'Invalid API key',
              'type': 'authentication_error',
              'code': 'invalid_api_key',
            }
          }),
          headers: {'Content-Type': 'application/json'});
    }

    // 解析请求体
    Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      print('[Switches] JSON parse error: $e');
      return shelf.Response(400,
          body: jsonEncode({'error': 'Invalid JSON'}),
          headers: {'Content-Type': 'application/json'});
    }

    final requestedModel = body['model']?.toString() ?? '';
    final stream = body['stream'] == true;

    // 查找模型
    final modelInfo = _findModelByName(requestedModel);
    if (modelInfo == null) {
      return shelf.Response(404,
          body: jsonEncode({
            'error': {
              'message': 'Model not found: $requestedModel',
              'type': 'not_found'
            }
          }),
          headers: {'Content-Type': 'application/json'});
    }

    // 该模型未配置为对外 OpenAI 协议
    if (modelInfo.exposedProtocol != 'openai') {
      return shelf.Response(404,
          body: jsonEncode({
            'error': {
              'message':
                  'Model "$requestedModel" is not exposed as OpenAI protocol. '
                      'Use the Claude endpoint /v1/messages instead.',
              'type': 'not_found'
            }
          }),
          headers: {'Content-Type': 'application/json'});
    }

    // 检查该IP是否允许此模型
    if (!_checkIpModelAccess(clientIp, modelInfo.id)) {
      return shelf.Response.forbidden(
        jsonEncode({
          'error': {
            'message': 'Model not allowed for this IP: $requestedModel',
            'type': 'forbidden',
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final provider = _findProvider(modelInfo.providerId);
    if (provider == null || !provider.enabled || provider.apiKey.isEmpty) {
      return shelf.Response(500,
          body: jsonEncode({
            'error': {
              'message': 'Provider not configured for $requestedModel',
              'type': 'config_error'
            }
          }),
          headers: {'Content-Type': 'application/json'});
    }

    try {
      return await _dispatchUpstream(
          provider, modelInfo, body, stream, clientIp, requestedModel);
    } catch (e) {
      print('[Switches] handleChatCompletions error: $e');
      onRequest?.call(clientIp, requestedModel, 500);
      return shelf.Response(500,
          body: jsonEncode({
            'error': {'message': e.toString(), 'type': 'proxy_error'}
          }),
          headers: {'Content-Type': 'application/json'});
    }
  }

  /// 统一上游分发：无论入口协议如何，都以 OpenAI 格式(IR) 调上游并返回 OpenAI 响应
  Future<shelf.Response> _dispatchUpstream(
    LLMProvider provider,
    ModelInfo modelInfo,
    Map<String, dynamic> body,
    bool stream,
    String clientIp,
    String requestedModel,
  ) async {
    if (provider.type == 'openai') {
      return _proxyOpenAI(provider, body, stream, clientIp, requestedModel);
    } else if (provider.type == 'gemini') {
      return _proxyGemini(
          provider, modelInfo, body, stream, clientIp, requestedModel);
    } else if (provider.type == 'claude') {
      return _proxyClaude(
          provider, modelInfo, body, stream, clientIp, requestedModel);
    }
    return shelf.Response(500,
        body: jsonEncode({'error': 'Unsupported provider'}),
        headers: {'Content-Type': 'application/json'});
  }

  /// Claude 入口 /v1/messages：Claude 请求 → OpenAI IR → 上游 → Claude 响应
  Future<shelf.Response> _handleClaudeMessages(shelf.Request request) async {
    final clientIp = _getClientIp(request);

    if (!_checkIpAccess(clientIp)) {
      return shelf.Response.forbidden(
        jsonEncode(ProtocolConverter.claudeErrorResponse(
            'IP not authorized: $clientIp')),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (!_checkApiKey(request)) {
      return shelf.Response(401,
          body: jsonEncode(
              ProtocolConverter.claudeErrorResponse('Invalid API key')),
          headers: {'Content-Type': 'application/json'});
    }

    Map<String, dynamic> claudeBody;
    try {
      claudeBody =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      return shelf.Response(400,
          body: jsonEncode(
              ProtocolConverter.claudeErrorResponse('Invalid JSON')),
          headers: {'Content-Type': 'application/json'});
    }

    final requestedModel = claudeBody['model']?.toString() ?? '';
    final stream = claudeBody['stream'] == true;

    final modelInfo = _findModelByName(requestedModel);
    if (modelInfo == null) {
      return shelf.Response(404,
          body: jsonEncode(ProtocolConverter.claudeErrorResponse(
              'Model not found: $requestedModel')),
          headers: {'Content-Type': 'application/json'});
    }

    // 该模型未配置为对外 Claude 协议
    if (modelInfo.exposedProtocol != 'claude') {
      return shelf.Response(404,
          body: jsonEncode(ProtocolConverter.claudeErrorResponse(
              'Model "$requestedModel" is not exposed as Claude protocol. '
              'Use the OpenAI endpoint /v1/chat/completions instead.')),
          headers: {'Content-Type': 'application/json'});
    }

    if (!_checkIpModelAccess(clientIp, modelInfo.id)) {
      return shelf.Response.forbidden(
        jsonEncode(ProtocolConverter.claudeErrorResponse(
            'Model not allowed for this IP: $requestedModel')),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final provider = _findProvider(modelInfo.providerId);
    if (provider == null || !provider.enabled || provider.apiKey.isEmpty) {
      return shelf.Response(500,
          body: jsonEncode(ProtocolConverter.claudeErrorResponse(
              'Provider not configured for $requestedModel')),
          headers: {'Content-Type': 'application/json'});
    }

    // Claude 请求 → OpenAI IR
    final openaiBody = ProtocolConverter.claudeRequestToOpenAI(claudeBody);

    try {
      final upstream = await _dispatchUpstream(
          provider, modelInfo, openaiBody, stream, clientIp, requestedModel);

      // 上游返回的是 OpenAI 格式，需再编码为 Claude 格式
      if (stream) {
        final encoder = ClaudeSSEEncoder(requestedModel);
        // 转换后重新编码为字节流（shelf 只接受 Stream<List<int>>，
        // 否则运行时会抛类型错误导致连接被重置：UND_ERR_SOCKET）。
        // 用 LineSplitter 按行切分，正确处理跨 chunk 被拆散的 SSE 行。
        final transformed = upstream
            .read()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .transform(StreamTransformer<String, String>.fromHandlers(
          handleData: (line, sink) {
            if (line.startsWith('data: ')) {
              final payload = line.substring(6).trim();
              final out = encoder.handleOpenAIData(payload);
              if (out.isNotEmpty) sink.add(out);
            }
          },
          handleDone: (sink) {
            final tail = encoder.finish();
            if (tail.isNotEmpty) sink.add(tail);
            sink.close();
          },
        )).transform(utf8.encoder);
        return shelf.Response.ok(
          transformed,
          headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        );
      }

      // 非流式：读取 OpenAI JSON 响应，转换为 Claude 响应
      final bodyStr = await upstream.readAsString();
      if (upstream.statusCode != 200) {
        return shelf.Response(upstream.statusCode,
            body: bodyStr, headers: {'Content-Type': 'application/json'});
      }
      final openaiResp = jsonDecode(bodyStr) as Map<String, dynamic>;
      final claudeResp = ProtocolConverter.openaiToClaudeResponse(
          openaiResp, requestedModel);
      return shelf.Response.ok(
        jsonEncode(claudeResp),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[Switches] handleClaudeMessages error: $e');
      onRequest?.call(clientIp, requestedModel, 500);
      return shelf.Response(500,
          body: jsonEncode(
              ProtocolConverter.claudeErrorResponse(e.toString())),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<shelf.Response> _handleHealth(shelf.Request request) async {
    final clientIp = _getClientIp(request);

    // 未授权 IP 只返回最小状态，不泄露服务商/模型/规则等内部信息
    if (!_checkIpAccess(clientIp)) {
      return shelf.Response.forbidden(
        jsonEncode({
          'status': 'forbidden',
          'service': 'Switches',
          'client_ip': clientIp,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final providers = _providers.where((p) => p.enabled).length;
    final models = _models.where((m) => m.enabled).length;
    return shelf.Response.ok(
      jsonEncode({
        'status': 'ok',
        'service': 'Switches',
        'version': '1.0.0',
        'port': port,
        'providers': providers,
        'models': models,
        'ip_rules': _ipRules.length,
        'client_ip': clientIp,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ============= 代理转发 =============

  /// 归一化上游 baseUrl：剥离结尾斜杠及常见 API 版本后缀，
  /// 避免与后续拼接的 /v1/... 路径重复（如 baseUrl 已含 /v1 时产生 /v1/v1）。
  /// 必须与 ProviderService._normalizeBase 保持一致，否则会出现
  /// “模型能检测（走归一化）但请求失败（未归一化）”的错配。
  String _normalizeBase(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    for (final suffix in ['/v1beta', '/v1', '/openai']) {
      if (url.toLowerCase().endsWith(suffix)) {
        url = url.substring(0, url.length - suffix.length);
        break;
      }
    }
    return url;
  }

  /// OpenAI直通代理（带超时）
  Future<shelf.Response> _proxyOpenAI(
    LLMProvider provider,
    Map<String, dynamic> body,
    bool stream,
    String clientIp,
    String modelName,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: _requestTimeoutSeconds);
    try {
      final base = _normalizeBase(provider.baseUrl);
      final uri = Uri.parse('$base/v1/chat/completions');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer ${provider.apiKey}');
      request.headers.set('Content-Type', 'application/json');
      // 用 UTF-8 字节写入，避免默认 latin1 编码无法处理中文等非 ASCII 内容
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(
            Duration(seconds: _requestTimeoutSeconds),
          );

      if (stream) {
        onRequest?.call(clientIp, modelName, 200);
        // 上游已是 OpenAI SSE 格式，直接透传原始字节流
        // （不要 utf8.decoder 转成 Stream<String>，shelf 只接受 Stream<List<int>>）
        return shelf.Response.ok(
          response,
          headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        );
      }

      final respBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(seconds: _requestTimeoutSeconds));
      onRequest?.call(clientIp, modelName, response.statusCode);
      return shelf.Response(
        response.statusCode,
        body: respBody,
        headers: {'Content-Type': 'application/json'},
      );
    } on TimeoutException {
      onRequest?.call(clientIp, modelName, 504);
      return shelf.Response(504,
          body: jsonEncode({
            'error': {
              'message': 'Upstream timeout: OpenAI',
              'type': 'timeout'
            }
          }),
          headers: {'Content-Type': 'application/json'});
    } finally {
      client.close();
    }
  }

  /// Gemini代理
  Future<shelf.Response> _proxyGemini(
    LLMProvider provider,
    ModelInfo modelInfo,
    Map<String, dynamic> body,
    bool stream,
    String clientIp,
    String modelName,
  ) async {
    final geminiBody =
        ProtocolConverter.openaiToGemini(body, modelInfo.name);

    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: _requestTimeoutSeconds);
    try {
      final base = _normalizeBase(provider.baseUrl);
      final url = stream
          ? '$base/v1beta/models/${modelInfo.name}:streamGenerateContent?alt=sse&key=${Uri.encodeComponent(provider.apiKey)}'
          : '$base/v1beta/models/${modelInfo.name}:generateContent?key=${Uri.encodeComponent(provider.apiKey)}';

      final uri = Uri.parse(url);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      // 用 UTF-8 字节写入，避免默认 latin1 编码无法处理中文等非 ASCII 内容
      request.add(utf8.encode(jsonEncode(geminiBody)));

      final response = await request.close().timeout(
            Duration(seconds: _requestTimeoutSeconds),
          );

      if (stream) {
        onRequest?.call(clientIp, modelName, 200);
        // 转换SSE流，转换后重新编码为字节流（shelf 只接受 Stream<List<int>>）
        final transformed = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .transform(
          StreamTransformer<String, String>.fromHandlers(
            handleData: (line, sink) {
              if (line.startsWith('data: ')) {
                final jsonStr = line.substring(6).trim();
                if (jsonStr == '[DONE]') {
                  sink.add('data: [DONE]\n\n');
                } else {
                  final converted =
                      ProtocolConverter.geminiSSEToOpenAI(jsonStr, modelName);
                  if (converted.isNotEmpty) {
                    sink.add(converted);
                  }
                }
              }
            },
          ),
        ).transform(utf8.encoder);

        return shelf.Response.ok(
          transformed,
          headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        );
      }

      final respBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(seconds: _requestTimeoutSeconds));
      final geminiResp = jsonDecode(respBody) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        onRequest?.call(clientIp, modelName, response.statusCode);
        return shelf.Response(
          response.statusCode,
          body: jsonEncode(
              {'error': geminiResp['error'] ?? 'Gemini API error'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final openaiResp =
          ProtocolConverter.geminiToOpenAI(geminiResp, modelName);
      onRequest?.call(clientIp, modelName, 200);
      return shelf.Response.ok(
        jsonEncode(openaiResp),
        headers: {'Content-Type': 'application/json'},
      );
    } on TimeoutException {
      onRequest?.call(clientIp, modelName, 504);
      return shelf.Response(504,
          body: jsonEncode({
            'error': {
              'message': 'Upstream timeout: Gemini',
              'type': 'timeout'
            }
          }),
          headers: {'Content-Type': 'application/json'});
    } finally {
      client.close();
    }
  }

  /// Claude代理
  Future<shelf.Response> _proxyClaude(
    LLMProvider provider,
    ModelInfo modelInfo,
    Map<String, dynamic> body,
    bool stream,
    String clientIp,
    String modelName,
  ) async {
    final claudeBody =
        ProtocolConverter.openaiToClaude(body, modelInfo.name);
    if (stream) {
      claudeBody['stream'] = true;
    }

    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: _requestTimeoutSeconds);
    try {
      final base = _normalizeBase(provider.baseUrl);
      final uri = Uri.parse('$base/v1/messages');
      final request = await client.postUrl(uri);
      request.headers.set('x-api-key', provider.apiKey);
      request.headers.set('anthropic-version', '2023-06-01');
      request.headers.set('Content-Type', 'application/json');
      // 用 UTF-8 字节写入，避免默认 latin1 编码无法处理中文等非 ASCII 内容
      request.add(utf8.encode(jsonEncode(claudeBody)));

      final response = await request.close().timeout(
            Duration(seconds: _requestTimeoutSeconds),
          );

      if (stream) {
        onRequest?.call(clientIp, modelName, 200);
        // 转换后重新编码为字节流（shelf 只接受 Stream<List<int>>）
        final transformed = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .transform(
          StreamTransformer<String, String>.fromHandlers(
            handleData: (line, sink) {
              if (line.startsWith('data: ')) {
                final jsonStr = line.substring(6).trim();
                final converted =
                    ProtocolConverter.claudeSSEToOpenAI(jsonStr, modelName);
                if (converted.isNotEmpty) {
                  sink.add(converted);
                }
              }
            },
          ),
        ).transform(utf8.encoder);

        return shelf.Response.ok(
          transformed,
          headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        );
      }

      final respBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(seconds: _requestTimeoutSeconds));
      final claudeResp = jsonDecode(respBody) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        onRequest?.call(clientIp, modelName, response.statusCode);
        return shelf.Response(
          response.statusCode,
          body: jsonEncode(
              {'error': claudeResp['error'] ?? 'Claude API error'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final openaiResp =
          ProtocolConverter.claudeToOpenAI(claudeResp, modelName);
      onRequest?.call(clientIp, modelName, 200);
      return shelf.Response.ok(
        jsonEncode(openaiResp),
        headers: {'Content-Type': 'application/json'},
      );
    } on TimeoutException {
      onRequest?.call(clientIp, modelName, 504);
      return shelf.Response(504,
          body: jsonEncode({
            'error': {
              'message': 'Upstream timeout: Claude',
              'type': 'timeout'
            }
          }),
          headers: {'Content-Type': 'application/json'});
    } finally {
      client.close();
    }
  }

  // ============= IP白名单检查 =============

  /// 获取客户端真实IP。
  ///
  /// 安全要点：默认 **只信任真实 socket 连接地址**（connection_info）。
  /// X-Forwarded-For / X-Real-IP 这类请求头是客户端可任意伪造的——如果无条件信任，
  /// 远程攻击者只需发送 `X-Forwarded-For: 127.0.0.1` 就能伪装成本机、绕过整个白名单。
  /// 因此这两个头仅在用户显式开启 trustProxyHeaders（部署在可信反代之后）时才采用。
  String _getClientIp(shelf.Request request) {
    // 真实连接地址（直连场景的唯一可信来源）
    final socketIp = _socketIp(request);

    if (_trustProxyHeaders) {
      // 仅当明确信任反代时，才采用转发头
      final forwarded = request.headers['x-forwarded-for'];
      if (forwarded != null && forwarded.isNotEmpty) {
        return forwarded.split(',').first.trim();
      }
      final realIp = request.headers['x-real-ip'];
      if (realIp != null && realIp.isNotEmpty) {
        return realIp.trim();
      }
    }

    return socketIp ?? '127.0.0.1';
  }

  /// 从 shelf 连接信息读取真实 socket 远端地址
  String? _socketIp(shelf.Request request) {
    try {
      final connInfo =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      if (connInfo != null) {
        final addr = connInfo.remoteAddress;
        if (addr.type == InternetAddressType.IPv4 ||
            addr.type == InternetAddressType.IPv6) {
          return addr.address;
        }
      }
    } catch (e) {
      print('[Switches] getClientIp connection_info: $e');
    }
    return null;
  }

  /// 是否为本机地址（含 IPv4、IPv6 回环及 IPv4-mapped IPv6）
  bool _isLocalhost(String ip) {
    return ip == '127.0.0.1' ||
        ip == 'localhost' ||
        ip == '::1' ||
        ip == '::ffff:127.0.0.1' ||
        ip.startsWith('127.');
  }

  bool _checkIpAccess(String ip) {
    // 本地IP始终允许
    if (_isLocalhost(ip)) return true;

    // 检查白名单
    final enabledRules = _ipRules.where((r) => r.enabled).toList();
    if (enabledRules.isEmpty) {
      // 无规则时：严格模式拒绝远程；宽松模式（默认）放行
      return !_restrictToWhitelist;
    }

    // 有规则：仅命中白名单的 IP 可访问（无论宽松/严格）
    return enabledRules.any((rule) => _ipMatches(ip, rule.ipAddress));
  }

  bool _checkIpModelAccess(String ip, String modelId) {
    // 本地始终全权限
    if (_isLocalhost(ip)) return true;

    final enabledRules = _ipRules.where((r) => r.enabled).toList();
    if (enabledRules.isEmpty) {
      // 无规则：严格模式此前已在 _checkIpAccess 拦截；宽松模式放行全部模型
      return !_restrictToWhitelist;
    }

    // 命中的第一条规则决定该模型是否放行
    for (final rule in enabledRules) {
      if (_ipMatches(ip, rule.ipAddress)) {
        return rule.allowsModel(modelId);
      }
    }
    // 有规则但未命中：拒绝（与 _checkIpAccess 一致）
    return false;
  }

  bool _ipMatches(String ip, String rule) {
    // 精确匹配
    if (rule == ip) return true;
    // 通配
    if (rule == '*') return true;
    // CIDR
    if (rule.contains('/')) {
      return _cidrMatch(ip, rule);
    }
    return false;
  }

  /// 完整的CIDR匹配
  bool _cidrMatch(String ip, String cidr) {
    try {
      final parts = cidr.split('/');
      if (parts.length != 2) return false;

      final networkAddr = InternetAddress(parts[0]);
      final prefixLength = int.parse(parts[1]);
      final clientAddr = InternetAddress(ip);

      // 类型必须一致
      if (networkAddr.type != clientAddr.type) return false;

      final networkBytes = networkAddr.rawAddress;
      final clientBytes = clientAddr.rawAddress;

      if (networkBytes.length != clientBytes.length) return false;

      // 计算需要比较的完整字节数
      final fullBytes = prefixLength ~/ 8;
      final remainingBits = prefixLength % 8;

      // 比较完整字节
      for (var i = 0; i < fullBytes; i++) {
        if (networkBytes[i] != clientBytes[i]) return false;
      }

      // 比较剩余位
      if (remainingBits > 0 && fullBytes < networkBytes.length) {
        final mask = (0xFF << (8 - remainingBits)) & 0xFF;
        if ((networkBytes[fullBytes] & mask) !=
            (clientBytes[fullBytes] & mask)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('[Switches] CIDR match: $e');
      return false;
    }
  }

  List<ModelInfo> _getAllowedModels(String ip) {
    if (_isLocalhost(ip)) {
      return _models.where((m) => m.enabled).toList();
    }

    final enabledRules = _ipRules.where((r) => r.enabled).toList();
    if (enabledRules.isEmpty) {
      // 无规则：严格模式返回空（不放行）；宽松模式返回全部
      return _restrictToWhitelist
          ? <ModelInfo>[]
          : _models.where((m) => m.enabled).toList();
    }

    // 是否命中了任一规则
    var matchedAny = false;
    final allowedIds = <String>{};
    for (final rule in enabledRules) {
      if (_ipMatches(ip, rule.ipAddress)) {
        matchedAny = true;
        if (rule.allowAllModels) {
          return _models.where((m) => m.enabled).toList();
        }
        allowedIds.addAll(rule.allowedModelIds);
      }
    }

    // 未命中任何规则：拒绝（返回空），不再默认放行
    if (!matchedAny) return <ModelInfo>[];

    return _models
        .where((m) => m.enabled && allowedIds.contains(m.id))
        .toList();
  }

  ModelInfo? _findModelByName(String name) {
    try {
      return _models.firstWhere(
        (m) => m.name == name && m.enabled,
      );
    } catch (e) {
      print('[Switches] findModelByName: $e');
      return null;
    }
  }

  LLMProvider? _findProvider(String id) {
    try {
      return _providers.firstWhere((p) => p.id == id);
    } catch (e) {
      print('[Switches] findProvider: $e');
      return null;
    }
  }
}
