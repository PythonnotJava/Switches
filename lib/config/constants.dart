/// Switches 应用常量配置
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = 'Switches';

  /// 默认服务端口
  static const int defaultPort = 9998;

  /// 默认最小窗口尺寸
  static const double minWindowWidth = 800;
  static const double minWindowHeight = 600;

  /// 本地存储Box名称
  static const String providersBox = 'providers';
  static const String modelsBox = 'models';
  static const String ipRulesBox = 'ip_rules';
  static const String configBox = 'app_config';
  static const String logsBox = 'request_logs';

  /// 最大保留日志条数
  static const int maxLogEntries = 500;

  /// 支持的服务商类型
  static const List<String> supportedProviders = [
    'openai',
    'gemini',
    'claude',
  ];

  /// 服务商显示名称映射
  static const Map<String, String> providerDisplayNames = {
    'openai': 'OpenAI',
    'gemini': 'Gemini',
    'claude': 'Claude',
  };

  /// 服务商默认API地址
  static const Map<String, String> providerDefaultBaseUrls = {
    'openai': 'https://api.openai.com',
    'gemini': 'https://generativelanguage.googleapis.com',
    'claude': 'https://api.anthropic.com',
  };

  /// 服务商默认图标URL（用户可替换）
  static const Map<String, String> providerDefaultIcons = {
    'openai': '',
    'gemini': '',
    'claude': '',
  };

  /// 服务商Logo颜色
  static const Map<String, int> providerColors = {
    'openai': 0xFF10A37F,
    'gemini': 0xFF4285F4,
    'claude': 0xFFD97B4F,
  };
}

/// 模型能力枚举
enum ModelCapability {
  text('纯文本', 'text'),
  imageInput('图片输入', 'image_input'),
  imageOutput('图片输出', 'image_output'),
  audioInput('音频输入', 'audio_input'),
  audioOutput('音频输出', 'audio_output'),
  videoInput('视频输入', 'video_input'),
  functionCalling('函数调用', 'function_calling'),
  streaming('流式输出', 'streaming'),
  reasoning('深度推理', 'reasoning'),
  jsonMode('JSON模式', 'json_mode');

  final String label;
  final String key;
  const ModelCapability(this.label, this.key);
}
