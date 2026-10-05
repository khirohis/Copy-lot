import 'dart:convert';
import 'package:dio/dio.dart';
import 'network_metrics.dart';

/// Interceptor that tracks request/response latency, payload sizes,
/// and updates [NetworkMetrics].
class MetricsInterceptor extends Interceptor {
  MetricsInterceptor({required this.metrics});

  final NetworkMetrics metrics;

  static const String _startTimeKey = '_request_start_time_epoch_ms';
  static const String _bytesSentKey = '_request_bytes_sent';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startTimeKey] = DateTime.now().millisecondsSinceEpoch;

    // Calculate request payload size if available.
    int bytesSent = 0;
    final data = options.data;
    if (data is List<int>) {
      bytesSent = data.length;
    } else if (data is String) {
      bytesSent = utf8.encode(data).length;
    } else if (data is Map || data is List) {
      try {
        bytesSent = utf8.encode(jsonEncode(data)).length;
      } catch (_) {
        bytesSent = 0;
      }
    } else if (options.headers[Headers.contentLengthHeader] != null) {
      bytesSent =
          int.tryParse(options.headers[Headers.contentLengthHeader].toString()) ??
              0;
    }
    options.extra[_bytesSentKey] = bytesSent;

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final startTime = response.requestOptions.extra[_startTimeKey] as int?;
    final latency = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : 0;

    final bytesSent = response.requestOptions.extra[_bytesSentKey] as int?;
    final contentLengthHeader =
        response.headers.value(Headers.contentLengthHeader);
    int? bytesReceived =
        contentLengthHeader != null ? int.tryParse(contentLengthHeader) : null;

    if (bytesReceived == null && response.data != null) {
      final data = response.data;
      if (data is List<int>) {
        bytesReceived = data.length;
      } else if (data is String) {
        bytesReceived = utf8.encode(data).length;
      }
    }

    final reused =
        response.requestOptions.extra['http2_reused'] as bool? ?? false;
    final streamId =
        response.requestOptions.extra['http2_stream_id'] as int?;

    metrics.recordHttpResponse(
      host: response.requestOptions.uri.host,
      reused: reused,
      streamId: streamId,
      latencyMs: latency,
      statusCode: response.statusCode ?? 200,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = err.requestOptions.extra[_startTimeKey] as int?;
    final latency = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : 0;

    final reused =
        err.requestOptions.extra['http2_reused'] as bool? ?? false;
    final streamId = err.requestOptions.extra['http2_stream_id'] as int?;

    metrics.recordHttpError(
      host: err.requestOptions.uri.host,
      reused: reused,
      streamId: streamId,
      latencyMs: latency,
      statusCode: err.response?.statusCode,
      errorMessage: err.message ?? err.error?.toString() ?? 'Unknown error',
    );

    handler.next(err);
  }
}
