import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置'), centerTitle: false),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(title: '服务器'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dns_rounded),
                      title: const Text('服务端口'),
                      subtitle: Text('当前: ${app.config.port}'),
                      trailing: SizedBox(
                        width: 120,
                        child: TextFormField(
                          initialValue: app.config.port.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          onFieldSubmitted: (value) {
                            final port = int.tryParse(value);
                            if (port != null && port > 0 && port < 65536) {
                              app.updateConfig(app.config.copyWith(port: port));
                            }
                          },
                        ),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.auto_mode_rounded),
                      title: const Text('启动时自动开启服务'),
                      value: app.config.serverAutoStart,
                      onChanged: (v) => app.updateConfig(
                        app.config.copyWith(serverAutoStart: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '访问密钥'),
              _ApiKeyCard(app: app),
              const SizedBox(height: 24),
              _SectionHeader(title: '安全'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        Icons.shield_rounded,
                        color: app.config.restrictToWhitelist
                            ? Colors.green
                            : null,
                      ),
                      title: const Text('严格白名单模式'),
                      subtitle: const Text(
                        '开启后，未配置任何规则时除本机外一律拒绝；关闭则无规则时放行所有IP',
                      ),
                      value: app.config.restrictToWhitelist,
                      onChanged: (v) => app.updateConfig(
                        app.config.copyWith(restrictToWhitelist: v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.dns_outlined,
                        color: app.config.trustProxyHeaders
                            ? Colors.orange
                            : null,
                      ),
                      title: const Text('信任反向代理头'),
                      subtitle: const Text(
                        '仅当部署在可信反代(Nginx等)之后才开启。直连场景开启会导致客户端可伪造IP绕过白名单',
                      ),
                      value: app.config.trustProxyHeaders,
                      onChanged: (v) => app.updateConfig(
                        app.config.copyWith(trustProxyHeaders: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
                _SectionHeader(title: '桌面端 - 关闭行为'),
              if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
                Card(
                  child: Column(
                    children: [
                      RadioGroup<String>(
                        groupValue: app.config.closeAction,
                        onChanged: (v) => app.updateConfig(
                          app.config.copyWith(closeAction: v),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              secondary: const Icon(
                                Icons.help_outline_rounded,
                                color: Colors.orange,
                              ),
                              title: const Text('每次询问'),
                              subtitle: const Text('关闭窗口时弹出选择对话框'),
                              value: 'ask',
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            RadioListTile<String>(
                              secondary: const Icon(
                                Icons.minimize_rounded,
                                color: Colors.blue,
                              ),
                              title: const Text('最小化到系统托盘'),
                              subtitle: const Text('关闭窗口时直接隐藏到托盘'),
                              value: 'minimize',
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            RadioListTile<String>(
                              secondary: const Icon(
                                Icons.power_settings_new_rounded,
                                color: Colors.red,
                              ),
                              title: const Text('直接退出程序'),
                              subtitle: const Text('关闭窗口时停止服务并退出'),
                              value: 'quit',
                            ),
                          ],
                        ),
                      ),
                      if (app.config.closeAction != 'ask')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: OutlinedButton.icon(
                            onPressed: () => app.updateConfig(
                              app.config.copyWith(closeAction: 'ask'),
                            ),
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('恢复为「每次询问」'),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _SectionHeader(title: '外观'),
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_rounded),
                  title: const Text('深色模式'),
                  value: app.config.darkMode,
                  onChanged: (v) =>
                      app.updateConfig(app.config.copyWith(darkMode: v)),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '调试'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.bug_report_rounded),
                      title: const Text('调试模式'),
                      subtitle: const Text('记录请求/响应体内容（日志量较大）'),
                      value: app.config.debugMode,
                      onChanged: (v) =>
                          app.updateConfig(app.config.copyWith(debugMode: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '关于'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Switches'),
                      subtitle: const Text('LLM服务商协议转换工具'),
                      trailing: Text(
                        'v1.0.0',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.swap_horiz_rounded),
                      title: Text('协议转换'),
                      subtitle: Text(
                        '上游 OpenAI / Gemini / Claude → 对外 OpenAI / Claude',
                      ),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.api_rounded),
                      title: Text('对外 API'),
                      subtitle: Text(
                        'OpenAI 兼容 (/v1/chat/completions)  ·  Claude Messages (/v1/messages)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _ApiKeyCard extends StatelessWidget {
  final AppProvider app;
  const _ApiKeyCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final key = app.config.apiKey;
    final hasKey = key.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasKey ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: hasKey ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasKey ? '已启用密钥校验' : '未启用（仅靠 IP 白名单）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasKey ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasKey
                  ? '客户端请求需携带此密钥：OpenAI 用 Authorization: Bearer <key>，Claude 用 x-api-key: <key>。'
                  : '生成后，所有对外请求都必须携带密钥才能访问。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (hasKey) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        key,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: '复制',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: key));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制密钥'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await app.generateApiKey();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(hasKey ? '已重新生成密钥' : '已生成密钥'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: Text(hasKey ? '重新生成' : '生成密钥'),
                ),
                if (hasKey) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => app.clearApiKey(),
                    icon: const Icon(Icons.no_encryption_rounded, size: 18),
                    label: const Text('停用'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
