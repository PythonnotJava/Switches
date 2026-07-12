import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// IP白名单规则
class IpRule {
  final String id;
  String ipAddress; // IP地址，支持CIDR如 192.168.1.0/24
  String label; // 标签备注
  bool enabled;
  List<String> allowedModelIds; // 允许的模型ID列表，空=全部允许
  DateTime createdAt;
  DateTime updatedAt;

  IpRule({
    String? id,
    required this.ipAddress,
    this.label = '',
    this.enabled = true,
    List<String>? allowedModelIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        allowedModelIds = allowedModelIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 是否允许所有模型
  bool get allowAllModels => allowedModelIds.isEmpty;

  /// 检查是否允许指定模型
  bool allowsModel(String modelId) {
    if (allowAllModels) return true;
    return allowedModelIds.contains(modelId);
  }

  factory IpRule.fromJson(Map<String, dynamic> json) {
    return IpRule(
      id: json['id'] as String,
      ipAddress: json['ipAddress'] as String,
      label: json['label'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      allowedModelIds: (json['allowedModelIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ipAddress': ipAddress,
        'label': label,
        'enabled': enabled,
        'allowedModelIds': allowedModelIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  IpRule copyWith({
    String? ipAddress,
    String? label,
    bool? enabled,
    List<String>? allowedModelIds,
  }) {
    return IpRule(
      id: id,
      ipAddress: ipAddress ?? this.ipAddress,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      allowedModelIds: allowedModelIds ?? this.allowedModelIds,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
