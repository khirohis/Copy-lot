import 'package:dio/dio.dart';
import 'metrics_interceptor.dart';
import 'monitored_http2_adapter.dart';
import 'network_metrics.dart';

/// Factory that creates a preconfigured [Dio] client with HTTP/2 support,
/// connection monitoring, and metrics logging.
class DioFactory {
  DioFactory._();

  /// Default timeout values in milliseconds.
  static const Duration defaultConnectTimeout = Duration(milliseconds: 5000);
  static const Duration defaultReceiveTimeout = Duration(milliseconds: 5000);
  static const Duration defaultSendTimeout = Duration(milliseconds: 5000);

  /// Creates and configures a [Dio] instance with HTTP/2 adapter and metrics monitoring.
  static Dio create({
    BaseOptions? options,
    NetworkMetrics? metrics,
  }) {
    final effectiveMetrics = metrics ?? NetworkMetrics();

    final baseOptions = (options ?? BaseOptions()).copyWith(
      connectTimeout: options?.connectTimeout ?? defaultConnectTimeout,
      receiveTimeout: options?.receiveTimeout ?? defaultReceiveTimeout,
      sendTimeout: options?.sendTimeout ?? defaultSendTimeout,
    );

    final dio = Dio(baseOptions);

    dio.httpClientAdapter = MonitoredHttp2Adapter(metrics: effectiveMetrics);
    dio.interceptors.add(MetricsInterceptor(metrics: effectiveMetrics));

    return dio;
  }
}
