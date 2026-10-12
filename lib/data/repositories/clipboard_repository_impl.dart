import 'dart:async';

import '../../core/utils/text_guard.dart';
import '../../domain/models/clipboard_event.dart';
import '../../domain/repositories/clipboard_repository.dart';
import '../datasources/win32_clipboard_datasource.dart';

/// ClipboardRepository の具象実装クラス
class ClipboardRepositoryImpl implements ClipboardRepository {
  ClipboardRepositoryImpl({
    Win32ClipboardDatasource? datasource,
    TextGuard? textGuard,
  })  : _datasource = datasource ?? Win32ClipboardDatasource(),
        _textGuard = textGuard ?? TextGuard() {
    _subscription = _datasource.onClipboardChanged.listen(_handleRawText);
  }

  final Win32ClipboardDatasource _datasource;
  final TextGuard _textGuard;
  late final StreamSubscription<String> _subscription;

  final StreamController<ClipboardEvent> _eventController =
      StreamController<ClipboardEvent>.broadcast();

  @override
  Stream<ClipboardEvent> get eventStream => _eventController.stream;

  @override
  bool get isListening => _datasource.isListening;

  @override
  Future<void> startListening() async {
    _datasource.start();
  }

  @override
  Future<void> stopListening() async {
    _datasource.stop();
  }

  void _handleRawText(String rawText) {
    final guardResult = _textGuard.process(rawText);
    if (!guardResult.isValid) {
      // 空白文字のみ、または直前のテキストと重複しているため無視
      return;
    }

    final event = ClipboardEvent(
      text: guardResult.processedText,
      originalLength: guardResult.originalLength,
      isTruncated: guardResult.isTruncated,
      timestamp: DateTime.now(),
    );

    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _datasource.dispose();
    _eventController.close();
  }
}
