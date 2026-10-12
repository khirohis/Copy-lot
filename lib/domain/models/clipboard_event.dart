/// クリップボードから取得・ガードされたテキストイベント
class ClipboardEvent {
  const ClipboardEvent({
    required this.text,
    required this.originalLength,
    required this.isTruncated,
    required this.timestamp,
  });

  /// 処理済みテキスト（上限5,000文字適用済み）
  final String text;

  /// 切り詰め前の元文字数
  final int originalLength;

  /// 5,000文字上限を超過して切り詰められたかどうか
  final bool isTruncated;

  /// クリップボードから取得された日時
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardEvent &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          originalLength == other.originalLength &&
          isTruncated == other.isTruncated &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      text.hashCode ^
      originalLength.hashCode ^
      isTruncated.hashCode ^
      timestamp.hashCode;

  @override
  String toString() =>
      'ClipboardEvent(text: ${text.length > 20 ? '${text.substring(0, 20)}...' : text}, isTruncated: $isTruncated, timestamp: $timestamp)';
}
