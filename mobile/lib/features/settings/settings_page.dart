import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_service.dart';
import '../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = ApiService();
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
      final response = await _api.get('/auth/me');
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
          // Profile
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _buildProfile(),

          const SizedBox(height: 8),
          _section('外观', [
            _tile(Icons.palette, '主题', '跟随系统'),
            _tile(Icons.language, '语言', '中文'),
          ]),
          const SizedBox(height: 8),
          _section('通知', [
            _tile(Icons.notifications, '通知设置', '管理通知偏好'),
          ]),
          const SizedBox(height: 8),
          _section('家庭', [
            _tile(Icons.family_restroom, '家庭管理', '管理家庭和成员'),
          ]),
          const SizedBox(height: 8),
          _section('关于', [
            _tile(Icons.info, '关于 Family Fire', '版本 0.1.0'),
            _tile(Icons.description, '开源协议', 'MIT License'),
          ]),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () => _showLogoutDialog(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('退出登录'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfile() {
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
            radius: 30,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName.isNotEmpty ? fullName : username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_roleLabel(role), style: const TextStyle(color: AppColors.primary, fontSize: 11)),
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

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authState.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
