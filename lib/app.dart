import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'config/theme.dart';
import 'providers/app_provider.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/providers_page.dart';
import 'ui/pages/models_page.dart';
import 'ui/pages/ip_manager_page.dart';
import 'ui/pages/settings_page.dart';

enum _CloseAction { minimize, quit, cancel }

class SwitchesApp extends StatelessWidget {
  const SwitchesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return MaterialApp(
          title: 'Switches - LLM协议转换',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: app.config.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AppShell(),
        );
      },
    );
  }
}

/// 应用外壳 - 响应式导航布局
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_rounded, '仪表盘'),
    _NavItem(Icons.cloud_rounded, '服务商'),
    _NavItem(Icons.model_training_rounded, '模型库'),
    _NavItem(Icons.security_rounded, 'IP管理'),
    _NavItem(Icons.settings_rounded, '设置'),
  ];

  final _pages = const [
    HomePage(),
    ProvidersPage(),
    ModelsPage(),
    IpManagerPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  bool _handlingClose = false;
  OverlayEntry? _quitOverlay;

  @override
  void onWindowClose() async {
    // 防止关闭事件重入（弹窗期间用户再次点关闭）
    if (_handlingClose) return;
    _handlingClose = true;

    final app = context.read<AppProvider>();

    try {
      // 如果用户之前选了"记住"，直接按偏好执行
      if (app.config.closeAction == 'minimize') {
        await windowManager.hide();
        return;
      } else if (app.config.closeAction == 'quit') {
        await _quitWithOverlay(app);
        return;
      }

      // 直接弹窗提问（不再用 addPostFrameCallback + 延迟，避免卡顿）
      if (!mounted) return;
      final result = await showDialog<_CloseAction>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _CloseConfirmDialog(),
      );

      if (result == _CloseAction.minimize) {
        await windowManager.hide();
      } else if (result == _CloseAction.quit) {
        await _quitWithOverlay(app);
      }
      // cancel / null：什么都不做，窗口保持打开
    } finally {
      _handlingClose = false;
    }
  }

  /// 退出时先铺一层全屏加载动画，遮住关闭后台服务（shelf 服务器 +
  /// 托盘销毁）带来的界面冻结，让用户感知到"正在退出"而非卡死。
  Future<void> _quitWithOverlay(AppProvider app) async {
    if (mounted) {
      _quitOverlay = OverlayEntry(builder: (_) => const _QuittingOverlay());
      Overlay.of(context, rootOverlay: true).insert(_quitOverlay!);
      // 让遮罩先渲染一帧，再执行阻塞的关闭流程
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    try {
      await app.quit();
    } finally {
      _quitOverlay?.remove();
      _quitOverlay = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/icons/logo.png',
                          width: 36,
                          height: 36,
                        ),
                        const SizedBox(height: 4),
                        Text('Switches',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                  destinations: _navItems
                      .map((item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            label: Text(item.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _pages[_selectedIndex]),
              ],
            )
          : Column(
              children: [
                Expanded(child: _pages[_selectedIndex]),
                NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  destinations: _navItems
                      .map((item) => NavigationDestination(
                            icon: Icon(item.icon),
                            label: item.label,
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }
}

/// 关闭确认对话框
class _CloseConfirmDialog extends StatefulWidget {
  @override
  State<_CloseConfirmDialog> createState() => _CloseConfirmDialogState();
}

class _CloseConfirmDialogState extends State<_CloseConfirmDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();

    return AlertDialog(
      title: Row(
        children: [
          Image.asset('assets/icons/logo.png', width: 28, height: 28),
          const SizedBox(width: 10),
          const Text('关闭 Switches'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.serverRunning)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  SizedBox(width: 6),
                  Text('服务正在运行中',
                      style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          _OptionTile(
            icon: Icons.minimize_rounded,
            iconColor: Colors.blue,
            title: '最小化到系统托盘',
            subtitle: 'Switches 继续在后台运行，可通过托盘图标恢复',
            onTap: () => _choose(_CloseAction.minimize, app),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.power_settings_new_rounded,
            iconColor: Colors.red,
            title: '退出程序',
            subtitle: '停止服务并完全退出 Switches',
            onTap: () => _choose(_CloseAction.quit, app),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.close_rounded,
            iconColor: Colors.grey,
            title: '取消',
            subtitle: '什么都不做，返回主界面',
            onTap: () => Navigator.pop(context, _CloseAction.cancel),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _remember = !_remember),
                child: Text(
                  '记住我的选择，下次不再询问',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _choose(_CloseAction action, AppProvider app) {
    if (_remember) {
      final actionStr =
          action == _CloseAction.minimize ? 'minimize' : 'quit';
      app.updateConfig(app.config.copyWith(closeAction: actionStr));
    }
    Navigator.pop(context, action);
  }
}

/// 可点击选项行
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

/// 退出过程中的全屏加载遮罩
class _QuittingOverlay extends StatelessWidget {
  const _QuittingOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/logo.png', width: 48, height: 48),
            const SizedBox(height: 20),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            const Text(
              '正在退出…',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
