import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copy_lot/core/network/dio_factory.dart';

void main() {
  group('DioFactory', () {
    test('creates Dio instance with default timeouts', () {
      final dio = DioFactory.create();

      expect(dio.options.connectTimeout, const Duration(milliseconds: 5000));
      expect(dio.options.receiveTimeout, const Duration(milliseconds: 5000));
      expect(dio.options.sendTimeout, const Duration(milliseconds: 5000));
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
}
