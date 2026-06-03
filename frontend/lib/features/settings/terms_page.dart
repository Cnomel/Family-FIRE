import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户协议')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family Fire 用户协议',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '最后更新日期：2024年1月1日',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. 服务条款的接受',
              '欢迎使用 Family Fire（以下简称"本应用"）。在使用本应用之前，请仔细阅读本用户协议（以下简称"本协议"）。通过访问或使用本应用，即表示您同意受本协议的约束。如果您不同意本协议的任何条款，请停止使用本应用。',
            ),
            _buildSection(
              context,
              '2. 服务描述',
              'Family Fire 是一款家庭资产管理应用，旨在帮助用户追踪和管理家庭财务，实现财务独立（FIRE）目标。本应用提供的功能包括但不限于：\n\n'
                  '• 资产分类与管理\n'
                  '• 投资组合追踪\n'
                  '• 收支记录与分析\n'
                  '• 负债管理\n'
                  '• 财务目标规划\n'
                  '• 家庭协作功能',
            ),
            _buildSection(
              context,
              '3. 用户账户',
              '3.1 注册要求\n'
                  '您需要注册账户才能使用本应用的完整功能。注册时，您应提供准确、完整和最新的信息。\n\n'
                  '3.2 账户安全\n'
                  '您有责任维护账户的安全性，包括保护您的密码和设备。任何通过您的账户进行的活动均由您承担责任。\n\n'
                  '3.3 账户终止\n'
                  '我们保留在您违反本协议时暂停或终止您账户的权利。',
            ),
            _buildSection(
              context,
              '4. 用户行为规范',
              '使用本应用时，您同意：\n\n'
                  '• 遵守适用的法律法规\n'
                  '• 不进行任何非法或欺诈活动\n'
                  '• 不干扰或破坏本应用的正常运行\n'
                  '• 不尝试未经授权访问其他用户的账户\n'
                  '• 不上传恶意软件或有害内容',
            ),
            _buildSection(
              context,
              '5. 数据与隐私',
              '5.1 数据收集\n'
                  '我们收集和处理您的个人信息的方式详见《隐私政策》。\n\n'
                  '5.2 数据准确性\n'
                  '本应用提供的财务分析和建议仅供参考，不构成专业的财务建议。您应自行验证数据的准确性。\n\n'
                  '5.3 数据备份\n'
                  '建议您定期备份重要数据。我们不对数据丢失承担责任。',
            ),
            _buildSection(
              context,
              '6. 知识产权',
              '本应用及其内容（包括但不限于软件、文本、图像、标志）均为 Family Fire 或其许可方的财产，受知识产权法律保护。未经我们明确书面许可，您不得复制、修改、分发或创建衍生作品。',
            ),
            _buildSection(
              context,
              '7. 免责声明',
              '7.1 服务现状提供\n'
                  '本应用按"现状"和"可用性"提供，不作任何明示或暗示的保证。\n\n'
                  '7.2 财务风险\n'
                  '投资涉及风险，本应用不保证任何投资结果。过去的业绩不代表未来的表现。\n\n'
                  '7.3 第三方服务\n'
                  '本应用可能包含指向第三方服务的链接，我们不对这些服务的内容或可用性负责。',
            ),
            _buildSection(
              context,
              '8. 责任限制',
              '在法律允许的最大范围内，Family Fire 及其关联方不对任何间接、附带、特殊、后果性或惩罚性损害承担责任，包括但不限于利润损失、数据丢失或业务中断。',
            ),
            _buildSection(
              context,
              '9. 协议变更',
              '我们保留随时修改本协议的权利。变更将在本应用中公布后立即生效。继续使用本应用即表示您接受修改后的协议。',
            ),
            _buildSection(
              context,
              '10. 适用法律',
              '本协议受中华人民共和国法律管辖。任何争议应提交至本应用运营所在地的人民法院解决。',
            ),
            _buildSection(
              context,
              '11. 联系我们',
              '如果您对本协议有任何疑问，请通过以下方式联系我们：\n\n'
                  '邮箱：support@familyfire.app\n'
                  '地址：[您的地址]',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
