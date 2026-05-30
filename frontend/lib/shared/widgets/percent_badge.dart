import 'package:flutter/material.dart';

import 'package:family_fire/shared/theme/colors.dart';
import 'package:family_fire/shared/formatters/currency.dart';

/// 百分比标签（红涨绿跌）
class PercentBadge extends StatelessWidget {
  final num value;
  final double fontSize;

  const PercentBadge({
    super.key,
    required this.value,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final doubleValue = value.toDouble();
    final color = AppColors.forChange(doubleValue);
    final icon = doubleValue > 0
        ? Icons.arrow_upward
        : doubleValue < 0
            ? Icons.arrow_downward
            : Icons.remove;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize, color: color),
          const SizedBox(width: 2),
          Text(
            formatPercent(doubleValue.abs()),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
