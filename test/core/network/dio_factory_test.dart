import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http2/http2.dart';
import 'package:copy_lot/core/network/dio_factory.dart';
import 'package:copy_lot/core/network/metrics_interceptor.dart';
import 'package:copy_lot/core/network/monitored_http2_adapter.dart';
import 'package:copy_lot/core/network/network_metrics.dart';

class _FakeClientTransportStream implements ClientTransportStream {
  _FakeClientTransportStream(this.id) {
    _outgoingController.stream.listen((_) {});
    scheduleMicrotask(() {
      if (!_incomingController.isClosed) {
        _incomingController.add(
          HeadersStreamMessage([
            Header.ascii(':status', '200'),
          ]),
        );
      }
    });
  }

  @override
  final int id;

  final StreamController<StreamMessage> _incomingController =
      StreamController<StreamMessage>();
  final StreamController<StreamMessage> _outgoingController =
      StreamController<StreamMessage>();

  @override
  Stream<StreamMessage> get incomingMessages => _incomingController.stream;

  @override
  StreamSink<StreamMessage> get outgoingMessages => _outgoingController.sink;

  @override
  Stream<TransportStreamPush> get peerPushes => const Stream.empty();

  @override
  void sendData(List<int> bytes, {bool endStream = false}) {}

  @override
  void sendHeaders(List<Header> headers, {bool endStream = false}) {}

  @override
  void terminate() {
    _incomingController.close();
  }

  @override
  set onTerminated(void Function(int? p1) value) {}

  void simulateClose() {
    _incomingController.close();
  }
}

class _FakeClientTransportConnection implements ClientTransportConnection {
  ActiveStateHandler? _activeHandler;
  int _streamIdCounter = 1;

  final List<_FakeClientTransportStream> createdStreams = [];

  @override
  bool isOpen = true;

  @override
  Stream<void> get onFrameReceived => const Stream.empty();

  @override
  Future<void> get onInitialPeerSettingsReceived => Future.value();

  @override
  Stream<int> get onPingReceived => const Stream.empty();

  @override
  set onActiveStateChanged(ActiveStateHandler callback) {
    _activeHandler = callback;
  }

  void triggerActiveState(bool active) {
    _activeHandler?.call(active);
  }

  @override
  ClientTransportStream makeRequest(
    List<Header> headers, {
    bool endStream = false,
  }) {
    final stream = _FakeClientTransportStream(_streamIdCounter);
    _streamIdCounter += 2;
    createdStreams.add(stream);
    return stream;
  }

  @override
  Future<dynamic> finish() async {
    isOpen = false;
  }

  @override
  Future<dynamic> terminate([int? errorCode]) async {
    isOpen = false;
  }

  @override
  Future<dynamic> ping() async {}
}

class _FakeConnectionManager implements ConnectionManager {
  final _FakeClientTransportConnection singleConnection =
      _FakeClientTransportConnection();

  @override
  int cachedConnectionsCount = 1;

  @override
  void close({bool force = false}) {
    singleConnection.isOpen = false;
  }

  @override
  Future<ClientTransportConnection> getConnection(
    RequestOptions options,
    List<RedirectRecord> redirects,
  ) async {
    return singleConnection;
  }

  @override
  void removeConnection(ClientTransportConnection transport) {}
}

void main() {
  group('DioFactory', () {
    test('creates Dio instance with default timeouts and monitored HTTP/2 adapter', () {
      final dio = DioFactory.create();

      expect(dio.options.connectTimeout, const Duration(milliseconds: 5000));
      expect(dio.options.receiveTimeout, const Duration(milliseconds: 5000));
      expect(dio.options.sendTimeout, const Duration(milliseconds: 5000));
      expect(dio.httpClientAdapter, isA<MonitoredHttp2Adapter>());
      expect(
        dio.interceptors.whereType<MetricsInterceptor>().isNotEmpty,
        isTrue,
      );
    });

    test('preserves custom BaseOptions overrides', () {
      final dio = DioFactory.create(
        options: BaseOptions(
          baseUrl: 'https://example.com/api',
          connectTimeout: const Duration(milliseconds: 3000),
        ),
      );

      expect(dio.options.baseUrl, 'https://example.com/api');
      expect(dio.options.connectTimeout, const Duration(milliseconds: 3000));
      expect(dio.options.receiveTimeout, const Duration(milliseconds: 5000));
    });
  });

  group('MonitoredHttp2Adapter connection tracking', () {
    late List<String> logs;
    late NetworkMetrics metrics;
    late _FakeConnectionManager fakeManager;
    late MonitoredHttp2Adapter adapter;

    setUp(() {
      logs = [];
      metrics = NetworkMetrics(logHandler: logs.add);
      fakeManager = _FakeConnectionManager();
      adapter = MonitoredHttp2Adapter(
        metrics: metrics,
        connectionManager: fakeManager,
      );
    });

    test('detects new connection vs reused connection and tracks streams', () async {
      // 1st request to example.com
      final options1 = RequestOptions(path: 'https://example.com/test1');
      final response1 = await adapter.fetch(
        options1,
        Stream<Uint8List>.fromIterable([]),
        null,
      );
      expect(response1, isNotNull);
      expect(options1.extra['http2_reused'], isFalse);
      expect(options1.extra['http2_stream_id'], 1);
      expect(metrics.totalConnectionsCreated, 1);
      expect(metrics.activeStreams, 1);

      // 2nd request to same host (reusing connection)
      final options2 = RequestOptions(path: 'https://example.com/test2');
      final response2 = await adapter.fetch(
        options2,
        Stream<Uint8List>.fromIterable([]),
        null,
      );
      expect(response2, isNotNull);
      expect(options2.extra['http2_reused'], isTrue);
      expect(options2.extra['http2_stream_id'], 3);
      expect(metrics.totalConnectionsCreated, 1);
      expect(metrics.activeStreams, 2);

      // Verify stream closure
      fakeManager.singleConnection.createdStreams[0].simulateClose();
      // Allow stream transformer event to propagate
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(metrics.activeStreams, 1);

      fakeManager.singleConnection.createdStreams[1].simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(metrics.activeStreams, 0);

      // Verify log content
      expect(
        logs.any((l) => l.contains('[Network][Conn] New connection established to example.com:443')),
        isTrue,
      );
      expect(
        logs.any((l) => l.contains('stream_id: 1, reused: false')),
        isTrue,
      );
      expect(
        logs.any((l) => l.contains('stream_id: 3, reused: true')),
        isTrue,
      );
    });
  });

  group('MetricsInterceptor', () {
    test('logs response latency and status on response', () async {
      final logs = <String>[];
      final metrics = NetworkMetrics(logHandler: logs.add);

      final dio = Dio();
      dio.interceptors.add(MetricsInterceptor(metrics: metrics));
      dio.httpClientAdapter = _TestEchoAdapter();

      final res = await dio.get<String>(
        'https://example.com/items',
        options: Options(
          extra: {
            'http2_reused': true,
            'http2_stream_id': 5,
          },
        ),
      );

      expect(res.statusCode, 200);
      expect(logs.length, 1);
      expect(
        logs.first,
        contains('[Network][HTTP/2] host: example.com, reused: true, stream_id: 5, latency:'),
      );
      expect(logs.first, contains('status: 200'));
    });

    test('logs error details on request failure', () async {
      final logs = <String>[];
      final metrics = NetworkMetrics(logHandler: logs.add);

      final dio = Dio();
      dio.interceptors.add(MetricsInterceptor(metrics: metrics));
      dio.httpClientAdapter = _TestErrorAdapter();

      expect(
        () => dio.get<String>('https://example.com/fail'),
        throwsA(isA<DioException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(logs.length, 1);
      expect(
        logs.first,
        contains('[Network][HTTP/2][Error] host: example.com, reused: false, stream_id: unknown'),
      );
      expect(logs.first, contains('status: 500'));
    });
  });
}

class _TestEchoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"status":"ok"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        Headers.contentLengthHeader: ['15'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TestErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      'Internal Server Error',
      500,
      headers: {
        Headers.contentLengthHeader: ['21'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
