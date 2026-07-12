import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/tray_service.dart';
import 'app.dart';

bool _isDesktop() =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器（桌面端）
  if (_isDesktop()) {
    await windowManager.ensureInitialized();

    const minSize = Size(800, 600);
    await windowManager.setMinimumSize(minSize);
    await windowManager.setSize(const Size(1200, 800));
    await windowManager.center();
    await windowManager.setTitle('Switches - LLM协议转换');

    // 拦截关闭事件，交由 onWindowClose 处理
    await windowManager.setPreventClose(true);
  }

  // 初始化应用状态
  final appProvider = AppProvider();
  await appProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const SwitchesApp(),
    ),
  );

  // 初始化系统托盘（回调交由 TrayService 统一管理）
  if (_isDesktop()) {
    final tray = TrayService.instance;
    tray.isServerRunning = () => appProvider.serverRunning;
    tray.onToggleServer = appProvider.toggleServer;
    tray.onQuit = appProvider.quit;
    await tray.init();
  }
}
