/// クリップボード監視に関する UI 状態モデル
class ClipboardState {
  const ClipboardState({
    this.currentText = '',
    this.originalLength = 0,
    this.isTruncated = false,
    this.isListening = false,
    this.isAutoMonitoringEnabled = false,
    this.isWindowVisible = true,
    this.lastUpdated,
  });

  /// 最新のクリップボード取得テキスト（5,000文字ガード適用済み）
  final String currentText;

  /// 切り詰め前の元文字数
  final int originalLength;

  /// 5,000文字上限を超過して切り詰められたかどうか
  final bool isTruncated;

  /// 実効監視中かどうか（Windows API リスナーが登録中か）
  final bool isListening;

  /// UI の自動監視トグルが有効化されているかどうか（デフォルト: false）
  final bool isAutoMonitoringEnabled;

  /// ウィンドウが表示中かどうか（デフォルト: true、トレイ格納時: false）
  final bool isWindowVisible;

  /// 最終取得・更新日時
  final DateTime? lastUpdated;

  /// 有効なテキストが存在するかどうか
  bool get hasText => currentText.trim().isNotEmpty;

  ClipboardState copyWith({
    String? currentText,
    int? originalLength,
    bool? isTruncated,
    bool? isListening,
    bool? isAutoMonitoringEnabled,
    bool? isWindowVisible,
    DateTime? lastUpdated,
  }) {
    return ClipboardState(
      currentText: currentText ?? this.currentText,
      originalLength: originalLength ?? this.originalLength,
      isTruncated: isTruncated ?? this.isTruncated,
      isListening: isListening ?? this.isListening,
      isAutoMonitoringEnabled:
          isAutoMonitoringEnabled ?? this.isAutoMonitoringEnabled,
      isWindowVisible: isWindowVisible ?? this.isWindowVisible,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardState &&
          runtimeType == other.runtimeType &&
          currentText == other.currentText &&
          originalLength == other.originalLength &&
          isTruncated == other.isTruncated &&
          isListening == other.isListening &&
          isAutoMonitoringEnabled == other.isAutoMonitoringEnabled &&
          isWindowVisible == other.isWindowVisible &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode =>
      currentText.hashCode ^
      originalLength.hashCode ^
      isTruncated.hashCode ^
      isListening.hashCode ^
      isAutoMonitoringEnabled.hashCode ^
      isWindowVisible.hashCode ^
      lastUpdated.hashCode;
}
