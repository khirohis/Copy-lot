import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/domain/models/clipboard_event.dart';
import 'package:copy_lot/domain/repositories/clipboard_repository.dart';
import 'package:copy_lot/presentation/providers/clipboard_provider.dart';

class _MockClipboardRepository implements ClipboardRepository {
  final StreamController<ClipboardEvent> _controller =
      StreamController<ClipboardEvent>.broadcast();

  bool _mockIsListening = false;

  @override
  Stream<ClipboardEvent> get eventStream => _controller.stream;

  @override
  bool get isListening => _mockIsListening;

  @override
  Future<void> startListening() async {
    _mockIsListening = true;
  }

  @override
  Future<void> stopListening() async {
    _mockIsListening = false;
  }

  void emitEvent(ClipboardEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  group('ClipboardNotifier', () {
    late _MockClipboardRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = _MockClipboardRepository();
      container = ProviderContainer(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      mockRepo.dispose();
    });

    test('initial state has empty text and repository isListening status', () {
      final state = container.read(clipboardNotifierProvider);
      expect(state.currentText, '');
      expect(state.isListening, isFalse);
    });

    test('startListening and stopListening updates isListening state', () async {
      final notifier = container.read(clipboardNotifierProvider.notifier);

      await notifier.startListening();
      expect(container.read(clipboardNotifierProvider).isListening, isTrue);

      await notifier.stopListening();
      expect(container.read(clipboardNotifierProvider).isListening, isFalse);
    });

    test('updates state when eventStream emits ClipboardEvent', () async {
      // Initialize listener
      container.read(clipboardNotifierProvider);

      final event = ClipboardEvent(
        text: 'Copied string',
        originalLength: 13,
        isTruncated: false,
        timestamp: DateTime.now(),
      );

      mockRepo.emitEvent(event);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(clipboardNotifierProvider);
      expect(state.currentText, 'Copied string');
      expect(state.originalLength, 13);
      expect(state.isTruncated, isFalse);
    });
  });
}
