import 'text_type.dart';
import 'translation_direction.dart';

/// 翻訳処理の結果データモデル
class TranslationResult {
  const TranslationResult({
    required this.sourceText,
    required this.translatedText,
    required this.direction,
    required this.textType,
    this.candidates = const [],
    required this.timestamp,
    this.isSkipped = false,
    this.skipReason,
  });

  /// スキップされた場合のファクトリ
  factory TranslationResult.skipped({
    required String sourceText,
    required TranslationDirection direction,
    required String skipReason,
  }) {
    return TranslationResult(
      sourceText: sourceText,
      translatedText: '',
      direction: direction,
      textType: TextType.sentence,
      timestamp: DateTime.now(),
      isSkipped: true,
      skipReason: skipReason,
    );
  }

  /// 原文テキスト
  final String sourceText;

  /// 翻訳結果テキスト
  final String translatedText;

  /// 翻訳方向
  final TranslationDirection direction;

  /// 単語または文章の種別
  final TextType textType;

  /// 訳語候補リスト（単語判定時の別訳など）
  final List<String> candidates;

  /// 翻訳完了タイムスタンプ
  final DateTime timestamp;

  /// 言語不適合等でスキップされたかどうか
  final bool isSkipped;

  /// スキップされた場合の理由
  final String? skipReason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationResult &&
          runtimeType == other.runtimeType &&
          sourceText == other.sourceText &&
          translatedText == other.translatedText &&
          direction == other.direction &&
          textType == other.textType &&
          isSkipped == other.isSkipped;

  @override
  int get hashCode =>
      sourceText.hashCode ^
      translatedText.hashCode ^
      direction.hashCode ^
      textType.hashCode ^
      isSkipped.hashCode;
}
