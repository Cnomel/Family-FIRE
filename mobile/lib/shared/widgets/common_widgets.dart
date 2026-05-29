import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../formatters/currency.dart';

class AmountText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showSign;
  final bool privacyMode;

  const AmountText({
    super.key,
    required this.amount,
    this.style,
    this.showSign = false,
    this.privacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (privacyMode) {
      return Text('****', style: style ?? AmountStyle.medium());
    }

    Color? color;
    if (showSign) {
      color = amount > 0
          ? AppColors.profit
          : amount < 0
              ? AppColors.loss
              : AppColors.neutral;
    }

    return Text(
      CurrencyFormatter.format(amount, showSign: showSign),
      style: (style ?? AmountStyle.medium()).copyWith(color: color),
    );
  }
}

class PercentBadge extends StatelessWidget {
  final double value;
  final bool showSign;

  const PercentBadge({super.key, required this.value, this.showSign = true});

  @override
  Widget build(BuildContext context) {
    final color = value > 0
        ? AppColors.profit
        : value < 0
            ? AppColors.loss
            : AppColors.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        CurrencyFormatter.formatPercent(value, showSign: showSign),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class PrivacyToggle extends StatelessWidget {
  final bool isPrivate;
  final VoidCallback onToggle;

  const PrivacyToggle({super.key, required this.isPrivate, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isPrivate ? Icons.visibility_off : Icons.visibility,
        color: AppColors.textSecondary,
      ),
      onPressed: onToggle,
    );
  }
}

class AppSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeleton({super.key, this.width = double.infinity, this.height = 16, this.borderRadius = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  const AppCard({super.key, required this.child, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
