import '../config/constants.dart';

/// 应用全局配置
class AppConfig {
  int port;
  bool serverAutoStart;
  bool darkMode;
  bool debugMode;
  /// 关闭行为: 'ask' = 每次询问, 'minimize' = 最小化到托盘, 'quit' = 直接退出
  String closeAction;
  /// 对外服务的访问密钥。空 = 不校验（仅靠 IP 白名单）；
  /// 非空 = 所有请求必须携带（OpenAI 用 `Authorization: Bearer key`；Claude 用 `x-api-key: key`）
  String apiKey;
  /// 严格白名单模式。true（默认）= 仅本机 + 命中白名单规则的 IP 可访问，
  /// 无规则时除本机外全部拒绝；false = 无规则时放行所有 IP（宽松，不推荐）。
  bool restrictToWhitelist;
  /// 是否信任反向代理头（X-Forwarded-For / X-Real-IP）判定客户端 IP。
  /// 默认 false：直连场景下必须用真实 socket 地址，否则客户端可伪造头绕过白名单。
  /// 仅当 Switches 部署在可信反向代理之后时才应开启。
  bool trustProxyHeaders;

  AppConfig({
    this.port = AppConstants.defaultPort,
    this.serverAutoStart = false,
    this.darkMode = false,
    this.debugMode = false,
    this.closeAction = 'ask',
    this.apiKey = '',
    this.restrictToWhitelist = true,
    this.trustProxyHeaders = false,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    // 兼容旧版 minimizeToTray 字段
    String closeAction = json['closeAction'] as String? ?? 'ask';
    if (!json.containsKey('closeAction') &&
        json.containsKey('minimizeToTray')) {
      closeAction =
          (json['minimizeToTray'] as bool?) == true ? 'minimize' : 'ask';
    }
    return AppConfig(
      port: json['port'] as int? ?? AppConstants.defaultPort,
      serverAutoStart: json['serverAutoStart'] as bool? ?? false,
      darkMode: json['darkMode'] as bool? ?? false,
      debugMode: json['debugMode'] as bool? ?? false,
      closeAction: closeAction,
      apiKey: json['apiKey'] as String? ?? '',
      restrictToWhitelist: json['restrictToWhitelist'] as bool? ?? true,
      trustProxyHeaders: json['trustProxyHeaders'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'port': port,
        'serverAutoStart': serverAutoStart,
        'darkMode': darkMode,
        'debugMode': debugMode,
        'closeAction': closeAction,
        'apiKey': apiKey,
        'restrictToWhitelist': restrictToWhitelist,
        'trustProxyHeaders': trustProxyHeaders,
      };

  AppConfig copyWith({
    int? port,
    bool? serverAutoStart,
    bool? darkMode,
    bool? debugMode,
    String? closeAction,
    String? apiKey,
    bool? restrictToWhitelist,
    bool? trustProxyHeaders,
  }) {
    return AppConfig(
      port: port ?? this.port,
      serverAutoStart: serverAutoStart ?? this.serverAutoStart,
      darkMode: darkMode ?? this.darkMode,
      debugMode: debugMode ?? this.debugMode,
      closeAction: closeAction ?? this.closeAction,
      apiKey: apiKey ?? this.apiKey,
      restrictToWhitelist: restrictToWhitelist ?? this.restrictToWhitelist,
      trustProxyHeaders: trustProxyHeaders ?? this.trustProxyHeaders,
    );
  }
}
