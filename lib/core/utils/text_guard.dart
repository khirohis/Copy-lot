/// クリップボードテキストのガード処理結果
class GuardResult {
  const GuardResult({
    required this.isValid,
    this.processedText = '',
    this.isTruncated = false,
    this.originalLength = 0,
    this.skipReason,
  });

  /// 処理対象として有効かどうか
  final bool isValid;

  /// トリム・文字数制限適用後のテキスト
  final String processedText;

  /// 上限（5,000文字）を超過して切り詰められたかどうか
  final bool isTruncated;

  /// 原文の文字数
  final int originalLength;

  /// スキップされた理由（無効な場合）
  final SkipReason? skipReason;
}

/// クリップボード取得をスキップする理由
enum SkipReason {
  /// 空白または空文字
  empty,

  /// 直前に取得したテキストと同一
  duplicate,
}

/// クリップボードから取得したテキストのバリデーション・ガード機構
class TextGuard {
  TextGuard({this.maxLength = defaultMaxLength});

  /// 仕様上のデフォルト最大文字数 (5,000文字)
  static const int defaultMaxLength = 5000;

  /// 許容する最大文字数
  final int maxLength;

  /// 直前に処理されたテキストのキャッシュ（同一テキスト連続取得防止用）
  String? _lastProcessedText;

  /// 直前のテキストを取得
  String? get lastProcessedText => _lastProcessedText;

  /// キャッシュをクリア
  void reset() {
    _lastProcessedText = null;
  }

  /// テキストを検証・正規化し、ガード結果を返す
  GuardResult process(String rawText) {
    final trimmed = rawText.trim();

    // 1. 空白・空文字ガード
    if (trimmed.isEmpty) {
      return const GuardResult(
        isValid: false,
        skipReason: SkipReason.empty,
      );
    }

    // 2. 同一テキスト連続取得防止ガード
    if (trimmed == _lastProcessedText) {
      return GuardResult(
        isValid: false,
        originalLength: rawText.length,
        skipReason: SkipReason.duplicate,
      );
    }

    // 3. 上限（5,000文字）ガード
    final isTruncated = trimmed.length > maxLength;
    final processed = isTruncated ? trimmed.substring(0, maxLength) : trimmed;

    // キャッシュ更新
    _lastProcessedText = trimmed;

    return GuardResult(
      isValid: true,
      processedText: processed,
      isTruncated: isTruncated,
      originalLength: rawText.length,
    );
  }
}
