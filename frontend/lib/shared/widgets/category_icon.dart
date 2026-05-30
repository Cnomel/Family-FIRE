import 'package:flutter/material.dart';

/// 分类图标映射
class CategoryIcon extends StatelessWidget {
  final String nature;
  final double size;

  const CategoryIcon({
    super.key,
    required this.nature,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        _getIcon(),
        size: size * 0.6,
        color: _getColor(),
      ),
    );
  }

  IconData _getIcon() {
    switch (nature) {
      case 'tangible':
        return Icons.home;
      case 'digital':
        return Icons.computer;
      case 'financial':
        return Icons.account_balance;
      case 'intangible':
        return Icons.description;
      case 'service':
        return Icons.cloud;
      default:
        return Icons.category;
    }
  }

  Color _getColor() {
    switch (nature) {
      case 'tangible':
        return const Color(0xFF1677FF);
      case 'digital':
        return const Color(0xFF722ED1);
      case 'financial':
        return const Color(0xFF13C2C2);
      case 'intangible':
        return const Color(0xFFFA8C16);
      case 'service':
        return const Color(0xFF52C41A);
      default:
        return const Color(0xFF999999);
    }
  }
}
