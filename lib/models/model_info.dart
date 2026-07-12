import 'package:uuid/uuid.dart';
import '../config/constants.dart';

const _uuid = Uuid();

/// 模型信息
class ModelInfo {
  final String id;
  String providerId; // 归属服务商ID
  String name; // 模型名称，如 gpt-4o
  String displayName; // 显示名称
  Set<ModelCapability> capabilities;
  bool enabled;
  int maxTokens;
  String exposedProtocol; // 对外暴露协议: openai / claude
  DateTime createdAt;

  ModelInfo({
    String? id,
    required this.providerId,
    required this.name,
    String? displayName,
    Set<ModelCapability>? capabilities,
    this.enabled = true,
    this.maxTokens = 4096,
    this.exposedProtocol = 'openai',
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        displayName = displayName ?? name,
        capabilities = capabilities ?? {ModelCapability.text},
        createdAt = createdAt ?? DateTime.now();

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => ModelCapability.values.firstWhere(
                    (c) => c.key == e,
                    orElse: () => ModelCapability.text,
                  ))
              .toSet() ??
          {ModelCapability.text},
      enabled: json['enabled'] as bool? ?? true,
      maxTokens: json['maxTokens'] as int? ?? 4096,
      exposedProtocol: json['exposedProtocol'] as String? ?? 'openai',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'name': name,
        'displayName': displayName,
        'capabilities': capabilities.map((e) => e.key).toList(),
        'enabled': enabled,
        'maxTokens': maxTokens,
        'exposedProtocol': exposedProtocol,
        'createdAt': createdAt.toIso8601String(),
      };

  ModelInfo copyWith({
    String? displayName,
    Set<ModelCapability>? capabilities,
    bool? enabled,
    int? maxTokens,
    String? exposedProtocol,
  }) {
    return ModelInfo(
      id: id,
      providerId: providerId,
      name: name,
      displayName: displayName ?? this.displayName,
      capabilities: capabilities ?? this.capabilities,
      enabled: enabled ?? this.enabled,
      maxTokens: maxTokens ?? this.maxTokens,
      exposedProtocol: exposedProtocol ?? this.exposedProtocol,
      createdAt: createdAt,
    );
  }
}
