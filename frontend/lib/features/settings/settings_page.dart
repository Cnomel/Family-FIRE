import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/theme.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final response = await Api.instance.get('/auth/me');
      setState(() {
        _user = response['data'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // 用户信息卡片
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_user != null)
            _buildProfileCard(),

          const SizedBox(height: 8),
          _buildSection('外观', [
            _buildTile(Icons.palette_outlined, '主题', '跟随系统'),
            _buildTile(Icons.language_outlined, '语言', '中文'),
          ]),
          _buildSection('通知', [
            _buildTile(Icons.notifications_outlined, '通知设置', '管理通知偏好'),
          ]),
          _buildSection('家庭', [
            _buildTile(Icons.family_restroom, '家庭管理', '管理家庭和成员'),
          ]),
          _buildSection('关于', [
            _buildTile(Icons.info_outline, '关于 Family Fire', '版本 0.1.0'),
            _buildTile(Icons.description_outlined, '开源协议', 'MIT License'),
          ]),
          const SizedBox(height: 24),
          // 退出登录按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, color: kError),
              label: const Text('退出登录', style: TextStyle(color: kError)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kError),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final username = _user?['username'] ?? '';
    final fullName = _user?['full_name'] ?? '';
    final email = _user?['email'] ?? '';
    final role = _user?['role'] ?? '';

    return Container(
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
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: kPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isNotEmpty ? fullName : username,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(color: kText2, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_roleLabel(role), style: const TextStyle(color: kPrimary, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return '系统管理员';
      case 'family_admin': return '家庭管理员';
      case 'member': return '成员';
      default: return role;
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText2)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: kPrimary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: kText2, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: kText3),
    );
  }

  void _showLogoutDialog(BuildContext context) {
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
              Api.instance.clearTokens();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: kError),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
