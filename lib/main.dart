import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'presentation/providers/window_tray_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }

  final container = ProviderContainer();

  if (Platform.isWindows) {
    await container.read(windowTrayDatasourceProvider).init();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CopyLotApp(),
    ),
  );
}
