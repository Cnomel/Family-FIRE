import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  double _passwordStrength = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person)),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入用户名';
                  if (v.length < 3) return '用户名至少3位';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email)),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入邮箱';
                  if (!v.contains('@')) return '邮箱格式不正确';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '姓名', prefixIcon: Icon(Icons.badge)),
                validator: (v) => (v == null || v.isEmpty) ? '请输入姓名' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)),
                onChanged: _updatePasswordStrength,
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入密码';
                  if (v.length < 8) return '密码至少8位';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _passwordStrength,
                backgroundColor: Colors.grey[200],
                color: _passwordStrength < 0.3
                    ? AppColors.error
                    : _passwordStrength < 0.7
                        ? AppColors.warning
                        : AppColors.loss,
                minHeight: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v != _passwordController.text ? '两次密码不一致' : null,
              ),
              if (authState.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(authState.error!, style: const TextStyle(color: AppColors.error)),
                ),
              ],
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: authState,
                builder: (context, _) {
                  return ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleRegister,
                    child: authState.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('注册'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updatePasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    authState.clearError();
    authState.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    ).then((success) {
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录'), backgroundColor: AppColors.loss),
        );
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
