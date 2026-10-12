import 'package:flutter/material.dart';

/// Windows 11 Fluent Design に親和性のあるテーマ定義
class AppTheme {
  AppTheme._();

  static const _primarySeed = Color(0xFF0067C0); // Windows 11 Accent Blue

  /// ライトテーマ
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primarySeed,
        brightness: Brightness.light,
        surface: const Color(0xFFF9F9F9), // Windows 11 Mica-like surface
      ),
      scaffoldBackgroundColor: const Color(0xFFF3F3F3),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
    );
  }

  /// ダークテーマ
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primarySeed,
        brightness: Brightness.dark,
        surface: const Color(0xFF2C2C2C),
      ),
      scaffoldBackgroundColor: const Color(0xFF202020),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        color: const Color(0xFF2B2B2B),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
