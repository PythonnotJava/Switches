import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../models/provider_model.dart';
import '../models/model_info.dart';
import '../models/ip_rule.dart';
import '../models/app_config.dart';
import '../config/constants.dart';
import '../services/storage_service.dart';
import '../services/provider_service.dart';
import '../services/server_service.dart';
import '../services/tray_service.dart';

/// 应用全局状态管理
class AppProvider extends ChangeNotifier {
  // ===== 数据 =====
  List<LLMProvider> _providers = [];
  List<ModelInfo> _models = [];
  List<IpRule> _ipRules = [];
  AppConfig _config = AppConfig();
  late ServerService _serverService;

  // ===== 服务器状态 =====
  bool _serverRunning = false;
  final List<Map<String, dynamic>> _requestLogs = [];

  // ===== 加载状态 =====
  bool _loading = false;
  String? _error;

  /// 请求统计
  int _totalRequests = 0;
  int _successRequests = 0;
  int _errorRequests = 0;
  final Map<String, int> _modelUsageCount = {};

  // Getters
  List<LLMProvider> get providers => _providers;
  List<ModelInfo> get models => _models;
  List<IpRule> get ipRules => _ipRules;
  AppConfig get config => _config;
  ServerService get serverService => _serverService;
  bool get serverRunning => _serverRunning;
  List<Map<String, dynamic>> get requestLogs => _requestLogs;
  bool get loading => _loading;
  String? get error => _error;

  int get totalRequests => _totalRequests;
  int get successRequests => _successRequests;
  int get errorRequests => _errorRequests;
  Map<String, int> get modelUsageCount => _modelUsageCount;

  /// 成功率 (0.0~1.0)
  double get successRate =>
      _totalRequests > 0 ? _successRequests / _totalRequests : 0.0;

  /// 获取某服务商的模型列表
  List<ModelInfo> modelsForProvider(String providerId) {
    return _models.where((m) => m.providerId == providerId).toList();
  }

  /// 获取启用的模型数
  int get enabledModelCount => _models.where((m) => m.enabled).length;

  /// 获取启用的服务商数
  int get enabledProviderCount =>
      _providers.where((p) => p.enabled).length;

  /// 初始化
  Future<void> init() async {
    await StorageService.init();
    _loadAll();
    _loadLogs();
    _serverService = ServerService(port: _config.port);
    _serverService.onRequest = _onServerRequest;

    if (_config.serverAutoStart) {
      await startServer();
    }
  }

  void _loadAll() {
    _providers = StorageService.loadProviders();
    _models = StorageService.loadModels();
    _ipRules = StorageService.loadIpRules();
    _config = StorageService.loadConfig();
    notifyListeners();
  }

  void _loadLogs() {
    final logs = StorageService.loadRequestLogs();
    _requestLogs.addAll(logs);
    if (logs.isNotEmpty) {
      // 从日志恢复统计
      _rebuildStats();
    }
  }

  void _rebuildStats() {
    _totalRequests = 0;
    _successRequests = 0;
    _errorRequests = 0;
    _modelUsageCount.clear();
    for (final log in _requestLogs) {
      _totalRequests++;
      final status = log['status'] as int? ?? 500;
      if (status >= 200 && status < 300) {
        _successRequests++;
      } else {
        _errorRequests++;
      }
      final model = log['model']?.toString() ?? '';
      if (model.isNotEmpty) {
        _modelUsageCount[model] = (_modelUsageCount[model] ?? 0) + 1;
      }
    }
  }

  // ===== 服务商管理 =====

  Future<void> addProvider(LLMProvider provider) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await StorageService.saveProvider(provider);
      _providers = StorageService.loadProviders();
      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[Switches] addProvider: $e');
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProvider(LLMProvider provider) async {
    await StorageService.saveProvider(provider);
    _providers = StorageService.loadProviders();
    notifyListeners();
    _syncServer();
  }

  Future<void> deleteProvider(String id) async {
    await StorageService.deleteProvider(id);
    _providers = StorageService.loadProviders();
    _models = StorageService.loadModels();
    notifyListeners();
    _syncServer();
  }

  Future<void> toggleProvider(String id) async {
    final provider = _providers.firstWhere((p) => p.id == id);
    final updated = provider.copyWith(enabled: !provider.enabled);
    await StorageService.saveProvider(updated);
    _providers = StorageService.loadProviders();
    notifyListeners();
    _syncServer();
  }

  /// 测试服务商连接
  Future<bool> testProviderConnection(String providerId) async {
    final provider = _providers.firstWhere((p) => p.id == providerId);
    _error = null;
    notifyListeners();

    try {
      return await ProviderService.testConnection(provider);
    } catch (e) {
      debugPrint('[Switches] testProviderConnection: $e');
      _error = e.toString();
      return false;
    }
  }

  /// 从服务商获取模型列表
  Future<List<ModelInfo>> fetchProviderModels(String providerId) async {
    final provider = _providers.firstWhere((p) => p.id == providerId);
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 直接获取模型列表（本身即连接测试，且能返回真实的 HTTP 错误信息）
      final fetchedModels = await ProviderService.fetchModels(provider);

      // 复用已有模型的 id 与用户设置，避免每次获取都生成新 UUID
      // （否则 IP 规则里按 id 引用的模型会全部失效，显示成 UUID）
      final existing = _models.where((m) => m.providerId == providerId);
      final existingByName = <String, ModelInfo>{
        for (final m in existing) m.name: m,
      };

      final merged = fetchedModels.map((fresh) {
        final old = existingByName[fresh.name];
        if (old == null) return fresh; // 新模型，保持新 id
        // 命中同名旧模型：保留旧 id + 用户设置，仅刷新推断出的能力
        return ModelInfo(
          id: old.id,
          providerId: providerId,
          name: fresh.name,
          displayName: old.displayName,
          capabilities: fresh.capabilities,
          enabled: old.enabled,
          maxTokens: old.maxTokens,
          exposedProtocol: old.exposedProtocol,
          createdAt: old.createdAt,
        );
      }).toList();

      // 删除旧模型，保存合并后的模型（id 已尽量沿用）
      await StorageService.deleteModelsForProvider(providerId);
      await StorageService.saveModels(merged);

      _models = StorageService.loadModels();
      _loading = false;
      notifyListeners();
      _syncServer();

      return merged;
    } catch (e) {
      debugPrint('[Switches] fetchProviderModels: $e');
      _error = e.toString();
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ===== 模型管理 =====

  Future<void> updateModel(ModelInfo model) async {
    await StorageService.saveModel(model);
    _models = StorageService.loadModels();
    notifyListeners();
    _syncServer();
  }

  Future<void> toggleModel(String modelId) async {
    final model = _models.firstWhere((m) => m.id == modelId);
    final updated = model.copyWith(enabled: !model.enabled);
    await StorageService.saveModel(updated);
    _models = StorageService.loadModels();
    notifyListeners();
    _syncServer();
  }

  Future<void> deleteModel(String modelId) async {
    await StorageService.deleteModel(modelId);
    _models = StorageService.loadModels();
    notifyListeners();
    _syncServer();
  }

  // ===== IP规则管理 =====

  Future<void> addIpRule(IpRule rule) async {
    await StorageService.saveIpRule(rule);
    _ipRules = StorageService.loadIpRules();
    notifyListeners();
    _syncServer();
  }

  Future<void> updateIpRule(IpRule rule) async {
    await StorageService.saveIpRule(rule);
    _ipRules = StorageService.loadIpRules();
    notifyListeners();
    _syncServer();
  }

  Future<void> deleteIpRule(String id) async {
    await StorageService.deleteIpRule(id);
    _ipRules = StorageService.loadIpRules();
    notifyListeners();
    _syncServer();
  }

  Future<void> toggleIpRule(String id) async {
    final rule = _ipRules.firstWhere((r) => r.id == id);
    final updated = rule.copyWith(enabled: !rule.enabled);
    await StorageService.saveIpRule(updated);
    _ipRules = StorageService.loadIpRules();
    notifyListeners();
    _syncServer();
  }

  // ===== 配置管理 =====

  Future<void> updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    await StorageService.saveConfig(_config);
    notifyListeners();

    // 端口变更时重建服务器
    if (_serverRunning) {
      await stopServer();
      _serverService = ServerService(port: _config.port);
      _serverService.onRequest = _onServerRequest;
      await startServer();
    }
  }

  // ===== 服务器管理 =====

  Future<void> startServer() async {
    try {
      _serverService = ServerService(port: _config.port);
      _serverService.onRequest = _onServerRequest;
      _syncServer();
      await _serverService.start();
      _serverRunning = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Switches] startServer: $e');
      _error = '启动服务器失败: $e';
      _serverRunning = false;
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    await _serverService.stop();
    _serverRunning = false;
    notifyListeners();
  }

  Future<void> toggleServer() async {
    if (_serverRunning) {
      await stopServer();
    } else {
      await startServer();
    }
    // 同步刷新托盘菜单（启动/停止 文案）
    await TrayService.instance.refreshMenu();
  }

  /// 统一的退出流程：停止服务 → 销毁托盘 → 销毁窗口。
  /// 托盘菜单「退出」和窗口关闭「退出程序」共用，保证资源按序释放。
  Future<void> quit() async {
    try {
      await stopServer();
    } catch (e) {
      debugPrint('[Switches] quit stopServer: $e');
    }
    try {
      await TrayService.instance.dispose();
    } catch (e) {
      debugPrint('[Switches] quit tray dispose: $e');
    }
    await windowManager.destroy();
  }

  void _syncServer() {
    _serverService.updateData(
      providers: _providers,
      models: _models,
      ipRules: _ipRules,
      apiKey: _config.apiKey,
      restrictToWhitelist: _config.restrictToWhitelist,
      trustProxyHeaders: _config.trustProxyHeaders,
    );
  }

  /// 生成一个新的对外访问密钥（sk-switches-<32位随机>）
  Future<String> generateApiKey() async {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final buf = StringBuffer('sk-switches-');
    for (var i = 0; i < 32; i++) {
      buf.write(chars[rand.nextInt(chars.length)]);
    }
    final key = buf.toString();
    await updateConfig(_config.copyWith(apiKey: key));
    return key;
  }

  /// 清除访问密钥（恢复为不校验）
  Future<void> clearApiKey() async {
    await updateConfig(_config.copyWith(apiKey: ''));
  }

  void _onServerRequest(String ip, String model, int statusCode) {
    final logEntry = {
      'time': DateTime.now().toIso8601String(),
      'ip': ip,
      'model': model,
      'status': statusCode,
    };

    _requestLogs.insert(0, logEntry);

    // 统计
    _totalRequests++;
    if (statusCode >= 200 && statusCode < 300) {
      _successRequests++;
    } else {
      _errorRequests++;
    }
    _modelUsageCount[model] = (_modelUsageCount[model] ?? 0) + 1;

    // 限制内存中的日志数量
    if (_requestLogs.length > AppConstants.maxLogEntries) {
      _requestLogs.removeRange(
          AppConstants.maxLogEntries, _requestLogs.length);
    }

    // 异步持久化
    StorageService.addRequestLog(logEntry);
    StorageService.trimRequestLogs(AppConstants.maxLogEntries);

    notifyListeners();
  }

  /// 清除请求日志
  Future<void> clearRequestLogs() async {
    _requestLogs.clear();
    _totalRequests = 0;
    _successRequests = 0;
    _errorRequests = 0;
    _modelUsageCount.clear();
    await StorageService.clearRequestLogs();
    notifyListeners();
  }

  @override
  void dispose() {
    _serverService.stop();
    super.dispose();
  }
}
