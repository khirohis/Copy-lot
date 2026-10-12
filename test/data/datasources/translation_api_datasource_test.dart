import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/data/datasources/translation_api_datasource.dart';
import 'package:copy_lot/domain/repositories/translation_repository.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter({
    required this.handler,
  });

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('TranslationApiDatasource', () {
    late Dio dio;
    late TranslationApiDatasource datasource;

    setUp(() {
      dio = Dio();
      datasource = TranslationApiDatasource(dio);
    });

    test('throws InvalidApiKeyException if apiKey is empty', () async {
      expect(
        () => datasource.translateText(
          text: 'hello',
          sourceLang: 'en',
          targetLang: 'ja',
          apiKey: '',
        ),
        throwsA(isA<InvalidApiKeyException>()),
      );
    });

    test('successfully parses translated text and unescapes HTML entities', () async {
      dio.httpClientAdapter = _MockHttpAdapter(
        handler: (options) async {
          expect(options.queryParameters['key'], 'valid-key');
          final body = {
            'data': {
              'translations': [
                {
                  'translatedText': 'Tom &amp; Jerry &#39;Special&#39;',
                  'detectedSourceLanguage': 'en',
                }
              ]
            }
          };

          return ResponseBody.fromString(
            jsonEncode(body),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      final result = await datasource.translateText(
        text: 'Tom & Jerry',
        sourceLang: 'en',
        targetLang: 'ja',
        apiKey: 'valid-key',
      );

      expect(result, "Tom & Jerry 'Special'");
    });

    test('maps 400 and 403 status to InvalidApiKeyException', () async {
      dio.httpClientAdapter = _MockHttpAdapter(
        handler: (options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 400,
                'message': 'API key not valid. Please pass a valid API key.',
              }
            }),
            400,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      expect(
        () => datasource.translateText(
          text: 'test',
          sourceLang: 'en',
          targetLang: 'ja',
          apiKey: 'bad-key',
        ),
        throwsA(isA<InvalidApiKeyException>()),
      );
    });

    test('maps 429 status to QuotaExceededException', () async {
      dio.httpClientAdapter = _MockHttpAdapter(
        handler: (options) async {
          return ResponseBody.fromString(
            'Rate limit exceeded',
            429,
          );
        },
      );

      expect(
        () => datasource.translateText(
          text: 'test',
          sourceLang: 'en',
          targetLang: 'ja',
          apiKey: 'valid-key',
        ),
        throwsA(isA<QuotaExceededException>()),
      );
    });

    test('maps connection error to NetworkOfflineException', () async {
      dio.httpClientAdapter = _MockHttpAdapter(
        handler: (options) async {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'No internet connection',
          );
        },
      );

      expect(
        () => datasource.translateText(
          text: 'test',
          sourceLang: 'en',
          targetLang: 'ja',
          apiKey: 'valid-key',
        ),
        throwsA(isA<NetworkOfflineException>()),
      );
    });
  });
}
