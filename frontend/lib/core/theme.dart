import 'package:flutter/material.dart';

// 主题色 - 支付宝蓝色
const kPrimary = Color(0xFF1677FF);
const kPrimaryDark = Color(0xFF0958D9);
const kPrimaryLight = Color(0xFFE6F4FF);

// 语义色 - 国内惯例：红涨绿跌
const kProfit = Color(0xFFFF4D4F);
const kLoss = Color(0xFF00B578);
const kWarn = Color(0xFFFAAD14);
const kError = Color(0xFFFF4D4F);

// 中性色
const kText = Color(0xFF1F1F1F);
const kText2 = Color(0xFF8C8C8C);
const kText3 = Color(0xFFBFBFBF);
const kBg = Color(0xFFF5F5F5);
const kBorder = Color(0xFFE8E8E8);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kText,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: kPrimary,
      unselectedItemColor: kText3,
      type: BottomNavigationBarType.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
    ),
  );
}
