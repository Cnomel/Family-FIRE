import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/theme/colors.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/number.dart';

/// FIRE快照数据
class FireSnapshot {
  final double netWorth;
  final double fireNumber;
  final double fiRatio;
  final double? yearsToFire;
  final double savingsRate;
  final double annualExpense;
  final double withdrawalRate;

  FireSnapshot({
    required this.netWorth,
    required this.fireNumber,
    required this.fiRatio,
    this.yearsToFire,
    required this.savingsRate,
    required this.annualExpense,
    required this.withdrawalRate,
  });

  factory FireSnapshot.fromJson(Map<String, dynamic> json) {
    // net_worth 可能是嵌套对象或数字
    final nw = json['net_worth'];
    final netWorthValue = (nw is Map) ? toDouble(nw['net_worth']) : toDouble(nw);
    return FireSnapshot(
      netWorth: netWorthValue,
      fireNumber: toDouble(json['fire_number']),
      fiRatio: toDouble(json['fi_ratio']),
      yearsToFire: json['years_to_fire'] != null ? toDouble(json['years_to_fire']) : null,
      savingsRate: toDouble(json['savings_rate']),
      annualExpense: toDouble(json['annual_expense']),
      withdrawalRate: toDouble(json['withdrawal_rate'] ?? 0.04),
    );
  }
}

/// 资产统计
class AssetStats {
  final int totalCount;
  final double totalValue;
  final Map<String, dynamic> byNature;

  AssetStats({
    required this.totalCount,
    required this.totalValue,
    required this.byNature,
  });

  factory AssetStats.fromJson(Map<String, dynamic> json) {
    return AssetStats(
      totalCount: json['total_count'] ?? 0,
      totalValue: toDouble(json['total_value']),
      byNature: json['by_nature'] ?? {},
    );
  }
}

/// 获取当前家庭
final currentFamilyProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/api/families/current');
    return response.data['data'];
  } catch (_) {
    return null;
  }
});

/// 获取FIRE快照（仅在有家庭时请求）
final fireSnapshotProvider = FutureProvider<FireSnapshot?>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return null;

  try {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/api/families/current/finance/fire/snapshot');
    return FireSnapshot.fromJson(response.data['data']);
  } catch (_) {
    return null;
  }
});

/// 获取资产统计（仅在有家庭时请求）
final assetStatsProvider = FutureProvider<AssetStats?>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return null;

  try {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/api/families/current/assets/stats');
    return AssetStats.fromJson(response.data['data']);
  } catch (_) {
    return null;
  }
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fireAsync = ref.watch(fireSnapshotProvider);
    final statsAsync = ref.watch(assetStatsProvider);
    final familyAsync = ref.watch(currentFamilyProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(fireSnapshotProvider);
        ref.invalidate(assetStatsProvider);
        ref.invalidate(currentFamilyProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 无家庭提醒
          familyAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (family) {
              if (family == null) {
                return _NoFamilyCard();
              }
              return const SizedBox.shrink();
            },
          ),

          // 净资产Hero卡片
          _NetWorthCard(fireAsync: fireAsync),
          const SizedBox(height: 16),

          // FIRE指标行
          _FireMetricsRow(fireAsync: fireAsync),
          const SizedBox(height: 16),

          // 资产配置饼图
          _AllocationCard(statsAsync: statsAsync),
          const SizedBox(height: 16),

          // 快捷操作
          _QuickActions(),
          const SizedBox(height: 16),

          // 功能入口
          _FeatureGrid(),
        ],
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  final AsyncValue<FireSnapshot?> fireAsync;

  const _NetWorthCard({required this.fireAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withAlpha(204),
            ],
          ),
        ),
        child: fireAsync.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(width: 80, height: 14, borderRadius: 4),
              SizedBox(height: 12),
              Skeleton(width: 200, height: 32, borderRadius: 4),
              SizedBox(height: 8),
              Skeleton(width: 120, height: 14, borderRadius: 4),
            ],
          ),
          error: (_, __) => const Text('加载失败', style: TextStyle(color: Colors.white)),
          data: (fire) {
            final netWorth = fire?.netWorth ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '净资产',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                AmountText(
                  amount: netWorth,
                  showColor: false,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 8),
                if (fire != null)
                  Text(
                    'FIRE数字: ${formatCurrency(fire.fireNumber)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FireMetricsRow extends StatelessWidget {
  final AsyncValue<FireSnapshot?> fireAsync;

  const _FireMetricsRow({required this.fireAsync});

  @override
  Widget build(BuildContext context) {
    return fireAsync.when(
      loading: () => Row(
        children: const [
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Skeleton(height: 60)))),
          SizedBox(width: 8),
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Skeleton(height: 60)))),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (fire) {
        if (fire == null) return const SizedBox.shrink();
        return Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: '储蓄率',
                value: formatPercent(fire.savingsRate),
                icon: Icons.savings,
                color: AppColors.profit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'FI比率',
                value: '${(fire.fiRatio * 100).toStringAsFixed(1)}%',
                icon: Icons.flag,
                color: fire.fiRatio >= 1.0 ? AppColors.profit : AppColors.primary,
              ),
            ),
            if (fire.yearsToFire != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: '距FIRE',
                  value: '${fire.yearsToFire!.toStringAsFixed(1)}年',
                  icon: Icons.timer,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  final AsyncValue<AssetStats?> statsAsync;

  const _AllocationCard({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('资产配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => context.push('/assets'),
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            statsAsync.when(
              loading: () => const Skeleton(height: 150),
              error: (_, __) => const Text('加载失败'),
              data: (stats) {
                if (stats == null || stats.totalValue == 0) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: Text('暂无资产数据')),
                  );
                }
                return SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: _buildSections(stats.byNature, stats.totalValue),
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildLegend(stats.byNature),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(Map<String, dynamic> byNature, double total) {
    final colors = {
      'tangible': const Color(0xFF1677FF),
      'digital': const Color(0xFF722ED1),
      'financial': const Color(0xFF13C2C2),
      'intangible': const Color(0xFFFA8C16),
      'service': const Color(0xFF52C41A),
    };

    return byNature.entries.where((e) => (e.value['count'] ?? 0) > 0).map((entry) {
      final value = toDouble(entry.value['value']);
      final percent = total > 0 ? value / total * 100 : 0;
      return PieChartSectionData(
        value: value,
        title: '${percent.toStringAsFixed(0)}%',
        color: colors[entry.key] ?? Colors.grey,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, dynamic> byNature) {
    final colors = {
      'tangible': const Color(0xFF1677FF),
      'digital': const Color(0xFF722ED1),
      'financial': const Color(0xFF13C2C2),
      'intangible': const Color(0xFFFA8C16),
      'service': const Color(0xFF52C41A),
    };
    final labels = {
      'tangible': '有形',
      'digital': '数字',
      'financial': '金融',
      'intangible': '无形',
      'service': '服务',
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: byNature.entries.where((e) => (e.value['count'] ?? 0) > 0).map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[entry.key] ?? Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                labels[entry.key] ?? entry.key,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.add_circle_outline,
            label: '添加资产',
            color: AppColors.primary,
            onTap: () => context.push('/assets/create'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.qr_code_scanner,
            label: '扫码添加',
            color: const Color(0xFF722ED1),
            onTap: () => context.push('/assets/scan'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.upload_file,
            label: '上传文档',
            color: const Color(0xFF13C2C2),
            onTap: () => context.push('/documents/upload'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      {'icon': Icons.trending_up, 'label': 'FIRE仪表盘', 'path': '/finance'},
      {'icon': Icons.account_balance, 'label': '负债管理', 'path': '/finance/liabilities'},
      {'icon': Icons.receipt_long, 'label': '收支管理', 'path': '/finance/income-expense'},
      {'icon': Icons.pie_chart, 'label': '投资组合', 'path': '/finance/portfolio'},
      {'icon': Icons.show_chart, 'label': '被动收入', 'path': '/finance/passive-income'},
      {'icon': Icons.analytics, 'label': '蒙特卡洛', 'path': '/finance/monte-carlo'},
      {'icon': Icons.shield, 'label': '保险缺口', 'path': '/assets/insurance-gaps'},
      {'icon': Icons.family_restroom, 'label': '家庭管理', 'path': '/family'},
      {'icon': Icons.settings, 'label': '设置', 'path': '/settings'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                return InkWell(
                  onTap: () => context.push(feature['path'] as String),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(feature['icon'] as IconData, color: AppColors.primary, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        feature['label'] as String,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 无家庭提醒卡片
class _NoFamilyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.family_restroom,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '欢迎使用 Family Fire！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '您还没有创建或加入家庭\n创建家庭后即可开始管理家庭资产',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(204),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.push('/family'),
                  icon: const Icon(Icons.add),
                  label: const Text('创建家庭'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showJoinDialog(context),
                  icon: const Icon(Icons.group_add),
                  label: const Text('加入家庭'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('加入家庭'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: '邀请码',
            hintText: '请输入6位邀请码',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/family');
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}
