import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/clipboard_repository_impl.dart';
import '../../domain/models/clipboard_event.dart';
import '../../domain/models/clipboard_state.dart';
import '../../domain/repositories/clipboard_repository.dart';
import 'settings_provider.dart';

/// クリップボードリポジトリの Provider
final clipboardRepositoryProvider = Provider<ClipboardRepository>((ref) {
  final repo = ClipboardRepositoryImpl();
  ref.onDispose(repo.dispose);
  return repo;
});

/// クリップボード監視状態を管理する Notifier
class ClipboardNotifier extends Notifier<ClipboardState> {
  StreamSubscription<ClipboardEvent>? _subscription;

  @override
  ClipboardState build() {
    final repo = ref.watch(clipboardRepositoryProvider);

    // イベントストリームの購読
    _subscription?.cancel();
    _subscription = repo.eventStream.listen(_onClipboardEvent);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    // 初期状態は自動監視OFF、ウィンドウ表示中、リスナー停止
    return const ClipboardState(
      isAutoMonitoringEnabled: false,
      isWindowVisible: true,
      isListening: false,
    );
  }

  void _onClipboardEvent(ClipboardEvent event) {
    // 実効監視状態のときのみ取り込む
    if (!state.isListening) return;

    state = state.copyWith(
      currentText: event.text,
      originalLength: event.originalLength,
      isTruncated: event.isTruncated,
      lastUpdated: event.timestamp,
    );
  }

  /// 実効監視条件（三条件の論理積）の計算
  bool _computeShouldListen({
    bool? autoMonitoring,
    bool? windowVisible,
  }) {
    final auto = autoMonitoring ?? state.isAutoMonitoringEnabled;
    final visible = windowVisible ?? state.isWindowVisible;
    final hasApiKey = ref.read(settingsNotifierProvider).hasApiKey;

    return auto && visible && hasApiKey;
  }

  /// 現在のクリップボードテキストを取得して状態に反映（即時評価・手動ペースト共用）
  Future<void> _evaluateCurrentClipboardText() async {
    final repo = ref.read(clipboardRepositoryProvider);
    final text = await repo.getClipboardText();
    if (text != null && text.trim().isNotEmpty) {
      state = state.copyWith(
        currentText: text,
        originalLength: text.length,
        isTruncated: false,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 自動監視トグルの ON/OFF 切り替え
  Future<void> toggleAutoMonitoring(bool enabled) async {
    if (enabled) {
      // API キーの有効性チェック
      final settings = ref.read(settingsNotifierProvider);
      if (!settings.hasApiKey) {
        // API キーが無効/未設定の場合は ON にできない
        return;
      }
    }

    final repo = ref.read(clipboardRepositoryProvider);
    final shouldListen = _computeShouldListen(autoMonitoring: enabled);

    if (shouldListen && !repo.isListening) {
      await repo.startListening();
    } else if (!shouldListen && repo.isListening) {
      await repo.stopListening();
    }

    state = state.copyWith(
      isAutoMonitoringEnabled: enabled,
      isListening: repo.isListening,
    );

    // トグル ON 切り替え時の即時評価
    if (enabled) {
      await _evaluateCurrentClipboardText();
    }
  }

  /// ウィンドウの表示状態変更連動（トレイ格納時: false, 復帰時: true）
  Future<void> setWindowVisibility(bool visible) async {
    final repo = ref.read(clipboardRepositoryProvider);
    final shouldListen = _computeShouldListen(windowVisible: visible);

    if (shouldListen && !repo.isListening) {
      await repo.startListening();
    } else if (!shouldListen && repo.isListening) {
      await repo.stopListening();
    }

    state = state.copyWith(
      isWindowVisible: visible,
      isListening: repo.isListening,
    );

    // トレイ復帰時、直前のトグルが ON だった場合は現在のテキストを即時評価
    if (visible && state.isAutoMonitoringEnabled) {
      await _evaluateCurrentClipboardText();
    }
  }

  /// 手動ペースト実行（自動監視 OFF でも受容）
  Future<void> pasteAndTranslate() async {
    await _evaluateCurrentClipboardText();
  }

  /// クリップボード監視を開始（直接制御用）
  Future<void> startListening() async {
    final repo = ref.read(clipboardRepositoryProvider);
    await repo.startListening();
    state = state.copyWith(isListening: repo.isListening);
  }

  /// クリップボード監視を停止（直接制御用）
  Future<void> stopListening() async {
    final repo = ref.read(clipboardRepositoryProvider);
    await repo.stopListening();
    state = state.copyWith(isListening: repo.isListening);
  }
}

/// ClipboardNotifier の Provider
final clipboardNotifierProvider =
    NotifierProvider<ClipboardNotifier, ClipboardState>(ClipboardNotifier.new);
