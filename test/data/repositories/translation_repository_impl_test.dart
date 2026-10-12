import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/data/datasources/translation_api_datasource.dart';
import 'package:copy_lot/data/repositories/translation_repository_impl.dart';
import 'package:copy_lot/domain/models/text_type.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';
import 'package:dio/dio.dart';

class _FakeTranslationDatasource extends TranslationApiDatasource {
  _FakeTranslationDatasource() : super(Dio());

  String? lastText;
  String? lastSourceLang;
  String? lastTargetLang;
  int callCount = 0;

  @override
  Future<String> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    lastText = text;
    lastSourceLang = sourceLang;
    lastTargetLang = targetLang;
    return 'Translated: $text';
  }
}

void main() {
  group('TranslationRepositoryImpl', () {
    late _FakeTranslationDatasource datasource;
    late TranslationRepositoryImpl repository;

    setUp(() {
      datasource = _FakeTranslationDatasource();
      repository = TranslationRepositoryImpl(datasource);
    });

    test('skips translation without calling API when language is incompatible', () async {
      // enToJa but contains Japanese
      final res1 = await repository.translate(
        text: 'This is 日本語',
        direction: TranslationDirection.enToJa,
        apiKey: 'test-key',
      );

      expect(res1.isSkipped, isTrue);
      expect(res1.skipReason, contains('英→日モードですが日本語文字が含まれているためスキップしました'));
      expect(datasource.callCount, 0);

      // jaToEn but contains NO Japanese
      final res2 = await repository.translate(
        text: 'English only message',
        direction: TranslationDirection.jaToEn,
        apiKey: 'test-key',
      );

      expect(res2.isSkipped, isTrue);
      expect(res2.skipReason, contains('日→英モードですが日本語文字が含まれていないためスキップしました'));
      expect(datasource.callCount, 0);
    });

    test('calls API with correct language codes and segments word correctly', () async {
      final res = await repository.translate(
        text: 'apple',
        direction: TranslationDirection.enToJa,
        apiKey: 'test-key',
      );

      expect(res.isSkipped, isFalse);
      expect(res.translatedText, 'Translated: apple');
      expect(res.textType, TextType.word);
      expect(datasource.callCount, 1);
      expect(datasource.lastSourceLang, 'en');
      expect(datasource.lastTargetLang, 'ja');
    });

    test('segments sentence correctly for long Japanese text', () async {
      final res = await repository.translate(
        text: '本日は晴天なり。明日の天気はどうなるでしょうか。',
        direction: TranslationDirection.jaToEn,
        apiKey: 'test-key',
      );

      expect(res.isSkipped, isFalse);
      expect(res.textType, TextType.sentence);
      expect(datasource.callCount, 1);
      expect(datasource.lastSourceLang, 'ja');
      expect(datasource.lastTargetLang, 'en');
    });
  });
}
