import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1677FF);
  static const Color primaryDark = Color(0xFF0958D9);
  static const Color primaryLight = Color(0xFFE6F4FF);
  static const Color profit = Color(0xFFFF4D4F);
  static const Color loss = Color(0xFF00B578);
  static const Color neutral = Color(0xFF8C8C8C);
  static const Color warning = Color(0xFFFAAD14);
  static const Color text = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF8C8C8C);
  static const Color textTertiary = Color(0xFFBFBFBF);
  static const Color background = Color(0xFFF5F5F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8E8E8);
  static const Color error = Color(0xFFFF4D4F);
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    ),
  );
}
