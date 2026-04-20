import 'package:flutter/material.dart';

/// AppTheme — warm, high-contrast, large-text theme optimised for elderly users.
class AppTheme {
  AppTheme._();

  // Palette — warm cream background, deep navy text, amber accent
  static const Color background = Color(0xFFFFF8F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF1A3A5C);      // Deep navy
  static const Color primaryLight = Color(0xFF2E5F8A);
  static const Color accent = Color(0xFFE8840A);       // Warm amber
  static const Color accentLight = Color(0xFFF5A940);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMedium = Color(0xFF555555);
  static const Color textLight = Color(0xFF888888);
  static const Color cardBorder = Color(0xFFE2D5C3);
  static const Color danger = Color(0xFFCC3333);
  static const Color success = Color(0xFF2D8A4E);

  // Base font sizes — scaled up for elderly readability
  static const double fontXS = 16.0;
  static const double fontSM = 20.0;
  static const double fontMD = 24.0;
  static const double fontLG = 28.0;
  static const double fontXL = 34.0;
  static const double fontXXL = 42.0;

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      background: background,
      surface: surface,
      primary: primary,
      secondary: accent,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: fontLG,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: 30),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: fontMD, fontWeight: FontWeight.bold),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 2.5),
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: fontMD, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: fontSM, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: cardBorder, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: const TextStyle(color: textLight, fontSize: fontSM),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: fontXXL, fontWeight: FontWeight.bold, color: textDark),
      displayMedium: TextStyle(fontSize: fontXL, fontWeight: FontWeight.bold, color: textDark),
      headlineLarge: TextStyle(fontSize: fontLG, fontWeight: FontWeight.bold, color: textDark),
      headlineMedium: TextStyle(fontSize: fontMD, fontWeight: FontWeight.w600, color: textDark),
      bodyLarge: TextStyle(fontSize: fontMD, color: textDark, height: 1.6),
      bodyMedium: TextStyle(fontSize: fontSM, color: textMedium, height: 1.5),
      labelLarge: TextStyle(fontSize: fontMD, fontWeight: FontWeight.bold),
    ),
    dividerTheme: const DividerThemeData(color: cardBorder, thickness: 1.5),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle: const TextStyle(fontSize: fontSM, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
