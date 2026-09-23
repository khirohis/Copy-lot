/// 翻訳方向を表す列挙型
enum TranslationDirection {
  /// 英語 → 日本語
  enToJa,

  /// 日本語 → 英語
  jaToEn;

  /// 表示ラベル
  String get label {
    switch (this) {
      case TranslationDirection.enToJa:
        return '英語 → 日本語';
      case TranslationDirection.jaToEn:
        return '日本語 → 英語';
    }
  }

  /// 略称ラベル
  String get shortLabel {
    switch (this) {
      case TranslationDirection.enToJa:
        return 'EN → JA';
      case TranslationDirection.jaToEn:
        return 'JA → EN';
    }
  }
}
