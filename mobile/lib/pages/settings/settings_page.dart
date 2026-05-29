import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // 用户信息
          if (user != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: kPrimaryLight,
                    child: Text(user.initial, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: kPrimaryColor)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(user.email, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(4)),
                          child: Text(user.roleLabel, style: const TextStyle(color: kPrimaryColor, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          _section('外观', [
            _item(Icons.palette_outlined, '主题', '跟随系统'),
            _item(Icons.language_outlined, '语言', '中文'),
          ]),
          _section('通知', [
            _item(Icons.notifications_outlined, '通知设置', '管理通知偏好'),
          ]),
          _section('家庭', [
            _item(Icons.family_restroom, '家庭管理', '管理家庭和成员'),
          ]),
          _section('关于', [
            _item(Icons.info_outline, '关于 Family Fire', '版本 0.1.0'),
            _item(Icons.description_outlined, '开源协议', 'MIT License'),
          ]),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: kErrorColor),
              label: const Text('退出登录', style: TextStyle(color: kErrorColor)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kErrorColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _item(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: kPrimaryColor, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: kTextTertiary),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              authState.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
