import '../../domain/models/text_type.dart';
import '../../domain/models/translation_direction.dart';

/// 単語 / 文章の境界判定ユーティリティ
class TextSegmenter {
  TextSegmenter._();

  static final RegExp _sentenceEndRegex = RegExp(r'[.!?]');
  static final RegExp _japanesePunctuationRegex = RegExp(r'[。\n]');

  /// 原文テキストと翻訳方向に基づき、単語 (word) か文章 (sentence) かを判定する
  static TextType segment({
    required String text,
    required TranslationDirection direction,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return TextType.sentence;

    switch (direction) {
      case TranslationDirection.enToJa:
        // 英語: 空白区切りの単語数が 2 単語以下かつ文末記号（.!?）を含まないものを「単語」と判定
        final words = trimmed
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();

        final hasSentenceEnd = _sentenceEndRegex.hasMatch(trimmed);

        if (words.length <= 2 && !hasSentenceEnd) {
          return TextType.word;
        }
        return TextType.sentence;

      case TranslationDirection.jaToEn:
        // 日本語: 句読点（。）・改行を含まず、文字数が 15 文字以内を「単語」と判定
        final hasPunctuationOrNewline = _japanesePunctuationRegex.hasMatch(trimmed);

        if (!hasPunctuationOrNewline && trimmed.length <= 15) {
          return TextType.word;
        }
        return TextType.sentence;
    }
  }
}
