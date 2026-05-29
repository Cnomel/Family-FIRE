import 'package:flutter/material.dart';

// 主题色 - 参考支付宝蓝色
const kPrimaryColor = Color(0xFF1677FF);
const kPrimaryDark = Color(0xFF0958D9);
const kPrimaryLight = Color(0xFFE6F4FF);

// 语义色 - 国内惯例：红涨绿跌
const kProfitColor = Color(0xFFFF4D4F);  // 红色=盈利/涨
const kLossColor = Color(0xFF00B578);    // 绿色=亏损/跌
const kNeutralColor = Color(0xFF8C8C8C);
const kWarningColor = Color(0xFFFAAD14);
const kErrorColor = Color(0xFFFF4D4F);

// 中性色
const kTextPrimary = Color(0xFF1F1F1F);
const kTextSecondary = Color(0xFF8C8C8C);
const kTextTertiary = Color(0xFFBFBFBF);
const kBackgroundColor = Color(0xFFF5F5F5);
const kCardColor = Color(0xFFFFFFFF);
const kBorderColor = Color(0xFFE8E8E8);

// 分类颜色
const kCategoryColors = {
  'food': Color(0xFFFF6B35),
  'transport': Color(0xFF1677FF),
  'shopping': Color(0xFF722ED1),
  'housing': Color(0xFF13C2C2),
  'entertainment': Color(0xFFEB2F96),
  'healthcare': Color(0xFF52C41A),
  'education': Color(0xFFFAAD14),
  'social': Color(0xFF2F54EB),
};

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: kBackgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: kCardColor,
      foregroundColor: kTextPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: kTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: kCardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kErrorColor),
      ),
      labelStyle: const TextStyle(color: kTextSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: kPrimaryColor,
      unselectedItemColor: kTextTertiary,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),
  );
}
