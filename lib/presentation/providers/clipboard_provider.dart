import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/clipboard_repository_impl.dart';
import '../../domain/models/clipboard_event.dart';
import '../../domain/models/clipboard_state.dart';
import '../../domain/repositories/clipboard_repository.dart';

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

    return ClipboardState(isListening: repo.isListening);
  }

  void _onClipboardEvent(ClipboardEvent event) {
    state = state.copyWith(
      currentText: event.text,
      originalLength: event.originalLength,
      isTruncated: event.isTruncated,
      lastUpdated: event.timestamp,
    );
  }

  /// クリップボード監視を開始
  Future<void> startListening() async {
    final repo = ref.read(clipboardRepositoryProvider);
    await repo.startListening();
    state = state.copyWith(isListening: repo.isListening);
  }

  /// クリップボード監視を停止
  Future<void> stopListening() async {
    final repo = ref.read(clipboardRepositoryProvider);
    await repo.stopListening();
    state = state.copyWith(isListening: repo.isListening);
  }
}

/// ClipboardNotifier の Provider
final clipboardNotifierProvider =
    NotifierProvider<ClipboardNotifier, ClipboardState>(ClipboardNotifier.new);
