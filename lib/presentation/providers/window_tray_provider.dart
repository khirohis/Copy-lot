import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/window_tray_datasource.dart';

/// WindowTrayDatasource の Provider
final windowTrayDatasourceProvider = Provider<WindowTrayDatasource>((ref) {
  final datasource = WindowTrayDatasource();
  ref.onDispose(datasource.dispose);
  return datasource;
});
