import 'package:flutter/material.dart';

class UserGuidePage extends StatelessWidget {
  const UserGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用手册')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            icon: Icons.local_fire_department,
            title: '什么是 FIRE？',
            content: 'FIRE 是 "Financial Independence, Retire Early" 的缩写，中文意思是"财务独立，提前退休"。\n\n'
                'FIRE 运动的核心理念是通过高储蓄率和明智投资，尽早实现财务自由，从而可以选择是否继续工作。',
          ),
          _buildSection(
            context,
            icon: Icons.calculate,
            title: 'FIRE 数字是什么？',
            content: 'FIRE 数字是指实现财务独立所需的资产总额。\n\n'
                '计算公式：\n'
                'FIRE 数字 = 年支出 ÷ 提取率\n\n'
                '例如：\n'
                '• 年支出 = ¥120,000\n'
                '• 提取率 = 4%\n'
                '• FIRE 数字 = ¥120,000 ÷ 4% = ¥3,000,000\n\n'
                '当你的资产达到 FIRE 数字时，每年提取 4% 作为生活费，理论上本金可以永续使用。',
          ),
          _buildSection(
            context,
            icon: Icons.percent,
            title: '4% 法则是什么？',
            content: '4% 法则是 FIRE 运动的核心原则之一。\n\n'
                '根据历史数据研究，如果一个退休人员每年从投资组合中提取不超过 4% 的资金用于生活开支，'
                '那么这个投资组合有很高的概率可以持续 30 年以上而不会耗尽。\n\n'
                '这意味着：\n'
                '• 如果你每年需要 ¥100,000 生活费\n'
                '• 你需要攒够 ¥100,000 ÷ 4% = ¥2,500,000\n'
                '• 然后每年提取 4%（¥100,000）用于生活',
          ),
          _buildSection(
            context,
            icon: Icons.savings,
            title: '什么是储蓄率？',
            content: '储蓄率是指你每月/每年收入中用于储蓄和投资的比例。\n\n'
                '计算公式：\n'
                '储蓄率 = (收入 - 支出) ÷ 收入 × 100%\n\n'
                '例如：\n'
                '• 月收入 = ¥15,000\n'
                '• 月支出 = ¥8,000\n'
                '• 月储蓄 = ¥7,000\n'
                '• 储蓄率 = ¥7,000 ÷ ¥15,000 × 100% = 46.7%\n\n'
                '储蓄率越高，达到 FIRE 目标的速度越快。',
          ),
          _buildSection(
            context,
            icon: Icons.trending_up,
            title: '什么是安全提取率？',
            content: '安全提取率是指在不耗尽本金的情况下，每年可以从投资组合中提取的最大比例。\n\n'
                '通常使用 4% 作为安全提取率。\n\n'
                '月安全提取额 = 净资产 × 4% ÷ 12\n\n'
                '例如：\n'
                '• 净资产 = ¥3,000,000\n'
                '• 年提取额 = ¥3,000,000 × 4% = ¥120,000\n'
                '• 月提取额 = ¥120,000 ÷ 12 = ¥10,000\n\n'
                '这意味着你每月可以安全提取 ¥10,000 用于生活开支。',
          ),
          _buildSection(
            context,
            icon: Icons.pie_chart,
            title: '资产配置建议',
            content: '合理的资产配置是实现 FIRE 的关键。\n\n'
                '常见的资产配置建议：\n\n'
                '1. 股票（60-80%）\n'
                '   • 长期收益较高\n'
                '   • 波动性较大\n'
                '   • 适合年轻投资者\n\n'
                '2. 债券（20-40%）\n'
                '   • 收益稳定\n'
                '   • 风险较低\n'
                '   • 适合临近退休的投资者\n\n'
                '3. 现金及等价物（5-10%）\n'
                '   • 应急资金\n'
                '   • 流动性高\n'
                '   • 收益较低\n\n'
                '建议根据自己的年龄、风险承受能力和投资目标来调整配置比例。',
          ),
          _buildSection(
            context,
            icon: Icons.lightbulb,
            title: 'FIRE 的几种类型',
            content: '1. 肥 FIRE（Fat FIRE）\n'
                '   • 较高的年支出预算\n'
                '   • 生活质量不受影响\n'
                '   • 需要更多的储蓄\n\n'
                '2. 瘦 FIRE（Lean FIRE）\n'
                '   • 较低的年支出预算\n'
                '   • 简单生活方式\n'
                '   • 较快实现目标\n\n'
                '3. 咖啡师 FIRE（Barista FIRE）\n'
                '   • 半退休状态\n'
                '   • 从事轻松的兼职工作\n'
                '   • 补充部分收入\n\n'
                '4. 海岸 FIRE（Coast FIRE）\n'
                '   • 已有足够的退休储蓄\n'
                '   • 只需覆盖当前开支\n'
                '   • 不需要继续储蓄',
          ),
          _buildSection(
            context,
            icon: Icons.calculate_outlined,
            title: '如何使用本应用？',
            content: '1. 记录资产\n'
                '   • 添加你的所有资产（房产、车辆、投资等）\n'
                '   • 定期更新资产价值\n\n'
                '2. 记录收支\n'
                '   • 设置固定支出项和预期范围\n'
                '   • 每月记录实际收支\n'
                '   • 查看储蓄率变化\n\n'
                '3. 跟踪进度\n'
                '   • 查看 FIRE 仪表盘\n'
                '   • 监控净资产增长\n'
                '   • 估算达到 FIRE 的时间\n\n'
                '4. 家庭协作\n'
                '   • 邀请家人加入\n'
                '   • 共同管理家庭财务\n'
                '   • 一起制定财务目标',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
