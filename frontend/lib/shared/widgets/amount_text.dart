import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_fire/core/providers/privacy_provider.dart';
import 'package:family_fire/shared/formatters/currency.dart';
import 'package:family_fire/shared/theme/colors.dart';

/// 金额显示组件（支持隐私模式 + 颜色）
class AmountText extends ConsumerWidget {
  final num amount;
  final bool showSign;
  final bool showColor;
  final double fontSize;
  final FontWeight fontWeight;

  const AmountText({
    super.key,
    required this.amount,
    this.showSign = false,
    this.showColor = true,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacy = ref.watch(privacyModeProvider);
    final doubleAmount = amount.toDouble();

    if (isPrivacy) {
      return Text(
        '****',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Theme.of(context).colorScheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    final color = showColor ? AppColors.forChange(doubleAmount) : Theme.of(context).colorScheme.onSurface;

    return Text(
      formatCurrency(doubleAmount, showSign: showSign),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
