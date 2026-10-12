import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// ウィンドウ表示・非表示、最前面固定、およびシステムトレイ常駐を管理するデータソース
class WindowTrayDatasource with WindowListener, TrayListener {
  WindowTrayDatasource({
    WindowManager? windowManager,
    TrayManager? trayManager,
  })  : _windowManager = windowManager ?? WindowManager.instance,
        _trayManager = trayManager ?? TrayManager.instance;

  final WindowManager _windowManager;
  final TrayManager _trayManager;

  final StreamController<bool> _visibilityController =
      StreamController<bool>.broadcast();

  /// ウィンドウの表示状態変更ストリーム（true: 表示中, false: トレイ格納/非表示）
  Stream<bool> get onVisibilityChanged => _visibilityController.stream;

  bool _isVisible = true;

  /// 現在ウィンドウが表示中かどうか
  bool get isVisible => _isVisible;

  /// 初期化処理（ウィンドウオプションとトレイアイコン/メニューの設定）
  Future<void> init() async {
    if (!Platform.isWindows) return;

    _windowManager.addListener(this);
    _trayManager.addListener(this);

    // ウィンドウオプションの設定
    const windowOptions = WindowOptions(
      size: Size(380, 560),
      minimumSize: Size(320, 480),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'Copy-lot',
    );

    await _windowManager.waitUntilReadyToShow(windowOptions, () async {
      await _windowManager.setPreventClose(true);
      await _windowManager.show();
      await _windowManager.focus();
      _isVisible = true;
    });

    // システムトレイの設定
    await _initSystemTray();
  }

  Future<void> _initSystemTray() async {
    try {
      await _trayManager.setIcon('assets/app_icon.ico');
      final menu = Menu(
        items: [
          MenuItem(key: 'toggle_window', label: '表示 / 非表示'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: '終了'),
        ],
      );
      await _trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('[WindowTrayDatasource] Failed to initialize system tray: $e');
    }
  }

  /// ウィンドウを表示してフォーカス
  Future<void> showWindow() async {
    if (!Platform.isWindows) return;
    await _windowManager.show();
    await _windowManager.focus();
    _isVisible = true;
    _visibilityController.add(true);
  }

  /// ウィンドウを非表示にしてシステムトレイへ格納
  Future<void> hideWindow() async {
    if (!Platform.isWindows) return;
    await _windowManager.hide();
    _isVisible = false;
    _visibilityController.add(false);
  }

  /// ウィンドウの表示/非表示を切り替え
  Future<void> toggleWindow() async {
    if (_isVisible) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  /// 最前面固定（Always on Top）の切り替え
  Future<void> setAlwaysOnTop(bool isAlwaysOnTop) async {
    if (!Platform.isWindows) return;
    await _windowManager.setAlwaysOnTop(isAlwaysOnTop);
  }

  /// アプリケーションの完全終了
  Future<void> exitApp() async {
    if (!Platform.isWindows) return;
    _windowManager.removeListener(this);
    _trayManager.removeListener(this);
    await _trayManager.destroy();
    await _windowManager.destroy();
  }

  // --- WindowListener フック ---

  @override
  void onWindowClose() async {
    // 「×」ボタン押下時は終了せずトレイへ格納
    await hideWindow();
  }

  @override
  void onWindowMinimize() async {
    // 「_（最小化）」ボタン押下時もトレイへ格納（非表示化）
    await hideWindow();
  }

  // --- TrayListener フック ---

  @override
  void onTrayIconMouseDown() async {
    // トレイアイコン左クリックで表示/非表示切り替え
    await toggleWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'toggle_window':
        await toggleWindow();
        break;
      case 'exit_app':
        await exitApp();
        break;
    }
  }

  void dispose() {
    _windowManager.removeListener(this);
    _trayManager.removeListener(this);
    _visibilityController.close();
  }
}
