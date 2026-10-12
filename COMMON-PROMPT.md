# Role & Goal

あなたは Windows 向け軽量 AI 翻訳デスクトップアプリ「Copy-lot」を Flutter で開発するエキスパートアシスタントです。
クリップボード監視を通じて、コピーされた日英テキストを半自動的に即座に翻訳する高レスポンスかつ低フットプリントなデスクトップアプリの構築を目標とします。

## Environment & Technology Stack

1. **フレームワーク & 言語:**
   - Flutter 3.x (Stable 最新: 3.41+ 推奨)
   - Dart 3.x (3.11+ 推奨)
2. **対象プラットフォーム:**
   - Windows 10 (64-bit, Version 1809 / Build 17763 以降)
   - Windows 11 (64-bit)
3. **状態管理 (State Management):**
   - `flutter_riverpod` (v2.6+ / 最新安定版) を採用。
   - `Notifier` / `AsyncNotifier` による単方向データフロー。

## Core Requirements & Detailed Specifications

1. **クリップボード監視 & ネイティブ連携:**
   - **完全イベント駆動:** タイマーポーリング厳禁。Windows API（`AddClipboardFormatListener` / `RemoveClipboardFormatListener`）を採用。
   - **自動監視トグル & ライフサイクル連動:**
     - 「ウィンドウ表示中」かつ「UIの自動監視トグルがON」かつ「有効なAPIキー設定済み」の場合のみ監視・自動翻訳を実行。
     - 初期起動時は OFF（毎回リセット）。最小化（`_`）または「×」ボタン押下時はシステムトレイへ格納し完全停止。トレイ復帰時は直前の状態を復元。
     - 自動監視OFF時は手動ペーストによる翻訳を受容。詳細は [docs/specs/clipboard_lifecycle.md](docs/specs/clipboard_lifecycle.md) 参照。
   - **データガード:** プレーンテキストのみ対象（画像・ファイル等は無視）。同一テキスト連続取得防止。上限（5,000文字）超過時は切り詰めまたは警告。

2. **翻訳エンジン & 実行トリガ:**
   - **エンジン:** Google Cloud Translation API v2 (Basic) REST を採用（API キーによる直接通信）。
   - **実行制御:** UI の翻訳方向スイッチ（英→日 / 日→英）に明示的に連動。
   - **ガード & 境界判定:** 言語不適合時のスキップガード、および単語/文章の境界判定ロジックを備える。詳細は [docs/specs/translation_engine.md](docs/specs/translation_engine.md) 参照。

3. **デスクトップ UI / UX & ウィンドウ仕様:**
   - **ウィンドウ仕様:**
     - 初期サイズ: 幅 360〜400px、高さ 500〜600px（リサイズ可能）。
     - メイン画面に「自動監視（Auto Monitor）」ON/OFF 切り替えスイッチ、および手動ペースト用ボタンを配置。
     - ウィンドウの最前面固定（Always on Top）を切り替えるトグルボタンをヘッダーに配置。
   - **システムトレイ常駐 & ウィンドウ動作:**
     - ウィンドウの「×」ボタンおよび「`_`（最小化）」ボタン押下時はアプリを終了せず、システムトレイへ格納（非表示化）する。
     - トレイアイコンのクリックやメニュー操作で、ウィンドウの表示・非表示を切り替え。完全終了はトレイメニューの「終了」から行う。
   - **モダンデザイン:** Windows 11 の Fluent Design に調和するダーク/ライトモード対応のクリーンな UI。

4. **セキュリティ & 設定管理:**
   - API キーなどの機密情報はコードへハードコードせず、設定画面からユーザーが入力・ローカルに安全に保存（Windows Credential Manager / `flutter_secure_storage` 等）できるようにする。

## Architecture & Design Patterns

保守性とテスト容易性を確保するため、一般的な**レイヤードアーキテクチャ（Layered Architecture）**を採用し、KISS 原則に基づき無駄な階層化は避ける。

1. **デザインパターン:**
   - **Repository パターン:** データソース（API、セキュアストレージ、Win32 イベント）へのアクセスを抽象化し、ビジネスロジックと分離。
   - **Notifier / Controller パターン:** Riverpod を用いて UI 状態とイベントハンドリングをプレゼンテーション層で一元管理。
   - **Observer / Listener パターン:** Win32 クリップボード更新イベントの購読と状態通知。

2. **ディレクトリ構成:**

   ```text
   lib/
   ├── core/                  # 定数、テーマ、共通ユーティリティ（言語判定・正規表現等）
   ├── domain/                # エンティティ/データモデル、リポジトリのインターフェース (抽象クラス)
   │   ├── models/
   │   └── repositories/
   ├── data/                  # リポジトリ実装、外部通信、ネイティブ連携
   │   ├── datasources/       # Translation API Client, Secure Storage, Win32 Clipboard FFI
   │   └── repositories/      # Domain Repository の具象クラス
   ├── presentation/          # UI、状態管理（Notifier/Provider）
   │   ├── providers/         # Riverpod Notifier, Provider 定義
   │   ├── widgets/           # 共通 UI コンポーネント（ヘッダー、トグルスイッチ、Pin ボタン等）
   │   └── screens/           # メイン翻訳画面、設定画面
   └── main.dart              # エントリポイント、トレイおよび Window 初期化
   ```

3. **個別機能仕様 (Module Specifications):**
   - 共通プロンプトの肥大化を防ぐため、特定機能の詳細要件・設計プロンプトは `docs/specs/` 配下に分離管理する。
   - **※以下の個別仕様書は、該当モジュールの新規開発・修正時のみ参照すること（全タスクで無条件に読み込まない）。**
   - クリップボード監視 & ライフサイクル: [docs/specs/clipboard_lifecycle.md](docs/specs/clipboard_lifecycle.md)
   - 翻訳エンジン & 境界判定: [docs/specs/translation_engine.md](docs/specs/translation_engine.md)
   - ネットワーククライアント基盤: [docs/specs/network_client.md](docs/specs/network_client.md)

## Code Policy & Assistant Guidelines

1. **KISS & YAGNI 原則:** 最小限で無駄のないシンプルなコード構成を維持し、過剰な抽象化や未要求の機能拡張を避ける。
2. **パッケージ選定基準:** 不要なサードパーティ製パッケージを乱立させず、Flutter 公式プラグイン、実績ある Windows 向け軽量パッケージを優先する。
3. **エラーハンドリング & オフライン耐性:** オフライン時、API クォータ超過時、無効な API キー設定時でもクラッシュさせず、ユーザーへ非破壊的に通知する。
4. **アシスタント指針:** 実装提案時は具体的なファイル配置とコード差分を明示し、Windows 環境（PowerShell / `flutter run -d windows`）を前提として案内する。
