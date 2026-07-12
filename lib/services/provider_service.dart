// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/provider_model.dart';
import '../models/model_info.dart';
import '../config/constants.dart';

/// 服务商管理服务 - 负责与各LLM服务商API通信
class ProviderService {
  /// 规范化 baseUrl：去掉尾部斜杠，并剥离用户误加的 /v1、/v1beta 后缀，
  /// 使各服务商端点拼接保持一致，避免出现 /v1/v1/models 这类错误路径。
  static String _normalizeBase(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // 剥离常见 API 版本后缀（大小写不敏感）
    for (final suffix in ['/v1beta', '/v1', '/openai']) {
      if (url.toLowerCase().endsWith(suffix)) {
        url = url.substring(0, url.length - suffix.length);
        break;
      }
    }
    return url;
  }

  /// 截断响应体，避免错误提示过长
  static String _briefBody(String body) {
    final b = body.trim().replaceAll('\n', ' ');
    return b.length > 200 ? '${b.substring(0, 200)}...' : b;
  }

  /// 从服务商获取可用模型列表
  static Future<List<ModelInfo>> fetchModels(LLMProvider provider) async {
    switch (provider.type) {
      case 'openai':
        return _fetchOpenAIModels(provider);
      case 'gemini':
        return _fetchGeminiModels(provider);
      case 'claude':
        return _fetchClaudeModels(provider);
      default:
        throw Exception('不支持的服务商类型: ${provider.type}');
    }
  }

  /// 测试服务商连接
  static Future<bool> testConnection(LLMProvider provider) async {
    try {
      final base = _normalizeBase(provider.baseUrl);
      switch (provider.type) {
        case 'openai':
          final resp = await http.get(
            Uri.parse('$base/v1/models'),
            headers: {
              'Authorization': 'Bearer ${provider.apiKey}',
            },
          ).timeout(const Duration(seconds: 20));
          return resp.statusCode == 200;
        case 'gemini':
          final resp = await http.get(
            Uri.parse(
                '$base/v1beta/models?key=${Uri.encodeComponent(provider.apiKey)}'),
          ).timeout(const Duration(seconds: 20));
          return resp.statusCode == 200;
        case 'claude':
          // Claude没有公开的list models端点，用轻量请求测试
          return provider.apiKey.isNotEmpty;
        default:
          return false;
      }
    } catch (e) {
      print('[Switches] testConnection error: $e');
      return false;
    }
  }

  static Future<List<ModelInfo>> _fetchOpenAIModels(LLMProvider provider) async {
    final base = _normalizeBase(provider.baseUrl);
    final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse('$base/v1/models'),
        headers: {'Authorization': 'Bearer ${provider.apiKey}'},
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('连接 ${provider.name} 失败：$e');
    }
    if (resp.statusCode != 200) {
      throw Exception(
          '获取模型失败 (HTTP ${resp.statusCode})：${_briefBody(resp.body)}');
    }
    final data = jsonDecode(resp.body);
    final List models = data['data'] ?? [];
    // 保留所有 chat/language 模型，仅过滤纯工具类模型
    final chatModels = models.where((m) {
      final id = m['id'].toString();
      // 排除明显的非对话模型
      if (id.startsWith('dall-e')) return false;
      if (id.startsWith('tts-')) return false;
      if (id.startsWith('whisper-')) return false;
      if (id.contains('embedding')) return false;
      if (id.contains('moderation')) return false;
      return true;
    });

    // 安全网：过滤后为空但 API 确实返回了模型 → 全量返回
    if (chatModels.isEmpty && models.isNotEmpty) {
      print('[Switches] OpenAI filter returned 0 models, falling back to raw list (${models.length} total)');
      return models.map((m) {
        final name = m['id'].toString();
        return ModelInfo(
          providerId: provider.id,
          name: name,
          displayName: name,
          capabilities: _inferOpenAICapabilities(name),
        );
      }).toList();
    }

    return chatModels
        .map((m) {
      final name = m['id'].toString();
      return ModelInfo(
        providerId: provider.id,
        name: name,
        displayName: name,
        capabilities: _inferOpenAICapabilities(name),
      );
    }).toList();
  }

  static Future<List<ModelInfo>> _fetchGeminiModels(
      LLMProvider provider) async {
    final base = _normalizeBase(provider.baseUrl);
    final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(
            '$base/v1beta/models?key=${Uri.encodeComponent(provider.apiKey)}'),
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('连接 ${provider.name} 失败：$e');
    }
    if (resp.statusCode != 200) {
      throw Exception(
          '获取模型失败 (HTTP ${resp.statusCode})：${_briefBody(resp.body)}');
    }
    final data = jsonDecode(resp.body);
    final List models = data['models'] ?? [];
    final geminiModels = models
        .where((m) {
          final name = m['name'].toString();
          // 保留 Gemini 系列及兼容服务商的模型，排除系统模型
          if (name.contains('system-') || name.contains('token-')) return false;
          return true;
        })
        .map((m) {
      final fullName = m['name'].toString();
      final name = fullName.replaceAll('models/', '');
      final desc = (m['description'] as String? ?? '').toLowerCase();
      return ModelInfo(
        providerId: provider.id,
        name: name,
        displayName: m['displayName']?.toString() ?? name,
        capabilities: _inferGeminiCapabilities(desc, fullName),
      );
    }).toList();

    // 安全网
    if (geminiModels.isEmpty && models.isNotEmpty) {
      print('[Switches] Gemini filter returned 0, falling back (${models.length} total)');
      return models.map((m) {
        final fullName = m['name'].toString();
        final name = fullName.replaceAll('models/', '');
        return ModelInfo(
          providerId: provider.id,
          name: name,
          displayName: m['displayName']?.toString() ?? name,
          capabilities: _inferGeminiCapabilities(
              (m['description'] as String? ?? '').toLowerCase(), fullName),
        );
      }).toList();
    }

    return geminiModels;
  }

  static Future<List<ModelInfo>> _fetchClaudeModels(
      LLMProvider provider) async {
    // Claude没有公开的list models API，返回预设列表
    return _presetClaudeModels(provider.id);
  }

  static List<ModelInfo> _presetClaudeModels(String providerId) {
    return [
      ModelInfo(
        providerId: providerId,
        name: 'claude-sonnet-4-20250514',
        displayName: 'Claude Sonnet 4',
        capabilities: {
          ModelCapability.text,
          ModelCapability.imageInput,
          ModelCapability.functionCalling,
          ModelCapability.streaming,
        },
        maxTokens: 200000,
      ),
      ModelInfo(
        providerId: providerId,
        name: 'claude-opus-4-20250514',
        displayName: 'Claude Opus 4',
        capabilities: {
          ModelCapability.text,
          ModelCapability.imageInput,
          ModelCapability.functionCalling,
          ModelCapability.streaming,
          ModelCapability.reasoning,
        },
        maxTokens: 200000,
      ),
      ModelInfo(
        providerId: providerId,
        name: 'claude-haiku-3.5',
        displayName: 'Claude 3.5 Haiku',
        capabilities: {
          ModelCapability.text,
          ModelCapability.imageInput,
          ModelCapability.streaming,
        },
        maxTokens: 200000,
      ),
    ];
  }

  /// 通用「视觉/图片输入」关键词：任意服务商模型名命中即视为支持图片输入
  static const List<String> _visionKeywords = [
    'vision', 'vl', '-v-', '4v', 'visual', 'image', 'multimodal', 'mm',
    'pixtral', 'llava', 'omni', 'internvl', 'minicpm-v', 'cogvlm',
  ];

  /// 通用「音频输入」关键词
  static const List<String> _audioKeywords = [
    'audio', 'omni', 'voice', 'speech', 'asr',
  ];

  /// 通用「推理」关键词
  static const List<String> _reasoningKeywords = [
    'reason', 'reasoner', 'thinking', 'think', 'r1', 'qwq', 'qvq', '-o1', '-o3',
  ];

  /// 根据模型名称推断 OpenAI 兼容协议模型的能力
  ///
  /// 说明：OpenAI 的 /v1/models 端点不返回能力元数据，只能靠模型名推断。
  /// 这里用「通用关键词 + 厂商专用规则」双层匹配，尽量覆盖多模态能力。
  static Set<ModelCapability> _inferOpenAICapabilities(String rawName) {
    final name = rawName.toLowerCase();

    // 纯工具模型：直接返回专属能力，不叠加文本/流式
    if (name.contains('dall-e') || name.contains('dalle') ||
        name.contains('image-gen') || name.contains('flux') ||
        name.contains('stable-diffusion') || name.contains('sd3') ||
        name.contains('gpt-image')) {
      return {ModelCapability.imageOutput};
    }
    if (name.contains('tts') || name.startsWith('speech')) {
      return {ModelCapability.audioOutput};
    }
    if (name.contains('whisper') || name.contains('-asr')) {
      return {ModelCapability.audioInput};
    }
    if (name.contains('embedding') || name.contains('embed') ||
        name.contains('moderation') || name.contains('rerank')) {
      return {};
    }

    // 对话类模型：默认支持文本 + 流式，绝大多数支持函数调用
    final caps = <ModelCapability>{
      ModelCapability.text,
      ModelCapability.streaming,
      ModelCapability.functionCalling,
      ModelCapability.jsonMode,
    };

    // 通用视觉/音频/推理关键词
    if (_visionKeywords.any(name.contains)) {
      caps.add(ModelCapability.imageInput);
    }
    if (_audioKeywords.any(name.contains)) {
      caps.add(ModelCapability.audioInput);
    }
    if (_reasoningKeywords.any(name.contains)) {
      caps.add(ModelCapability.reasoning);
    }

    // ===== 厂商专用规则（补充通用关键词漏检的能力） =====

    // OpenAI 官方
    if (name.contains('gpt-4o') || name.contains('gpt-4.1') ||
        name.contains('gpt-5') || name.contains('gpt-4.5') ||
        name.contains('chatgpt-4o')) {
      caps.addAll({ModelCapability.imageInput, ModelCapability.audioInput});
    }
    if (name.contains('gpt-4-turbo') || name.contains('gpt-4-vision')) {
      caps.add(ModelCapability.imageInput);
    }
    if (name.contains('o1') || name.contains('o3') || name.contains('o4')) {
      caps.add(ModelCapability.reasoning);
    }

    // DeepSeek
    if (name.contains('deepseek-reasoner') || name.contains('deepseek-r1')) {
      caps.add(ModelCapability.reasoning);
    }

    // MiniMax（M1/M2/abab 系列多为多模态，视觉能力靠名称难判，默认标注）
    if (name.contains('minimax') || name.contains('abab') ||
        name.startsWith('m1') || name.startsWith('m2') ||
        name.contains('-m1') || name.contains('-m2')) {
      caps.add(ModelCapability.imageInput);
    }

    // Qwen / 通义千问
    if (name.contains('qwen')) {
      if (name.contains('omni')) {
        caps.addAll({ModelCapability.imageInput, ModelCapability.audioInput});
      }
    }

    // GLM / 智谱
    if (name.contains('glm')) {
      if (name.contains('4v') || name.contains('vision') || name.contains('-v')) {
        caps.add(ModelCapability.imageInput);
      }
    }

    // Grok（xAI，2+ 版本多支持视觉）
    if (name.contains('grok')) {
      if (!name.contains('grok-1') && !name.contains('grok-beta')) {
        caps.add(ModelCapability.imageInput);
      }
    }

    // Llama / Mistral 多模态变体
    if (name.contains('llama') &&
        (name.contains('vision') || name.contains('-90b') ||
            name.contains('-11b') || name.contains('scout') ||
            name.contains('maverick'))) {
      caps.add(ModelCapability.imageInput);
    }

    return caps;
  }

  /// 根据描述推断Gemini模型能力
  static Set<ModelCapability> _inferGeminiCapabilities(
      String desc, String name) {
    final caps = <ModelCapability>{ModelCapability.text, ModelCapability.streaming};
    if (desc.contains('image') || desc.contains('vision')) {
      caps.add(ModelCapability.imageInput);
    }
    if (desc.contains('audio') || desc.contains('speech')) {
      caps.add(ModelCapability.audioInput);
    }
    if (desc.contains('video')) {
      caps.add(ModelCapability.videoInput);
    }
    if (desc.contains('function') || desc.contains('tool')) {
      caps.add(ModelCapability.functionCalling);
    }
    if (name.contains('pro') || name.contains('ultra')) {
      caps.add(ModelCapability.reasoning);
    }
    if (name.contains('2.5') || name.contains('2.0')) {
      caps.add(ModelCapability.imageInput);
      caps.add(ModelCapability.functionCalling);
      caps.add(ModelCapability.jsonMode);
    }
    return caps;
  }
}
