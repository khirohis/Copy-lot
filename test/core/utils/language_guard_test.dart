import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/core/utils/language_guard.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';

void main() {
  group('LanguageGuard', () {
    test('enToJa returns true only when text contains NO Japanese characters', () {
      expect(
        LanguageGuard.isCompatible(
          text: 'Hello World! How are you?',
          direction: TranslationDirection.enToJa,
        ),
        isTrue,
      );

      expect(
        LanguageGuard.isCompatible(
          text: 'Hello こんにちは',
          direction: TranslationDirection.enToJa,
        ),
        isFalse,
      );

      expect(
        LanguageGuard.isCompatible(
          text: '東京 Tower',
          direction: TranslationDirection.enToJa,
        ),
        isFalse,
      );
    });

    test('jaToEn returns true only when text contains Japanese characters', () {
      expect(
        LanguageGuard.isCompatible(
          text: 'こんにちは世界',
          direction: TranslationDirection.jaToEn,
        ),
        isTrue,
      );

      expect(
        LanguageGuard.isCompatible(
          text: 'Flutterアプリのテスト',
          direction: TranslationDirection.jaToEn,
        ),
        isTrue,
      );

      expect(
        LanguageGuard.isCompatible(
          text: 'Just plain English',
          direction: TranslationDirection.jaToEn,
        ),
        isFalse,
      );
    });

    test('empty text returns false', () {
      expect(
        LanguageGuard.isCompatible(
          text: '   ',
          direction: TranslationDirection.enToJa,
        ),
        isFalse,
      );
    });
  });
}
