import 'package:flutter/material.dart';

/// Central color palette for the CodeQuest dark, playful theme.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0E0B1E);
  static const Color panel = Color(0xFF171334);
  static const Color panel2 = Color(0xFF211A4D);
  static const Color ink = Color(0xFFF4F2FF);
  static const Color muted = Color(0xFFB7B0E0);
  static const Color brand = Color(0xFF8B5CFF);
  static const Color brand2 = Color(0xFF5B8CFF);
  static const Color gold = Color(0xFFFFC93C);
  static const Color green = Color(0xFF37E29A);
  static const Color pink = Color(0xFFFF5DB1);
}

/// App-wide theme. Material 3, dark, purple background with gold accents.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brand,
        secondary: AppColors.brand2,
        surface: AppColors.panel,
        onPrimary: AppColors.ink,
        onSecondary: AppColors.ink,
        onSurface: AppColors.ink,
        error: AppColors.pink,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          )
          .copyWith(
            headlineLarge: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            headlineMedium: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
            bodyMedium: const TextStyle(
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        centerTitle: false,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.panel2,
        contentTextStyle: TextStyle(color: AppColors.ink),
        behavior: SnackBarBehavior.floating,
      ),
      // Dialog background comes from colorScheme.surface (AppColors.panel),
      // avoiding the DialogTheme/DialogThemeData API change across Flutter
      // versions.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.ink,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
