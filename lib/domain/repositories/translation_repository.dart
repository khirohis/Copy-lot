import '../models/translation_direction.dart';
import '../models/translation_result.dart';

/// 翻訳エラーの基底例外クラス
sealed class TranslationException implements Exception {
  const TranslationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// ネットワーク接続エラー（オフライン等）
class NetworkOfflineException extends TranslationException {
  const NetworkOfflineException([
    super.message = 'ネットワークに接続されていません。接続を確認してください。',
  ]);
}

/// API キーが無効または未設定
class InvalidApiKeyException extends TranslationException {
  const InvalidApiKeyException([
    super.message = 'Google Cloud Translation API キーが無効または設定されていません。',
  ]);
}

/// API クォータ・利用制限超過 (429)
class QuotaExceededException extends TranslationException {
  const QuotaExceededException([
    super.message = 'Translation API のクォータ（利用制限）を超過しました。しばらく待ってから再試行してください。',
  ]);
}

/// その他の一般的な API エラー
class ApiServerException extends TranslationException {
  const ApiServerException([
    super.message = '翻訳サーバーとの通信でエラーが発生しました。',
    this.statusCode,
  ]);
  final int? statusCode;
}

/// 翻訳リポジトリの抽象インターフェース
abstract class TranslationRepository {
  /// 原文テキストを指定の方向で翻訳する
  Future<TranslationResult> translate({
    required String text,
    required TranslationDirection direction,
    required String apiKey,
  });

  /// API キーの有効性を検証する（接続テスト用）
  Future<void> validateApiKey(String apiKey);
}
