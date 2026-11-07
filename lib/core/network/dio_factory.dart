import 'package:dio/dio.dart';

/// Factory that creates a preconfigured [Dio] client with default timeout settings.
class DioFactory {
  DioFactory._();

  /// Default timeout values in milliseconds.
  static const Duration defaultConnectTimeout = Duration(milliseconds: 5000);
  static const Duration defaultReceiveTimeout = Duration(milliseconds: 5000);
  static const Duration defaultSendTimeout = Duration(milliseconds: 5000);

  /// Creates and configures a [Dio] instance with default timeouts.
  static Dio create({BaseOptions? options}) {
    final baseOptions = (options ?? BaseOptions()).copyWith(
      connectTimeout: options?.connectTimeout ?? defaultConnectTimeout,
      receiveTimeout: options?.receiveTimeout ?? defaultReceiveTimeout,
      sendTimeout: options?.sendTimeout ?? defaultSendTimeout,
    );

    return Dio(baseOptions);
  }
}
