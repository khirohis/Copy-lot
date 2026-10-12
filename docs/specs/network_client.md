# [要件プロンプト] HTTP/2 通信モニタリング機能を備えた汎用 Dio インスタンス生成ファクトリーの実装

## 1. 目的 & スコープ

特定の API（翻訳 API 等）に依存しない、**汎用的な HTTP/2 通信クライアント（`Dio`）を生成するファクトリー基盤**を構築する。
本機能の責務は **「HTTP/2 アダプター、コネクション監視機構、およびメトリクス収集インターセプターが組み込まれた `Dio` インスタンスを生成・提供すること」** に限定する（特定エンドポイントの呼び出しやビジネスロジックは含まない）。
また、UI 状態管理（Riverpod 等）への通知は行わず、**通信メトリクスを保持するデータモデルが更新されたタイミングで即座にログ出力を行う**方針とする。

---

## 2. ディレクトリ配置

KISS 原則に基づき、ネットワーク基盤モジュールとして完結させる。

```text
lib/
└── core/
    └── network/
        ├── dio_factory.dart             # モニタリング機能が設定済みの Dio インスタンスを生成するファクトリー
        ├── network_metrics.dart         # コネクション・通信状態を保持し、更新契機でログ出力するデータモデル
        ├── metrics_interceptor.dart     # リクエスト/レスポンス/エラー時にメトリクスを更新する Interceptor
        └── monitored_http2_adapter.dart # HTTP/2 コネクション確立・再利用・ストリーム数を追跡するカスタムアダプター
```

---

## 3. 機能要件

### 3.1 Dio インスタンス生成ファクトリー (`DioFactory`)

1. **ファクトリー責務:**
   - 共通の通信設定（タイムアウト値、ヘッダー等）を適用した `Dio` インスタンスを生成。
   - `dio_http2_adapter` を用いた **HTTP/2 アダプター** をデフォルト設定。
   - メトリクス監視用のインターセプターおよびアダプターを透過的に組み込む。
2. **基本通信設定（デフォルト値）:**
   - Connect Timeout: 5,000ms
   - Receive Timeout: 5,000ms
   - Send Timeout: 5,000ms

### 3.2 通信モニタリング要件（HTTP/2 前提）

#### A. コネクション & ストリーム監視

- **コネクション確立:**
  - 新規 TCP / TLS (h2) コネクションの確立イベント検知および累積接続数。
- **コネクションプール / 多重化 (Multiplexing) 追跡:**
  - 同一ホストへのリクエストにおいて、既存 HTTP/2 コネクションが再利用（Connection Reuse）されているかの識別。
  - 現在アクティブな多重化ストリーム数（Active Streams）の追跡。
  - コネクション切断・アイドル状態の検知。

#### B. パフォーマンス & レイテンシ監視

- **所要時間計測:**
  - リクエスト送信開始からレスポンスヘッダー受信までの時間 (TTFB)。
  - トータルレスポンス時間 (Total Round-Trip Time)。
- **送受信データサイズ:**
  - リクエストおよびレスポンスのバイト数（Content-Length / 転送量）。

### 3.3 ログ出力要件（データモデル更新連動）

1. **Notifier 不要:**
   - Riverpod や Flutter の UI 状態管理への依存は持たせない。
2. **モデル更新連動ログ出力:**
   - メトリクスを保持するデータモデル（`NetworkMetrics`）の更新メソッドが実行されたタイミングで、整形された構造化ログを出力する。
   - **出力内容例:**
     - `[Network][HTTP/2] host: example.com, reused: true, stream_id: 3, latency: 45ms, status: 200`
     - `[Network][Conn] New connection established to example.com:443 (Total: 1, Active Streams: 1)`

---

## 4. 技術選定 & 実装アプローチ

1. **利用パッケージ:**
   - `dio`: ^5.x
   - `dio_http2_adapter`: ^2.x
2. **レイヤー構造:**
   - **`DioFactory`:**
     - 設定済みの `BaseOptions`、`monitored_http2_adapter`、`metrics_interceptor` を束ねて `Dio` インスタンスを返すファクトリーメソッド（`DioFactory.create()`）を提供。
   - **`monitored_http2_adapter`:**
     - `Http2Adapter` の `ConnectionManager` をフック／ラップし、ソケット接続確立やストリーム生成を検知して `NetworkMetrics` を更新。
   - **`metrics_interceptor`:**
     - `Interceptor` の `onRequest`, `onResponse`, `onError` フックで通信時間やステータスを計測し、`NetworkMetrics` を更新。
   - **`NetworkMetrics`:**
     - 各種メトリクスを保持。更新時に内部でデバッグログ（`dart:developer` の `log` 等）を発行。

---

## 5. 検証基準

1. `DioFactory.create()` で生成したインスタンスが、HTTP/2 対応エンドポイントに対して正常にリクエストを行えること。
2. 連続リクエスト時に、HTTP/2 コネクションの再利用とストリーム多重化が確認できること。
3. リクエスト実行に伴い、データモデルの更新契機でコネクション情報・レイテンシ情報がコンソールへログ出力されること。
4. 静的解析（`flutter analyze`）でエラーおよび lint 警告が発生しないこと。
