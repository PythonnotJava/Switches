import 'package:hive_flutter/hive_flutter.dart';
import '../config/constants.dart';
import '../models/provider_model.dart';
import '../models/model_info.dart';
import '../models/ip_rule.dart';
import '../models/app_config.dart';

/// 本地存储服务
class StorageService {
  static late Box<Map> _providersBox;
  static late Box<Map> _modelsBox;
  static late Box<Map> _ipRulesBox;
  static late Box<Map> _configBox;
  static late Box<Map> _logsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _providersBox = await Hive.openBox<Map>(AppConstants.providersBox);
    _modelsBox = await Hive.openBox<Map>(AppConstants.modelsBox);
    _ipRulesBox = await Hive.openBox<Map>(AppConstants.ipRulesBox);
    _configBox = await Hive.openBox<Map>(AppConstants.configBox);
    _logsBox = await Hive.openBox<Map>(AppConstants.logsBox);
  }

  // ==================== 服务商 ====================

  static List<LLMProvider> loadProviders() {
    return _providersBox.values
        .map((e) => LLMProvider.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveProvider(LLMProvider provider) async {
    await _providersBox.put(provider.id, provider.toJson());
  }

  static Future<void> deleteProvider(String id) async {
    await _providersBox.delete(id);
    // 同时删除关联的模型
    final modelsToDelete = _modelsBox.values
        .where((e) => e['providerId'] == id)
        .map((e) => e['id'] as String)
        .toList();
    for (final mid in modelsToDelete) {
      await _modelsBox.delete(mid);
    }
  }

  // ==================== 模型 ====================

  static List<ModelInfo> loadModels() {
    return _modelsBox.values
        .map((e) => ModelInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<ModelInfo> loadModelsForProvider(String providerId) {
    return _modelsBox.values
        .where((e) => e['providerId'] == providerId)
        .map((e) => ModelInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveModel(ModelInfo model) async {
    await _modelsBox.put(model.id, model.toJson());
  }

  static Future<void> saveModels(List<ModelInfo> models) async {
    for (final m in models) {
      await _modelsBox.put(m.id, m.toJson());
    }
  }

  static Future<void> deleteModel(String id) async {
    await _modelsBox.delete(id);
  }

  static Future<void> deleteModelsForProvider(String providerId) async {
    final toDelete = _modelsBox.values
        .where((e) => e['providerId'] == providerId)
        .map((e) => e['id'] as String)
        .toList();
    for (final mid in toDelete) {
      await _modelsBox.delete(mid);
    }
  }

  // ==================== IP规则 ====================

  static List<IpRule> loadIpRules() {
    return _ipRulesBox.values
        .map((e) => IpRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveIpRule(IpRule rule) async {
    await _ipRulesBox.put(rule.id, rule.toJson());
  }

  static Future<void> deleteIpRule(String id) async {
    await _ipRulesBox.delete(id);
  }

  // ==================== 请求日志 ====================

  static List<Map<String, dynamic>> loadRequestLogs() {
    final entries = _logsBox.values.toList();
    // 按时间倒序
    entries.sort((a, b) {
      final aTime = DateTime.tryParse(a['time'] as String? ?? '');
      final bTime = DateTime.tryParse(b['time'] as String? ?? '');
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return entries.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addRequestLog(Map<String, dynamic> log) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _logsBox.put(id, log);
  }

  static Future<void> clearRequestLogs() async {
    await _logsBox.clear();
  }

  /// 清理旧日志，保留最近N条
  static Future<void> trimRequestLogs(int keepCount) async {
    if (_logsBox.length <= keepCount) return;
    final allKeys = _logsBox.keys.toList();
    // 删除最旧的
    final toDelete = allKeys.sublist(0, allKeys.length - keepCount);
    await _logsBox.deleteAll(toDelete);
  }

  // ==================== 应用配置 ====================

  static AppConfig loadConfig() {
    final data = _configBox.get('app_config');
    if (data != null) {
      return AppConfig.fromJson(Map<String, dynamic>.from(data));
    }
    return AppConfig();
  }

  static Future<void> saveConfig(AppConfig config) async {
    await _configBox.put('app_config', config.toJson());
  }
}
