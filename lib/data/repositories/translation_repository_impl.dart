import '../../core/utils/language_guard.dart';
import '../../core/utils/text_segmenter.dart';
import '../../domain/models/translation_direction.dart';
import '../../domain/models/translation_result.dart';
import '../../domain/repositories/translation_repository.dart';
import '../datasources/translation_api_datasource.dart';

/// TranslationRepository の具象実装クラス
class TranslationRepositoryImpl implements TranslationRepository {
  TranslationRepositoryImpl(this._datasource);

  final TranslationApiDatasource _datasource;

  @override
  Future<TranslationResult> translate({
    required String text,
    required TranslationDirection direction,
    required String apiKey,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult.skipped(
        sourceText: text,
        direction: direction,
        skipReason: 'テキストが空です',
      );
    }

    // 1. 言語適合チェック（実行トリガガード）
    final isCompatible = LanguageGuard.isCompatible(
      text: trimmed,
      direction: direction,
    );

    if (!isCompatible) {
      final reason = direction == TranslationDirection.enToJa
          ? '英→日モードですが日本語文字が含まれているためスキップしました'
          : '日→英モードですが日本語文字が含まれていないためスキップしました';

      return TranslationResult.skipped(
        sourceText: text,
        direction: direction,
        skipReason: reason,
      );
    }

    // 2. 単語 / 文章の境界判定
    final textType = TextSegmenter.segment(
      text: trimmed,
      direction: direction,
    );

    // 3. 言語コードの決定
    final String sourceLang;
    final String targetLang;
    switch (direction) {
      case TranslationDirection.enToJa:
        sourceLang = 'en';
        targetLang = 'ja';
        break;
      case TranslationDirection.jaToEn:
        sourceLang = 'ja';
        targetLang = 'en';
        break;
    }

    // 4. API 呼び出し
    final translatedText = await _datasource.translateText(
      text: trimmed,
      sourceLang: sourceLang,
      targetLang: targetLang,
      apiKey: apiKey,
    );

    return TranslationResult(
      sourceText: text,
      translatedText: translatedText,
      direction: direction,
      textType: textType,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> validateApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const InvalidApiKeyException('API キーが入力されていません。');
    }

    await _datasource.translateText(
      text: 'test',
      sourceLang: 'en',
      targetLang: 'ja',
      apiKey: trimmed,
    );
  }
}
