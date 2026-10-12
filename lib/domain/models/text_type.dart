/// 原文テキストの種別（単語 or 文章）
enum TextType {
  /// 単語（2単語以下の英語、または句読点なし15文字以内の日本語）
  word,

  /// 文章（複数文または長文）
  sentence;

  String get label {
    switch (this) {
      case TextType.word:
        return '単語';
      case TextType.sentence:
        return '文章';
    }
  }
}
