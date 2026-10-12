import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:http2/http2.dart';
import 'network_metrics.dart';

/// A custom [Http2Adapter] that transparently tracks HTTP/2 connection reuse,
/// stream multiplexing, and updates [NetworkMetrics].
class MonitoredHttp2Adapter extends Http2Adapter {
  MonitoredHttp2Adapter({
    NetworkMetrics? metrics,
    ConnectionManager? connectionManager,
    super.fallbackAdapter,
    super.onNotSupported,
  })  : metrics = metrics ?? NetworkMetrics(),
        super(
          _MonitoredConnectionManager(
            metrics ?? NetworkMetrics(),
            connectionManager ?? ConnectionManager(),
          ),
        );

  /// The metrics instance monitoring this adapter.
  final NetworkMetrics metrics;
}

class _MonitoredConnectionManager implements ConnectionManager {
  _MonitoredConnectionManager(this.metrics, this._inner);

  final NetworkMetrics metrics;
  final ConnectionManager _inner;
  final Set<ClientTransportConnection> _knownTransports =
      <ClientTransportConnection>{};

  @override
  // ignore: invalid_use_of_visible_for_testing_member
  int get cachedConnectionsCount => _inner.cachedConnectionsCount;

  @override
  void close({bool force = false}) {
    _knownTransports.clear();
    _inner.close(force: force);
  }

  @override
  Future<ClientTransportConnection> getConnection(
    RequestOptions options,
    List<RedirectRecord> redirects,
  ) async {
    final transport = await _inner.getConnection(options, redirects);
    final host = options.uri.host;
    final port = options.uri.port;

    final isReused = _knownTransports.contains(transport);
    if (!isReused) {
      _knownTransports.add(transport);
      metrics.recordNewConnection(
        host: host,
        port: port,
        activeStreamsCount: metrics.activeStreams,
      );
    }

    options.extra['http2_reused'] = isReused;
    options.extra['network_metrics'] = metrics;

    return _MonitoredClientTransportConnection(
      transport,
      metrics: metrics,
      host: host,
      port: port,
      isReused: isReused,
      options: options,
      onClosed: () {
        _knownTransports.remove(transport);
      },
    );
  }

  @override
  void removeConnection(ClientTransportConnection transport) {
    if (transport is _MonitoredClientTransportConnection) {
      _knownTransports.remove(transport._inner);
      _inner.removeConnection(transport._inner);
    } else {
      _knownTransports.remove(transport);
      _inner.removeConnection(transport);
    }
  }
}

class _MonitoredClientTransportConnection implements ClientTransportConnection {
  _MonitoredClientTransportConnection(
    this._inner, {
    required this.metrics,
    required this.host,
    required this.port,
    required this.isReused,
    required this.options,
    required this.onClosed,
  });

  final ClientTransportConnection _inner;
  final NetworkMetrics metrics;
  final String host;
  final int port;
  final bool isReused;
  final RequestOptions options;
  final void Function() onClosed;

  @override
  bool get isOpen => _inner.isOpen;

  @override
  Stream<void> get onFrameReceived => _inner.onFrameReceived;

  @override
  Future<void> get onInitialPeerSettingsReceived =>
      _inner.onInitialPeerSettingsReceived;

  @override
  Stream<int> get onPingReceived => _inner.onPingReceived;

  @override
  set onActiveStateChanged(ActiveStateHandler callback) {
    _inner.onActiveStateChanged = (isActive) {
      metrics.recordConnectionStateChanged(host: host, isActive: isActive);
      callback(isActive);
    };
  }

  @override
  ClientTransportStream makeRequest(
    List<Header> headers, {
    bool endStream = false,
  }) {
    final stream = _inner.makeRequest(headers, endStream: endStream);
    options.extra['http2_stream_id'] = stream.id;

    metrics.recordStreamCreated(
      host: host,
      streamId: stream.id,
      reused: isReused,
    );

    return _MonitoredClientTransportStream(
      stream,
      metrics: metrics,
      host: host,
    );
  }

  @override
  Future<dynamic> finish() {
    onClosed();
    metrics.recordConnectionClosed(host: host, port: port);
    return _inner.finish();
  }

  @override
  Future<dynamic> terminate([int? errorCode]) {
    onClosed();
    metrics.recordConnectionClosed(host: host, port: port);
    return _inner.terminate(errorCode);
  }

  @override
  Future<dynamic> ping() => _inner.ping();
}

class _MonitoredClientTransportStream implements ClientTransportStream {
  _MonitoredClientTransportStream(
    this._inner, {
    required this.metrics,
    required this.host,
  }) {
    _incomingMessages = _inner.incomingMessages.transform(
      StreamTransformer<StreamMessage, StreamMessage>.fromHandlers(
        handleData: (data, sink) => sink.add(data),
        handleError: (error, stackTrace, sink) =>
            sink.addError(error, stackTrace),
        handleDone: (sink) {
          _closeStreamOnce();
          sink.close();
        },
      ),
    );
  }

  final ClientTransportStream _inner;
  final NetworkMetrics metrics;
  final String host;
  late final Stream<StreamMessage> _incomingMessages;
  bool _closed = false;

  void _closeStreamOnce() {
    if (!_closed) {
      _closed = true;
      metrics.recordStreamClosed(host: host, streamId: _inner.id);
    }
  }

  @override
  int get id => _inner.id;

  @override
  Stream<StreamMessage> get incomingMessages => _incomingMessages;

  @override
  StreamSink<StreamMessage> get outgoingMessages => _inner.outgoingMessages;

  @override
  Stream<TransportStreamPush> get peerPushes => _inner.peerPushes;

  @override
  void sendData(List<int> bytes, {bool endStream = false}) {
    _inner.sendData(bytes, endStream: endStream);
  }

  @override
  void sendHeaders(List<Header> headers, {bool endStream = false}) {
    _inner.sendHeaders(headers, endStream: endStream);
  }

  @override
  void terminate() {
    _closeStreamOnce();
    _inner.terminate();
  }

  @override
  set onTerminated(void Function(int? p1) value) {
    _inner.onTerminated = (code) {
      _closeStreamOnce();
      value(code);
    };
  }
}
