import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/core/network/network_metrics.dart';

void main() {
  group('NetworkMetrics', () {
    late List<String> logs;
    late NetworkMetrics metrics;

    setUp(() {
      logs = [];
      metrics = NetworkMetrics(logHandler: logs.add);
    });

    test('initial state is zeroed', () {
      expect(metrics.totalConnectionsCreated, 0);
      expect(metrics.activeConnections, 0);
      expect(metrics.activeStreams, 0);
      expect(metrics.lastLatencyMs, 0);
      expect(metrics.totalBytesSent, 0);
      expect(metrics.totalBytesReceived, 0);
    });

    test('recordNewConnection logs and updates counters', () {
      metrics.recordNewConnection(host: 'example.com', port: 443);

      expect(metrics.totalConnectionsCreated, 1);
      expect(metrics.activeConnections, 1);
      expect(logs.length, 1);
      expect(
        logs.first,
        '[Network][Conn] New connection established to example.com:443 (Total: 1, Active Streams: 0)',
      );
    });

    test('recordConnectionClosed decrements activeConnections', () {
      metrics.recordNewConnection(host: 'example.com', port: 443);
      metrics.recordConnectionClosed(host: 'example.com', port: 443);

      expect(metrics.totalConnectionsCreated, 1);
      expect(metrics.activeConnections, 0);
      expect(logs.length, 2);
      expect(
        logs.last,
        '[Network][Conn] Connection closed for example.com:443 (Active Streams: 0)',
      );
    });

    test('recordStreamCreated and recordStreamClosed track activeStreams', () {
      metrics.recordStreamCreated(host: 'example.com', streamId: 1, reused: false);
      expect(metrics.activeStreams, 1);
      expect(
        logs.last,
        '[Network][Stream] Stream created on example.com (stream_id: 1, reused: false, Active Streams: 1)',
      );

      metrics.recordStreamCreated(host: 'example.com', streamId: 3, reused: true);
      expect(metrics.activeStreams, 2);

      metrics.recordStreamClosed(host: 'example.com', streamId: 1);
      expect(metrics.activeStreams, 1);

      metrics.recordStreamClosed(host: 'example.com', streamId: 3);
      expect(metrics.activeStreams, 0);
    });

    test('recordHttpResponse logs structured output and updates latency/bytes', () {
      metrics.recordHttpResponse(
        host: 'example.com',
        reused: true,
        streamId: 3,
        latencyMs: 45,
        statusCode: 200,
        bytesSent: 120,
        bytesReceived: 1024,
      );

      expect(metrics.lastLatencyMs, 45);
      expect(metrics.totalBytesSent, 120);
      expect(metrics.totalBytesReceived, 1024);
      expect(logs.length, 1);
      expect(
        logs.first,
        '[Network][HTTP/2] host: example.com, reused: true, stream_id: 3, latency: 45ms, status: 200',
      );
    });

    test('recordHttpError logs structured error output', () {
      metrics.recordHttpError(
        host: 'example.com',
        reused: false,
        streamId: 1,
        latencyMs: 120,
        errorMessage: 'Connection timed out',
        statusCode: 504,
      );

      expect(metrics.lastLatencyMs, 120);
      expect(logs.length, 1);
      expect(
        logs.first,
        '[Network][HTTP/2][Error] host: example.com, reused: false, stream_id: 1, latency: 120ms, status: 504, error: Connection timed out',
      );
    });
  });
}
