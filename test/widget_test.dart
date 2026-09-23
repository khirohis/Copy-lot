import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:copy_lot/domain/models/settings_state.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';
import 'package:copy_lot/domain/repositories/settings_repository.dart';
import 'package:copy_lot/app.dart';
import 'package:copy_lot/presentation/providers/settings_provider.dart';

/// テスト用のダミーリポジトリ
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({String apiKey = 'test-api-key'})
      : _state = SettingsState(
          apiKey: apiKey,
          direction: TranslationDirection.enToJa,
        );

  SettingsState _state;

  @override
  Future<SettingsState> loadSettings() async => _state;

  @override
  Future<void> saveApiKey(String apiKey) async {
    _state = _state.copyWith(apiKey: apiKey);
  }

  @override
  Future<void> saveDirection(TranslationDirection direction) async {
    _state = _state.copyWith(direction: direction);
  }

  @override
  Future<void> saveAlwaysOnTop(bool isAlwaysOnTop) async {
    _state = _state.copyWith(isAlwaysOnTop: isAlwaysOnTop);
  }
}

void main() {
  testWidgets('MainScreen UI smoke test (with API key)', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        ],
        child: const CopyLotApp(),
      ),
    );

    await tester.pumpAndSettle();

    // ヘッダータイトルの存在確認
    expect(find.text('Copy-lot'), findsOneWidget);

    // 翻訳方向スイッチの存在確認
    expect(find.text('英語 → 日本語'), findsOneWidget);
    expect(find.text('日本語 → 英語'), findsOneWidget);

    // 原文・翻訳カードのタイトル確認
    expect(find.text('原文 (Source)'), findsOneWidget);
    expect(find.text('翻訳 (Translation)'), findsOneWidget);

    // ステータスバーの確認
    expect(find.text('クリップボード監視待機中'), findsOneWidget);
  });

  testWidgets('Redirects to SettingsScreen when API key is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(FakeSettingsRepository(apiKey: '')),
        ],
        child: const CopyLotApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 設定画面のタイトルが表示されていることを確認（自動プッシュされた）
    expect(find.text('設定'), findsOneWidget);
    expect(find.text('Google Cloud Translation API'), findsOneWidget);
    expect(find.text('ご利用を開始するには、Google Cloud Translation API キーの設定が必要です。'),
        findsOneWidget);
  });
}
