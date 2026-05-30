import 'package:flutter/material.dart';

/// 环形进度组件（用于FIRE进度、储蓄率等）
class ProgressRing extends StatelessWidget {
  final num progress; // 0.0 - 1.0
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? child;
  final String? label;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 10,
    this.color,
    this.backgroundColor,
    this.child,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final doubleProgress = progress.toDouble().clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景环
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              color: effectiveBg,
            ),
          ),
          // 进度环
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: doubleProgress,
              strokeWidth: strokeWidth,
              color: effectiveColor,
              strokeCap: StrokeCap.round,
            ),
          ),
          // 中心内容
          if (child != null)
            child!
          else if (label != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(doubleProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: size * 0.16,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                ),
                if (label!.isNotEmpty)
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: size * 0.09,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
