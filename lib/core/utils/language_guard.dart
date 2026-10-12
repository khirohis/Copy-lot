import '../../domain/models/translation_direction.dart';

/// 翻訳実行前の言語適合チェック（実行トリガガード）
class LanguageGuard {
  LanguageGuard._();

  /// 日本語文字（ひらがな・カタカナ・漢字）を検出する正規表現
  static final RegExp _japaneseRegex = RegExp(
    r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]',
  );

  /// テキストが指定された翻訳方向に適合しているかどうかを判定する
  static bool isCompatible({
    required String text,
    required TranslationDirection direction,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final hasJapanese = _japaneseRegex.hasMatch(trimmed);

    switch (direction) {
      case TranslationDirection.jaToEn:
        // 日→英モード: 日本語文字が 1 文字以上含まれる場合のみ実行
        return hasJapanese;

      case TranslationDirection.enToJa:
        // 英→日モード: 日本語文字を含まない場合のみ実行
        return !hasJapanese;
    }
  }
}
