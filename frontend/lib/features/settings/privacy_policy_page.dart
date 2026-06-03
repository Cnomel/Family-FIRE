import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私政策')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family Fire 隐私政策',
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
              '1. 引言',
              'Family Fire（以下简称"我们"或"本应用"）非常重视您的隐私保护。本隐私政策旨在向您说明我们如何收集、使用、存储和保护您的个人信息。',
            ),
            _buildSection(
              context,
              '2. 信息收集',
              '2.1 您主动提供的信息\n\n'
                  '• 账户信息：用户名、邮箱地址、密码（加密存储）\n'
                  '• 个人资料：姓名、头像\n'
                  '• 财务数据：资产信息、收支记录、投资组合、负债信息\n'
                  '• 文档资料：您上传的收据、保单、说明书等文件\n\n'
                  '2.2 自动收集的信息\n\n'
                  '• 设备信息：设备型号、操作系统版本、唯一设备标识符\n'
                  '• 日志信息：访问时间、操作记录、错误日志\n'
                  '• 网络信息：IP地址、网络类型',
            ),
            _buildSection(
              context,
              '3. 信息使用',
              '我们收集的信息将用于：\n\n'
                  '• 提供和维护本应用的核心功能\n'
                  '• 处理您的请求和交易\n'
                  '• 发送服务通知和更新\n'
                  '• 改进和优化用户体验\n'
                  '• 防止欺诈和增强安全性\n'
                  '• 遵守法律法规要求',
            ),
            _buildSection(
              context,
              '4. 信息存储与安全',
              '4.1 数据存储\n'
                  '您的数据存储在安全的服务器上，采用行业标准的加密技术进行保护。\n\n'
                  '4.2 数据安全措施\n\n'
                  '• 传输加密：所有数据传输均使用 TLS/SSL 加密\n'
                  '• 存储加密：敏感数据采用 AES-256 加密存储\n'
                  '• 访问控制：严格的权限管理和访问控制机制\n'
                  '• 安全审计：定期进行安全审计和漏洞扫描\n\n'
                  '4.3 数据保留\n'
                  '我们会在提供服务所需的期限内保留您的个人信息。当您删除账户后，我们将在合理时间内删除您的个人数据。',
            ),
            _buildSection(
              context,
              '5. 信息共享',
              '我们不会出售您的个人信息。仅在以下情况下，我们可能会共享您的信息：\n\n'
                  '• 经您同意：在获得您明确同意后共享\n'
                  '• 家庭协作：在家庭组内与授权成员共享相关财务信息\n'
                  '• 法律要求：为遵守法律法规或政府要求\n'
                  '• 服务提供商：与帮助我们运营服务的可信第三方合作（如云服务提供商）',
            ),
            _buildSection(
              context,
              '6. 您的权利',
              '您对自己的个人信息享有以下权利：\n\n'
                  '• 访问权：查看我们持有的您的个人信息\n'
                  '• 更正权：更正不准确的个人信息\n'
                  '• 删除权：请求删除您的个人信息\n'
                  '• 导出权：导出您的数据\n'
                  '• 撤回同意：撤回之前给予的同意\n\n'
                  '如需行使上述权利，请通过本应用内的设置功能或联系我们。',
            ),
            _buildSection(
              context,
              '7. Cookie 和类似技术',
              '本应用可能使用 Cookie 和类似技术来：\n\n'
                  '• 维持您的登录状态\n'
                  '• 记住您的偏好设置\n'
                  '• 分析应用使用情况\n\n'
                  '您可以通过设备设置管理这些技术。',
            ),
            _buildSection(
              context,
              '8. 儿童隐私',
              '本应用不面向 14 岁以下的儿童。我们不会故意收集 14 岁以下儿童的个人信息。如果您发现我们可能收集了儿童的个人信息，请立即联系我们。',
            ),
            _buildSection(
              context,
              '9. 隐私政策变更',
              '我们可能会不时更新本隐私政策。变更将在本应用中公布后立即生效。重大变更时，我们会通过应用内通知或其他方式提醒您。',
            ),
            _buildSection(
              context,
              '10. 联系我们',
              '如果您对本隐私政策有任何疑问、意见或建议，请通过以下方式联系我们：\n\n'
                  '邮箱：privacy@familyfire.app\n'
                  '地址：[您的地址]\n\n'
                  '我们将在 15 个工作日内回复您的请求。',
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
