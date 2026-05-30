import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_fire/shared/theme/colors.dart';
import 'package:family_fire/shared/widgets/amount_text.dart';
import 'package:family_fire/shared/widgets/percent_badge.dart';
import 'package:family_fire/shared/widgets/category_icon.dart';

/// 资产列表卡片
class AssetCard extends ConsumerWidget {
  final String name;
  final String nature;
  final String? category;
  final num currentValue;
  final num? changePercent;
  final List<String>? tags;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showCheckbox;

  const AssetCard({
    super.key,
    required this.name,
    required this.nature,
    this.category,
    required this.currentValue,
    this.changePercent,
    this.tags,
    this.onTap,
    this.isSelected = false,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 复选框或分类图标
              if (showCheckbox)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? AppColors.primary : Colors.grey,
                    size: 24,
                  ),
                )
              else ...[
                CategoryIcon(nature: nature, size: 40),
                const SizedBox(width: 12),
              ],
              // 名称 + 标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tags != null && tags!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: tags!.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // 金额
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(amount: currentValue, fontSize: 16),
                  if (changePercent != null) ...[
                    const SizedBox(height: 4),
                    PercentBadge(value: changePercent!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
