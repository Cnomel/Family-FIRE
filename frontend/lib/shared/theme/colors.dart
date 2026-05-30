import 'package:flutter/material.dart';

/// 中国化颜色约定
/// 红色 = 盈利/涨，绿色 = 亏损/跌（与西方相反）
class AppColors {
  // 盈利/涨 - 红色
  static const Color profit = Color(0xFFFF4D4F);
  static const Color up = Color(0xFFFF4D4F);

  // 亏损/跌 - 绿色
  static const Color loss = Color(0xFF00B578);
  static const Color down = Color(0xFF00B578);

  // 持平
  static const Color flat = Color(0xFF999999);

  // 主题蓝
  static const Color primary = Color(0xFF1677FF);

  // 背景色
  static const Color cardLight = Color(0xFFF5F5F5);
  static const Color cardDark = Color(0xFF1E1E1E);

  // 文字色
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);

  /// 根据涨跌返回对应颜色
  static Color forChange(num change) {
    final v = change.toDouble();
    if (v > 0) return profit;
    if (v < 0) return loss;
    return flat;
  }
}
