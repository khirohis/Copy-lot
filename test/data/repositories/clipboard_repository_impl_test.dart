import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/core/utils/text_guard.dart';
import 'package:copy_lot/data/datasources/win32_clipboard_datasource.dart';
import 'package:copy_lot/data/repositories/clipboard_repository_impl.dart';
import 'package:copy_lot/domain/models/clipboard_event.dart';

class _FakeWin32ClipboardDatasource extends Win32ClipboardDatasource {
  final StreamController<String> _fakeController =
      StreamController<String>.broadcast();

  bool _mockIsListening = false;

  @override
  Stream<String> get onClipboardChanged => _fakeController.stream;

  @override
  bool get isListening => _mockIsListening;

  @override
  void start() {
    _mockIsListening = true;
  }

  @override
  void stop() {
    _mockIsListening = false;
  }

  void emitText(String text) {
    _fakeController.add(text);
  }

  @override
  void dispose() {
    _fakeController.close();
  }
}

void main() {
  group('ClipboardRepositoryImpl', () {
    late _FakeWin32ClipboardDatasource datasource;
    late ClipboardRepositoryImpl repository;

    setUp(() {
      datasource = _FakeWin32ClipboardDatasource();
      repository = ClipboardRepositoryImpl(
        datasource: datasource,
        textGuard: TextGuard(),
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('startListening and stopListening control datasource state', () async {
      expect(repository.isListening, isFalse);

      await repository.startListening();
      expect(repository.isListening, isTrue);

      await repository.stopListening();
      expect(repository.isListening, isFalse);
    });

    test('emits ClipboardEvent when valid text is received', () async {
      final events = <ClipboardEvent>[];
      final sub = repository.eventStream.listen(events.add);

      datasource.emitText('Hello Flutter');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events.length, 1);
      expect(events.first.text, 'Hello Flutter');
      expect(events.first.originalLength, 13);
      expect(events.first.isTruncated, isFalse);

      await sub.cancel();
    });

    test('filters out empty or duplicate texts', () async {
      final events = <ClipboardEvent>[];
      final sub = repository.eventStream.listen(events.add);

      datasource.emitText('Same message');
      datasource.emitText('   '); // Empty whitespace
      datasource.emitText('Same message'); // Duplicate
      datasource.emitText('New message');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events.length, 2);
      expect(events[0].text, 'Same message');
      expect(events[1].text, 'New message');

      await sub.cancel();
    });

    test('truncates texts exceeding 5,000 characters', () async {
      final events = <ClipboardEvent>[];
      final sub = repository.eventStream.listen(events.add);

      final overLength = 'Z' * 5200;
      datasource.emitText(overLength);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events.length, 1);
      expect(events.first.text.length, 5000);
      expect(events.first.originalLength, 5200);
      expect(events.first.isTruncated, isTrue);

      await sub.cancel();
    });
  });
}
