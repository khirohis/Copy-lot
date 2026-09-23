import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/secure_storage_datasource.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/models/settings_state.dart';
import '../../domain/models/translation_direction.dart';
import '../../domain/repositories/settings_repository.dart';

/// リポジトリの Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final datasource = SecureStorageDatasource();
  return SettingsRepositoryImpl(datasource);
});

/// 設定状態を管理する Notifier
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // 初期状態は読み込み中
    state = const SettingsState(isLoading: true);
    _init();
    return state;
  }

  Future<void> _init() async {
    final repo = ref.read(settingsRepositoryProvider);
    final loaded = await repo.loadSettings();
    state = loaded;
  }

  /// API キーの更新と保存
  Future<void> updateApiKey(String apiKey) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveApiKey(apiKey.trim());
    state = state.copyWith(apiKey: apiKey.trim());
  }

  /// 翻訳方向の切り替えと保存
  Future<void> setDirection(TranslationDirection direction) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveDirection(direction);
    state = state.copyWith(direction: direction);
  }

  /// 最前面固定（Always on Top）の切り替えと保存
  Future<void> toggleAlwaysOnTop() async {
    final newValue = !state.isAlwaysOnTop;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveAlwaysOnTop(newValue);
    state = state.copyWith(isAlwaysOnTop: newValue);
  }
}

/// SettingsNotifier の Provider
final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
