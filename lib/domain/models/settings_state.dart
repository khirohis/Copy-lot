import 'translation_direction.dart';

/// アプリケーションの設定状態
class SettingsState {
  const SettingsState({
    this.apiKey = '',
    this.direction = TranslationDirection.enToJa,
    this.isAlwaysOnTop = false,
    this.isLoading = false,
  });

  /// Google Cloud Translation API キー
  final String apiKey;

  /// 選択されている翻訳方向
  final TranslationDirection direction;

  /// ウィンドウの最前面固定
  final bool isAlwaysOnTop;

  /// 読み込み中フラグ
  final bool isLoading;

  /// APIキーが設定されているかどうか
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  SettingsState copyWith({
    String? apiKey,
    TranslationDirection? direction,
    bool? isAlwaysOnTop,
    bool? isLoading,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      direction: direction ?? this.direction,
      isAlwaysOnTop: isAlwaysOnTop ?? this.isAlwaysOnTop,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
