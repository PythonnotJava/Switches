import 'package:uuid/uuid.dart';
import '../config/constants.dart';

const _uuid = Uuid();

/// LLM服务商模型
class LLMProvider {
  final String id;
  String name;
  String type; // openai, gemini, claude
  String apiKey;
  String baseUrl;
  String iconUrl; // 自定义图标URL，为空则用首字
  bool enabled;
  DateTime createdAt;
  DateTime updatedAt;

  LLMProvider({
    String? id,
    required this.name,
    required this.type,
    this.apiKey = '',
    String? baseUrl,
    this.iconUrl = '',
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        baseUrl = baseUrl ?? AppConstants.providerDefaultBaseUrls[type] ?? '',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory LLMProvider.fromJson(Map<String, dynamic> json) {
    return LLMProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String?,
      iconUrl: json['iconUrl'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
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
        'name': name,
        'type': type,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'iconUrl': iconUrl,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  LLMProvider copyWith({
    String? name,
    String? type,
    String? apiKey,
    String? baseUrl,
    String? iconUrl,
    bool? enabled,
  }) {
    return LLMProvider(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 获取显示名称
  String get displayType =>
      AppConstants.providerDisplayNames[type] ?? type.toUpperCase();

  /// 是否有自定义图标
  bool get hasIcon => iconUrl.isNotEmpty;
}
