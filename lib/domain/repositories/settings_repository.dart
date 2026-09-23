import '../models/settings_state.dart';
import '../models/translation_direction.dart';

/// 設定アクセスの抽象リポジトリ
abstract class SettingsRepository {
  /// 保存されている設定状態をロード
  Future<SettingsState> loadSettings();

  /// API キーをセキュアに保存
  Future<void> saveApiKey(String apiKey);

  /// 翻訳方向を保存
  Future<void> saveDirection(TranslationDirection direction);

  /// 最前面固定状態を保存
  Future<void> saveAlwaysOnTop(bool isAlwaysOnTop);
}
