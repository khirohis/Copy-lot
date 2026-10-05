import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_factory.dart';

/// アプリケーション全体で共有される HTTP/2 対応 Dio シングルインスタンスの Provider
///
/// コネクションの再利用（Connection Reuse）およびストリーム多重化を最大化し、
/// 低レイテンシ・低フットプリントな通信を実現します。
final dioProvider = Provider<Dio>((ref) {
  final dio = DioFactory.create();
  ref.onDispose(() {
    dio.close(force: true);
  });
  return dio;
});
