import 'dart:async';
import 'package:copy_lot/domain/models/clipboard_event.dart';
import 'package:copy_lot/domain/models/settings_state.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';
import 'package:copy_lot/domain/repositories/clipboard_repository.dart';
import 'package:copy_lot/presentation/providers/clipboard_provider.dart';
import 'package:copy_lot/presentation/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockClipboardLifecycleRepository implements ClipboardRepository {
  final StreamController<ClipboardEvent> _controller =
      StreamController<ClipboardEvent>.broadcast();

  bool _isListening = false;
  String? currentClipboardContent;

  @override
  Stream<ClipboardEvent> get eventStream => _controller.stream;

  @override
  bool get isListening => _isListening;

  @override
  Future<void> startListening() async {
    _isListening = true;
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
  }

  @override
  Future<String?> getClipboardText() async {
    return currentClipboardContent;
  }

  void emitEvent(ClipboardEvent event) {
    if (_isListening) {
      _controller.add(event);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class FakeLifecycleSettingsNotifier extends SettingsNotifier {
  FakeLifecycleSettingsNotifier(this.initial);
  final SettingsState initial;

  @override
  SettingsState build() => initial;
}

void main() {
  group('Clipboard Lifecycle & Auto-Monitoring Tests (docs/specs/clipboard_lifecycle.md)', () {
    late MockClipboardLifecycleRepository mockRepo;

    ProviderContainer createContainer({
      String apiKey = 'valid_api_key_123',
    }) {
      mockRepo = MockClipboardLifecycleRepository();
      return ProviderContainer(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(mockRepo),
          settingsNotifierProvider.overrideWith(
            () => FakeLifecycleSettingsNotifier(
              SettingsState(
                apiKey: apiKey,
                direction: TranslationDirection.enToJa,
                isLoading: false,
              ),
            ),
          ),
        ],
      );
    }

    test('1. 初期状態テスト: アプリ起動直後は自動監視トグルがOFF、リスナー停止', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = container.read(clipboardNotifierProvider);

      expect(state.isAutoMonitoringEnabled, isFalse,
          reason: 'アプリ起動時は常に自動監視OFFから開始（非永続化・毎回リセット）');
      expect(state.isWindowVisible, isTrue,
          reason: '起動直後はウィンドウが表示状態');
      expect(state.isListening, isFalse,
          reason: 'トグルOFFのため実効監視は停止状態');
      expect(mockRepo.isListening, isFalse,
          reason: 'リポジトリのネイティブリスナーも未登録');
    });

    test('2. API キーガードテスト: API キーが無効または空の場合、トグルをONにできない', () async {
      final container = createContainer(apiKey: '');
      addTearDown(container.dispose);

      final notifier = container.read(clipboardNotifierProvider.notifier);

      // APIキー未設定の状態でトグルONを試みる
      await notifier.toggleAutoMonitoring(true);

      final state = container.read(clipboardNotifierProvider);
      expect(state.isAutoMonitoringEnabled, isFalse,
          reason: 'APIキー未設定時はトグルONにできずOFFを維持');
      expect(state.isListening, isFalse);
      expect(mockRepo.isListening, isFalse);
    });

    test('3. トグル切り替え & 即時評価テスト: トグルをONにした瞬間、現在のクリップボードテキストを取得して反映し監視開始', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      mockRepo.currentClipboardContent = 'Hello Antigravity';

      final notifier = container.read(clipboardNotifierProvider.notifier);
      await notifier.toggleAutoMonitoring(true);

      final state = container.read(clipboardNotifierProvider);
      expect(state.isAutoMonitoringEnabled, isTrue);
      expect(state.isListening, isTrue);
      expect(mockRepo.isListening, isTrue);
      expect(state.currentText, 'Hello Antigravity',
          reason: 'ON に切り替えた瞬間、既存クリップボードテキストを参照して即座に取り込む');
    });

    test('4. トグルOFFテスト: トグルをOFFにするとリスナー解除され、以降のイベントを無視する', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(clipboardNotifierProvider.notifier);
      await notifier.toggleAutoMonitoring(true);
      expect(container.read(clipboardNotifierProvider).isListening, isTrue);

      // トグルOFF
      await notifier.toggleAutoMonitoring(false);
      final state = container.read(clipboardNotifierProvider);
      expect(state.isAutoMonitoringEnabled, isFalse);
      expect(state.isListening, isFalse);
      expect(mockRepo.isListening, isFalse);

      // 以降のイベント発行
      mockRepo.emitEvent(ClipboardEvent(
        text: 'New copied text',
        originalLength: 15,
        isTruncated: false,
        timestamp: DateTime.now(),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(container.read(clipboardNotifierProvider).currentText, isNot('New copied text'),
          reason: '監視停止中は新しいクリップボードイベントを取り込まない');
    });

    test('5. システムトレイ格納テスト: ウィンドウ非表示（トレイ格納）時はリスナー完全停止し、トグル状態は保持', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(clipboardNotifierProvider.notifier);
      await notifier.toggleAutoMonitoring(true);
      expect(container.read(clipboardNotifierProvider).isListening, isTrue);

      // 最小化または「×」押下によりトレイ格納（非表示化）
      await notifier.setWindowVisibility(false);

      final state = container.read(clipboardNotifierProvider);
      expect(state.isWindowVisible, isFalse);
      expect(state.isAutoMonitoringEnabled, isTrue,
          reason: 'トレイ格納時もメモリ上のトグル状態は保持');
      expect(state.isListening, isFalse,
          reason: '非表示時は実効監視状態がfalseとなり完全停止');
      expect(mockRepo.isListening, isFalse,
          reason: 'ネイティブリスナーが解除されていること');
    });

    test('6. トレイ復帰 & 状態維持テスト: 格納前にONだった場合、復帰時にリスナー再開し既存テキストを参照', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(clipboardNotifierProvider.notifier);
      await notifier.toggleAutoMonitoring(true);

      // トレイ格納
      await notifier.setWindowVisibility(false);
      expect(container.read(clipboardNotifierProvider).isListening, isFalse);

      // 留守中に他アプリでコピーされたテキスト
      mockRepo.currentClipboardContent = 'Copied during tray minimized';

      // トレイからウィンドウ復帰
      await notifier.setWindowVisibility(true);

      final state = container.read(clipboardNotifierProvider);
      expect(state.isWindowVisible, isTrue);
      expect(state.isAutoMonitoringEnabled, isTrue,
          reason: '格納直前のトグルONが復元される');
      expect(state.isListening, isTrue,
          reason: 'トグルON復元に伴いリスナーが自動再開される');
      expect(mockRepo.isListening, isTrue);
      expect(state.currentText, 'Copied during tray minimized',
          reason: '復帰時に現在のクリップボードテキストを参照して即時反映');
    });

    test('6-b. トレイ復帰テスト (格納前がOFF): 格納前にOFFだった場合、復帰時もOFFを維持し停止継続', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(clipboardNotifierProvider.notifier);
      // トグルOFFのまま
      expect(container.read(clipboardNotifierProvider).isAutoMonitoringEnabled, isFalse);

      // トレイ格納
      await notifier.setWindowVisibility(false);
      // トレイ復帰
      await notifier.setWindowVisibility(true);

      final state = container.read(clipboardNotifierProvider);
      expect(state.isWindowVisible, isTrue);
      expect(state.isAutoMonitoringEnabled, isFalse,
          reason: '格納直前のOFFを復元');
      expect(state.isListening, isFalse,
          reason: '停止状態を維持');
      expect(mockRepo.isListening, isFalse);
    });

    test('7. 手動ペーストテスト: 自動監視OFFでも手動ペーストでテキスト取得・反映可能', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      mockRepo.currentClipboardContent = 'Manual Paste Content';

      final notifier = container.read(clipboardNotifierProvider.notifier);
      // 自動監視はOFF
      expect(container.read(clipboardNotifierProvider).isAutoMonitoringEnabled, isFalse);

      // 手動ペースト実行
      await notifier.pasteAndTranslate();

      final state = container.read(clipboardNotifierProvider);
      expect(state.currentText, 'Manual Paste Content',
          reason: '手動ペーストによりテキストが取り込まれる');
      expect(state.isAutoMonitoringEnabled, isFalse,
          reason: '手動ペーストしても自動監視トグルはOFFのまま維持');
      expect(state.isListening, isFalse,
          reason: '実効監視も停止のまま維持');
    });
  });
}
