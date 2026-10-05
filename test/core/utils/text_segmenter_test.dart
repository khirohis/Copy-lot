import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/core/utils/text_segmenter.dart';
import 'package:copy_lot/domain/models/text_type.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';

void main() {
  group('TextSegmenter', () {
    test('enToJa segments 2 or fewer words without punctuation as word', () {
      expect(
        TextSegmenter.segment(
          text: 'apple',
          direction: TranslationDirection.enToJa,
        ),
        TextType.word,
      );

      expect(
        TextSegmenter.segment(
          text: 'ice cream',
          direction: TranslationDirection.enToJa,
        ),
        TextType.word,
      );

      // 3 words -> sentence
      expect(
        TextSegmenter.segment(
          text: 'hot apple pie',
          direction: TranslationDirection.enToJa,
        ),
        TextType.sentence,
      );

      // With sentence end mark -> sentence
      expect(
        TextSegmenter.segment(
          text: 'Run!',
          direction: TranslationDirection.enToJa,
        ),
        TextType.sentence,
      );
    });

    test('jaToEn segments 15 chars or fewer without 。 or newline as word', () {
      expect(
        TextSegmenter.segment(
          text: 'りんご',
          direction: TranslationDirection.jaToEn,
        ),
        TextType.word,
      );

      expect(
        TextSegmenter.segment(
          text: '人工知能技術の開発', // 9文字
          direction: TranslationDirection.jaToEn,
        ),
        TextType.word,
      );

      // Over 15 chars -> sentence
      expect(
        TextSegmenter.segment(
          text: 'これは十五文字を明確に超過している日本語の文章です', // 24文字
          direction: TranslationDirection.jaToEn,
        ),
        TextType.sentence,
      );

      // Contains 。 -> sentence
      expect(
        TextSegmenter.segment(
          text: '了解です。',
          direction: TranslationDirection.jaToEn,
        ),
        TextType.sentence,
      );

      // Contains newline -> sentence
      expect(
        TextSegmenter.segment(
          text: 'りんご\nみかん',
          direction: TranslationDirection.jaToEn,
        ),
        TextType.sentence,
      );
    });
  });
}
