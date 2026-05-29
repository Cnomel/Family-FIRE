import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

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
  bool _isLoading = false;
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
                  if (v?.isEmpty ?? true) return '请输入用户名';
                  if (v!.length < 3) return '用户名至少3位';
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
                  if (!v!.contains('@')) return '邮箱格式不正确';
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
                  return null;
                },
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _passwordStrength,
                backgroundColor: Colors.grey[200],
                color: _passwordStrength < 0.3
                    ? AppColors.loss
                    : _passwordStrength < 0.7
                        ? AppColors.warning
                        : AppColors.profit,
              ),
              const SizedBox(height: 4),
              Text(_passwordStrengthLabel, style: TextStyle(fontSize: 12, color: _passwordStrengthColor)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码', prefixIcon: Icon(Icons.lock)),
                validator: (v) => v != _passwordController.text ? '两次密码不一致' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading
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

  void _updatePasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  String get _passwordStrengthLabel {
    if (_passwordStrength < 0.25) return '弱';
    if (_passwordStrength < 0.5) return '一般';
    if (_passwordStrength < 0.75) return '较强';
    return '强';
  }

  Color get _passwordStrengthColor {
    if (_passwordStrength < 0.3) return AppColors.loss;
    if (_passwordStrength < 0.7) return AppColors.warning;
    return AppColors.profit;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // TODO: Call API
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) context.pop();
    setState(() => _isLoading = false);
  }
}
