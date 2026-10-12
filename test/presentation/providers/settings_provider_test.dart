import 'package:copy_lot/domain/models/settings_state.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';
import 'package:copy_lot/domain/repositories/settings_repository.dart';
import 'package:copy_lot/presentation/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository({
    this.initialState = const SettingsState(
      apiKey: 'initial_key',
      direction: TranslationDirection.enToJa,
      isAlwaysOnTop: false,
      isLoading: false,
    ),
  });

  SettingsState initialState;
  String? savedApiKey;
  TranslationDirection? savedDirection;
  bool? savedAlwaysOnTop;

  @override
  Future<SettingsState> loadSettings() async => initialState;

  @override
  Future<void> saveApiKey(String apiKey) async {
    savedApiKey = apiKey;
  }

  @override
  Future<void> saveDirection(TranslationDirection direction) async {
    savedDirection = direction;
  }

  @override
  Future<void> saveAlwaysOnTop(bool isAlwaysOnTop) async {
    savedAlwaysOnTop = isAlwaysOnTop;
  }
}

void main() {
  group('SettingsNotifier', () {
    late MockSettingsRepository mockRepository;
    late ProviderContainer container;

    setUp(() {
      mockRepository = MockSettingsRepository();
      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial load initializes state from repository', () async {
      // 最初の状態監視で読み込みがトリガーされる
      final state = container.read(settingsNotifierProvider);
      expect(state.isLoading, isTrue);

      // 非同期初期化の完了を待機
      await Future<void>.delayed(Duration.zero);

      final loadedState = container.read(settingsNotifierProvider);
      expect(loadedState.isLoading, isFalse);
      expect(loadedState.apiKey, 'initial_key');
      expect(loadedState.direction, TranslationDirection.enToJa);
      expect(loadedState.isAlwaysOnTop, isFalse);
    });

    test('updateApiKey updates state and saves to repository', () async {
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(settingsNotifierProvider.notifier);
      await notifier.updateApiKey('  new_api_key  ');

      expect(mockRepository.savedApiKey, 'new_api_key');
      expect(container.read(settingsNotifierProvider).apiKey, 'new_api_key');
    });

    test('setDirection updates state and saves to repository', () async {
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(settingsNotifierProvider.notifier);
      await notifier.setDirection(TranslationDirection.jaToEn);

      expect(mockRepository.savedDirection, TranslationDirection.jaToEn);
      expect(container.read(settingsNotifierProvider).direction,
          TranslationDirection.jaToEn);
    });

    test('toggleAlwaysOnTop toggles state and saves to repository', () async {
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(settingsNotifierProvider.notifier);
      await notifier.toggleAlwaysOnTop();

      expect(mockRepository.savedAlwaysOnTop, isTrue);
      expect(container.read(settingsNotifierProvider).isAlwaysOnTop, isTrue);

      await notifier.toggleAlwaysOnTop();
      expect(mockRepository.savedAlwaysOnTop, isFalse);
      expect(container.read(settingsNotifierProvider).isAlwaysOnTop, isFalse);
    });
  });
}
