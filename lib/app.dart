import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/main_screen.dart';

/// Copy-lot アプリケーションのルートウィジェット
class CopyLotApp extends StatelessWidget {
  const CopyLotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Copy-lot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}
