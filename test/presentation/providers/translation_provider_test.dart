import 'package:copy_lot/domain/models/settings_state.dart';
import 'package:copy_lot/domain/models/text_type.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';
import 'package:copy_lot/domain/models/translation_result.dart';
import 'package:copy_lot/domain/repositories/settings_repository.dart';
import 'package:copy_lot/domain/repositories/translation_repository.dart';
import 'package:copy_lot/presentation/providers/settings_provider.dart';
import 'package:copy_lot/presentation/providers/translation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockTranslationRepository implements TranslationRepository {
  TranslationResult? stubResult;
  Exception? stubException;
  String? lastTranslatedText;
  TranslationDirection? lastDirection;
  String? lastApiKey;

  @override
  Future<TranslationResult> translate({
    required String text,
    required TranslationDirection direction,
    required String apiKey,
  }) async {
    lastTranslatedText = text;
    lastDirection = direction;
    lastApiKey = apiKey;

    if (stubException != null) {
      throw stubException!;
    }

    return stubResult ??
        TranslationResult(
          sourceText: text,
          translatedText: '翻訳結果: $text',
          direction: direction,
          textType: TextType.sentence,
          timestamp: DateTime.now(),
        );
  }

  @override
  Future<void> validateApiKey(String apiKey) async {}
}

class FakeSettingsNotifier extends SettingsNotifier {
  FakeSettingsNotifier(this.initial);
  final SettingsState initial;

  @override
  SettingsState build() => initial;
}

void main() {
  group('TranslationNotifier', () {
    late MockTranslationRepository mockTranslationRepo;

    ProviderContainer createContainer({
      String apiKey = 'test_api_key',
      TranslationDirection direction = TranslationDirection.enToJa,
    }) {
      mockTranslationRepo = MockTranslationRepository();
      return ProviderContainer(
        overrides: [
          translationRepositoryProvider
              .overrideWithValue(mockTranslationRepo),
          settingsNotifierProvider.overrideWith(
            () => FakeSettingsNotifier(
              SettingsState(
                apiKey: apiKey,
                direction: direction,
                isLoading: false,
              ),
            ),
          ),
        ],
      );
    }

    test('initial state has empty result and isLoading false', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = container.read(translationNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.result, isNull);
      expect(state.errorMessage, isNull);
    });

    test('translate does nothing when text is empty or whitespace only', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(translationNotifierProvider.notifier);
      await notifier.translate('   ');

      expect(mockTranslationRepo.lastTranslatedText, isNull);
      expect(container.read(translationNotifierProvider).isLoading, isFalse);
    });

    test('translate sets errorMessage when API key is missing', () async {
      final container = createContainer(apiKey: '');
      addTearDown(container.dispose);

      // 初期化完了を待機
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(translationNotifierProvider.notifier);
      await notifier.translate('Hello');

      expect(mockTranslationRepo.lastTranslatedText, isNull);
      final state = container.read(translationNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, contains('API キーが設定されていません'));
    });

    test('translate successfully updates state with translation result', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final expectedResult = TranslationResult(
        sourceText: 'Hello',
        translatedText: 'こんにちは',
        direction: TranslationDirection.enToJa,
        textType: TextType.word,
        timestamp: DateTime.now(),
      );
      mockTranslationRepo.stubResult = expectedResult;

      final notifier = container.read(translationNotifierProvider.notifier);
      final future = notifier.translate('Hello');

      // 呼び出し中の状態チェック
      expect(container.read(translationNotifierProvider).isLoading, isTrue);

      await future;

      final state = container.read(translationNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.result?.translatedText, 'こんにちは');
      expect(state.errorMessage, isNull);
      expect(mockTranslationRepo.lastTranslatedText, 'Hello');
      expect(mockTranslationRepo.lastDirection, TranslationDirection.enToJa);
      expect(mockTranslationRepo.lastApiKey, 'test_api_key');
    });

    test('translate captures TranslationException and sets errorMessage', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      mockTranslationRepo.stubException =
          const InvalidApiKeyException('無効なAPIキーです');

      final notifier = container.read(translationNotifierProvider.notifier);
      await notifier.translate('Hello');

      final state = container.read(translationNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.result, isNull);
      expect(state.errorMessage, '無効なAPIキーです');
    });

    test('translate captures unexpected Exception and sets generic errorMessage', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      mockTranslationRepo.stubException = Exception('Network crash');

      final notifier = container.read(translationNotifierProvider.notifier);
      await notifier.translate('Hello');

      final state = container.read(translationNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, contains('予期せぬエラーが発生しました'));
    });

    test('clearError resets errorMessage to null', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      mockTranslationRepo.stubException =
          const InvalidApiKeyException('エラー');

      final notifier = container.read(translationNotifierProvider.notifier);
      await notifier.translate('Hello');
      expect(container.read(translationNotifierProvider).errorMessage, isNotNull);

      notifier.clearError();
      expect(container.read(translationNotifierProvider).errorMessage, isNull);
    });
  });
}
