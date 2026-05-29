import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/auth/auth_repository.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  double _passwordStrength = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.loss),
        );
      }
    });

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
                  if (v?.isEmpty ?? true) return '请输入用户名';
                  if (v!.length < 3) return '用户名至少3位';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return '仅支持字母、数字、下划线';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email)),
                validator: (v) {
                  if (v?.isEmpty ?? true) return '请输入邮箱';
                  if (!v!.contains('@') || !v.contains('.')) return '邮箱格式不正确';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '姓名', prefixIcon: Icon(Icons.badge)),
                validator: (v) => v?.isEmpty ?? true ? '请输入姓名' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)),
                onChanged: _updatePasswordStrength,
                validator: (v) {
                  if (v?.isEmpty ?? true) return '请输入密码';
                  if (v!.length < 8) return '密码至少8位';
                  if (!v.contains(RegExp(r'[A-Z]'))) return '需包含大写字母';
                  if (!v.contains(RegExp(r'[a-z]'))) return '需包含小写字母';
                  if (!v.contains(RegExp(r'[0-9]'))) return '需包含数字';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _buildPasswordStrengthBar(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v != _passwordController.text ? '两次密码不一致' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _handleRegister,
                child: authState.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('注册'),
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('已有账号？返回登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthBar() {
    Color color;
    String label;
    if (_passwordStrength < 0.25) {
      color = AppColors.loss;
      label = '弱';
    } else if (_passwordStrength < 0.5) {
      color = AppColors.warning;
      label = '一般';
    } else if (_passwordStrength < 0.75) {
      color = AppColors.primary;
      label = '较强';
    } else {
      color = AppColors.profit;
      label = '强';
    }

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey[200],
            color: color,
            minHeight: 4,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
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
    ref.read(authProvider.notifier).register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    ).then((success) {
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录'), backgroundColor: AppColors.profit),
        );
        context.pop();
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
