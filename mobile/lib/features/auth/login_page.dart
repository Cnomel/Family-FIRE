import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../main.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.local_fire_department, size: 80, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Family Fire',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '家庭资产管理系统',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: '用户名或邮箱',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入用户名或邮箱' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(authState.error!, style: const TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: authState,
                  builder: (context, _) {
                    return ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleLogin,
                      child: authState.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('登录'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text('没有账号？立即注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    authState.clearError();
    authState.login(_idController.text.trim(), _passController.text);
  }

  @override
  void dispose() {
    _idController.dispose();
    _passController.dispose();
    super.dispose();
  }
}
