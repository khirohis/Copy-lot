import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:copy_lot/domain/models/settings_state.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';
import 'package:copy_lot/domain/models/translation_result.dart';
import 'package:copy_lot/domain/models/text_type.dart';
import 'package:copy_lot/domain/repositories/settings_repository.dart';
import 'package:copy_lot/domain/repositories/translation_repository.dart';
import 'package:copy_lot/presentation/providers/settings_provider.dart';
import 'package:copy_lot/presentation/providers/translation_provider.dart';
import 'package:copy_lot/presentation/screens/settings_screen.dart';

class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository({this.apiKey = ''});

  final String apiKey;

  @override
  Future<SettingsState> loadSettings() async => SettingsState(
        apiKey: apiKey,
        direction: TranslationDirection.enToJa,
      );

  @override
  Future<void> saveApiKey(String apiKey) async {}

  @override
  Future<void> saveDirection(TranslationDirection direction) async {}

  @override
  Future<void> saveAlwaysOnTop(bool isAlwaysOnTop) async {}
}

class MockTranslationRepository implements TranslationRepository {
  MockTranslationRepository({this.shouldThrow = false, this.exception});

  final bool shouldThrow;
  final Exception? exception;
  String? lastValidatedKey;

  @override
  Future<TranslationResult> translate({
    required String text,
    required TranslationDirection direction,
    required String apiKey,
  }) async {
    return TranslationResult(
      sourceText: text,
      translatedText: 'Translated',
      direction: direction,
      textType: TextType.word,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> validateApiKey(String apiKey) async {
    lastValidatedKey = apiKey;
    if (shouldThrow) {
      throw exception ?? const InvalidApiKeyException('無効なキーです');
    }
  }
}

void main() {
  Widget buildTestWidget({
    required SettingsRepository settingsRepo,
    required TranslationRepository translationRepo,
  }) {
    return ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        translationRepositoryProvider.overrideWithValue(translationRepo),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen displays connection test button',
      (WidgetTester tester) async {
    final settingsRepo = MockSettingsRepository(apiKey: 'initial-key');
    final translationRepo = MockTranslationRepository();

    await tester.pumpWidget(
      buildTestWidget(
        settingsRepo: settingsRepo,
        translationRepo: translationRepo,
      ),
    );
    await tester.pumpAndSettle();

    // 接続確認ボタンが存在することを確認
    expect(find.text('接続確認'), findsOneWidget);
    // 初期状態ではインジケーターメッセージが表示されていないことを確認
    expect(find.textContaining('接続確認 OK'), findsNothing);
    expect(find.textContaining('接続確認 NG'), findsNothing);
  });

  testWidgets('Empty API key triggers invalid indicator without calling repository',
      (WidgetTester tester) async {
    final settingsRepo = MockSettingsRepository(apiKey: '');
    final translationRepo = MockTranslationRepository();

    await tester.pumpWidget(
      buildTestWidget(
        settingsRepo: settingsRepo,
        translationRepo: translationRepo,
      ),
    );
    await tester.pumpAndSettle();

    // 接続確認ボタンを押す
    await tester.tap(find.text('接続確認'));
    await tester.pumpAndSettle();

    // エラーインジケーターが表示される
    expect(find.text('API キーを入力してください'), findsOneWidget);
    // リポジトリの validate は呼ばれていない
    expect(translationRepo.lastValidatedKey, isNull);
  });

  testWidgets('Valid API key displays OK indicator',
      (WidgetTester tester) async {
    final settingsRepo = MockSettingsRepository();
    final translationRepo = MockTranslationRepository();

    await tester.pumpWidget(
      buildTestWidget(
        settingsRepo: settingsRepo,
        translationRepo: translationRepo,
      ),
    );
    await tester.pumpAndSettle();

    // API キーを入力
    await tester.enterText(find.byType(TextField), 'valid-api-key');
    await tester.pumpAndSettle();

    // 接続確認ボタンを押す
    await tester.tap(find.text('接続確認'));
    await tester.pumpAndSettle();

    // 有効なキーが検証されたことを確認
    expect(translationRepo.lastValidatedKey, 'valid-api-key');
    // OK インジケーターが表示される
    expect(find.text('接続確認 OK: 有効な API キーです'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('Invalid API key displays NG indicator with error reason',
      (WidgetTester tester) async {
    final settingsRepo = MockSettingsRepository();
    final translationRepo = MockTranslationRepository(
      shouldThrow: true,
      exception: const InvalidApiKeyException('API キーが無効です。'),
    );

    await tester.pumpWidget(
      buildTestWidget(
        settingsRepo: settingsRepo,
        translationRepo: translationRepo,
      ),
    );
    await tester.pumpAndSettle();

    // API キーを入力
    await tester.enterText(find.byType(TextField), 'invalid-api-key');
    await tester.pumpAndSettle();

    // 接続確認ボタンを押す
    await tester.tap(find.text('接続確認'));
    await tester.pumpAndSettle();

    // NG インジケーターとエラーメッセージが表示される
    expect(find.text('接続確認 NG: API キーが無効です。'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('Editing API key resets validation indicator',
      (WidgetTester tester) async {
    final settingsRepo = MockSettingsRepository();
    final translationRepo = MockTranslationRepository();

    await tester.pumpWidget(
      buildTestWidget(
        settingsRepo: settingsRepo,
        translationRepo: translationRepo,
      ),
    );
    await tester.pumpAndSettle();

    // API キーを入力
    await tester.enterText(find.byType(TextField), 'valid-api-key');
    await tester.pumpAndSettle();

    // 接続確認ボタンを押して OK 状態にする
    await tester.tap(find.text('接続確認'));
    await tester.pumpAndSettle();
    expect(find.text('接続確認 OK: 有効な API キーです'), findsOneWidget);

    // テキストフィールドを編集する
    await tester.enterText(find.byType(TextField), 'new-key');
    await tester.pumpAndSettle();

    // インジケーターがリセット（非表示）されたことを確認
    expect(find.text('接続確認 OK: 有効な API キーです'), findsNothing);
  });
}
