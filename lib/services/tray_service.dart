import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// 系统托盘服务（单例）
///
/// 统一管理托盘的初始化、菜单刷新与销毁，避免退出流程中
/// 托盘资源未释放导致的崩溃。
class TrayService {
  TrayService._();
  static final TrayService instance = TrayService._();

  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;
  bool _disposed = false;

  /// 由外部注入的回调，供托盘菜单调用
  bool Function()? isServerRunning;
  Future<void> Function()? onToggleServer;
  Future<void> Function()? onQuit;

  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    String iconPath = '';
    try {
      iconPath = await _extractIconAsset('assets/icons/app_icon.ico');
    } catch (e) {
      debugPrint('[Switches] extractIcon: $e');
    }

    try {
      await _systemTray.initSystemTray(
        title: 'Switches',
        iconPath: iconPath,
        toolTip: 'Switches - LLM协议转换',
      );

      await _rebuildMenu();

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          windowManager.show();
        }
      });
      _initialized = true;
    } catch (e) {
      debugPrint('[Switches] 系统托盘初始化失败: $e');
    }
  }

  /// 刷新托盘菜单（服务状态变化时调用）
  Future<void> refreshMenu() async {
    if (!_initialized || _disposed) return;
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    final running = isServerRunning?.call() ?? false;
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: '显示主窗口',
        onClicked: (_) => windowManager.show(),
      ),
      MenuItemLabel(
        label: running ? '停止服务' : '启动服务',
        onClicked: (_) async {
          await onToggleServer?.call();
          await refreshMenu();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '退出',
        onClicked: (_) async {
          await onQuit?.call();
        },
      ),
    ]);
    await _systemTray.setContextMenu(menu);
  }

  /// 销毁托盘（退出前必须调用）
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _systemTray.destroy();
    } catch (e) {
      debugPrint('[Switches] 托盘销毁失败: $e');
    }
  }

  Future<String> _extractIconAsset(String assetPath) async {
    final dir = await getApplicationSupportDirectory();
    final iconDir = Directory('${dir.path}/icons');
    if (!await iconDir.exists()) {
      await iconDir.create(recursive: true);
    }
    final fileName = assetPath.split('/').last;
    final file = File('${iconDir.path}/$fileName');
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return file.path;
  }
}
