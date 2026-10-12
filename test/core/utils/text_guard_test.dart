import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/core/utils/text_guard.dart';

void main() {
  group('TextGuard', () {
    late TextGuard guard;

    setUp(() {
      guard = TextGuard();
    });

    test('valid text returns isValid = true', () {
      final result = guard.process('Hello World');

      expect(result.isValid, isTrue);
      expect(result.processedText, 'Hello World');
      expect(result.isTruncated, isFalse);
      expect(result.originalLength, 11);
      expect(result.skipReason, isNull);
    });

    test('empty or whitespace only text is skipped', () {
      final emptyResult = guard.process('');
      expect(emptyResult.isValid, isFalse);
      expect(emptyResult.skipReason, SkipReason.empty);

      final whitespaceResult = guard.process('   \n\t  ');
      expect(whitespaceResult.isValid, isFalse);
      expect(whitespaceResult.skipReason, SkipReason.empty);
    });

    test('duplicate sequential text is skipped', () {
      final first = guard.process('Important note');
      expect(first.isValid, isTrue);

      // Same text copied again
      final second = guard.process('Important note');
      expect(second.isValid, isFalse);
      expect(second.skipReason, SkipReason.duplicate);

      // Same text with extra whitespace is also detected as duplicate
      final third = guard.process('  Important note  \n');
      expect(third.isValid, isFalse);
      expect(third.skipReason, SkipReason.duplicate);

      // Different text is accepted
      final fourth = guard.process('Different note');
      expect(fourth.isValid, isTrue);

      // First text copied again after different text is accepted
      final fifth = guard.process('Important note');
      expect(fifth.isValid, isTrue);
    });

    test('text exceeding max length is truncated to 5,000 characters', () {
      const customMax = 100;
      final customGuard = TextGuard(maxLength: customMax);

      final longText = 'A' * 150;
      final result = customGuard.process(longText);

      expect(result.isValid, isTrue);
      expect(result.isTruncated, isTrue);
      expect(result.originalLength, 150);
      expect(result.processedText.length, 100);
      expect(result.processedText, 'A' * 100);
    });

    test('defaultMaxLength is 5,000 characters', () {
      expect(TextGuard.defaultMaxLength, 5000);

      final over5000 = 'x' * 5050;
      final result = guard.process(over5000);

      expect(result.isValid, isTrue);
      expect(result.isTruncated, isTrue);
      expect(result.processedText.length, 5000);
      expect(result.originalLength, 5050);
    });

    test('reset clears the cached last processed text', () {
      guard.process('hello');
      guard.reset();

      // After reset, same text should be accepted again
      final result = guard.process('hello');
      expect(result.isValid, isTrue);
    });
  });
}
