import '../models/clipboard_event.dart';

/// クリップボード監視の抽象リポジトリ
abstract class ClipboardRepository {
  /// クリップボード更新イベントのブロードキャストストリーム
  Stream<ClipboardEvent> get eventStream;

  /// 現在監視中かどうか
  bool get isListening;

  /// クリップボードの監視を開始（Windows イベントリスナー登録）
  Future<void> startListening();

  /// クリップボードの監視を停止（Windows イベントリスナー解除）
  Future<void> stopListening();

  /// 現在のクリップボードからプレーンテキストを直接取得
  Future<String?> getClipboardText();

  /// リソースを破棄
  void dispose();
}
