import 'dart:io';
import 'package:dio/dio.dart';

import '../../domain/repositories/translation_repository.dart';

/// Google Cloud Translation API v2 (Basic) クライアントデータソース
class TranslationApiDatasource {
  TranslationApiDatasource(this._dio);

  final Dio _dio;

  static const String _endpoint =
      'https://translation.googleapis.com/language/translate/v2';

  /// Google Cloud Translation API v2 を呼び出してテキストを翻訳する
  Future<String> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const InvalidApiKeyException();
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        queryParameters: {
          'key': apiKey.trim(),
        },
        data: {
          'q': text,
          'source': sourceLang,
          'target': targetLang,
          'format': 'text',
        },
        cancelToken: cancelToken,
      );

      final data = response.data?['data'] as Map<String, dynamic>?;
      final translations = data?['translations'] as List<dynamic>?;

      if (translations != null && translations.isNotEmpty) {
        final first = translations.first as Map<String, dynamic>;
        final translatedText = first['translatedText'] as String? ?? '';
        return _unescapeHtml(translatedText);
      }

      return '';
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      if (e is TranslationException) rethrow;
      throw ApiServerException(e.toString());
    }
  }

  /// DioException をドメイン層の TranslationException にマッピング
  TranslationException _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.error is SocketException) {
      return const NetworkOfflineException();
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 400 || statusCode == 403) {
      // 400 (Bad Request: API key not valid) / 403 (Permission denied / Key invalid)
      return const InvalidApiKeyException();
    } else if (statusCode == 429) {
      // 429 (Too Many Requests / Quota Exceeded)
      return const QuotaExceededException();
    }

    String? serverMessage;
    final resData = e.response?.data;
    if (resData is Map) {
      final errorMap = resData['error'];
      if (errorMap is Map) {
        serverMessage = errorMap['message']?.toString();
      }
    }

    return ApiServerException(
      serverMessage ?? e.message ?? '通信エラーが発生しました',
      statusCode,
    );
  }

  /// Google Translation API の応答に含まれる HTML エンティティのデコード
  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
