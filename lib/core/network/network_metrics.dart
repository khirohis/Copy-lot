import 'dart:developer' as developer;

/// Callback signature for handling structured network logs.
typedef NetworkLogHandler = void Function(String message);

/// Holds network and connection metrics and outputs structured logs on updates.
///
/// Designed to be decoupled from UI state management (Riverpod/Flutter Notifiers)
/// in accordance with KISS principles.
class NetworkMetrics {
  NetworkMetrics({NetworkLogHandler? logHandler})
      : _logHandler = logHandler ?? _defaultLogger;

  final NetworkLogHandler _logHandler;

  int _totalConnectionsCreated = 0;
  int _activeConnections = 0;
  int _activeStreams = 0;
  int _lastLatencyMs = 0;
  int _totalBytesSent = 0;
  int _totalBytesReceived = 0;

  /// Total number of newly established TCP / TLS (h2) connections.
  int get totalConnectionsCreated => _totalConnectionsCreated;

  /// Current number of active connections.
  int get activeConnections => _activeConnections;

  /// Current number of multiplexed active HTTP/2 streams.
  int get activeStreams => _activeStreams;

  /// Latency of the most recent request in milliseconds.
  int get lastLatencyMs => _lastLatencyMs;

  /// Total bytes sent across requests.
  int get totalBytesSent => _totalBytesSent;

  /// Total bytes received across responses.
  int get totalBytesReceived => _totalBytesReceived;

  static void _defaultLogger(String message) {
    developer.log(message, name: 'CopyLot.Network');
  }

  /// Records the establishment of a new HTTP/2 connection and emits a structured log.
  void recordNewConnection({
    required String host,
    required int port,
    int? activeStreamsCount,
  }) {
    _totalConnectionsCreated++;
    _activeConnections++;
    if (activeStreamsCount != null) {
      _activeStreams = activeStreamsCount;
    }
    _logHandler(
      '[Network][Conn] New connection established to $host:$port (Total: $_totalConnectionsCreated, Active Streams: $_activeStreams)',
    );
  }

  /// Records a connection close or termination.
  void recordConnectionClosed({
    required String host,
    required int port,
  }) {
    if (_activeConnections > 0) {
      _activeConnections--;
    }
    _logHandler(
      '[Network][Conn] Connection closed for $host:$port (Active Streams: $_activeStreams)',
    );
  }

  /// Records connection state change (e.g. active / idle).
  void recordConnectionStateChanged({
    required String host,
    required bool isActive,
  }) {
    _logHandler(
      '[Network][Conn] Connection state changed for $host: isActive=$isActive (Active Streams: $_activeStreams)',
    );
  }

  /// Records the creation of an HTTP/2 stream.
  void recordStreamCreated({
    required String host,
    required int streamId,
    required bool reused,
  }) {
    _activeStreams++;
    _logHandler(
      '[Network][Stream] Stream created on $host (stream_id: $streamId, reused: $reused, Active Streams: $_activeStreams)',
    );
  }

  /// Records the closure/completion of an HTTP/2 stream.
  void recordStreamClosed({
    required String host,
    required int streamId,
  }) {
    if (_activeStreams > 0) {
      _activeStreams--;
    }
  }

  /// Records an HTTP/2 response and emits the structured log.
  void recordHttpResponse({
    required String host,
    required bool reused,
    int? streamId,
    required int latencyMs,
    required int statusCode,
    int? bytesSent,
    int? bytesReceived,
  }) {
    _lastLatencyMs = latencyMs;
    if (bytesSent != null) {
      _totalBytesSent += bytesSent;
    }
    if (bytesReceived != null) {
      _totalBytesReceived += bytesReceived;
    }

    final streamIdStr = streamId != null ? streamId.toString() : 'unknown';
    _logHandler(
      '[Network][HTTP/2] host: $host, reused: $reused, stream_id: $streamIdStr, latency: ${latencyMs}ms, status: $statusCode',
    );
  }

  /// Records an HTTP error and emits the structured error log.
  void recordHttpError({
    required String host,
    required bool reused,
    int? streamId,
    required int latencyMs,
    required String errorMessage,
    int? statusCode,
  }) {
    _lastLatencyMs = latencyMs;
    final streamIdStr = streamId != null ? streamId.toString() : 'unknown';
    final statusStr = statusCode != null ? ', status: $statusCode' : '';
    _logHandler(
      '[Network][HTTP/2][Error] host: $host, reused: $reused, stream_id: $streamIdStr, latency: ${latencyMs}ms$statusStr, error: $errorMessage',
    );
  }
}
