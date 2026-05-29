import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;
  double _strength = 0;

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
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: '3-20位，字母数字下划线',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入用户名';
                  if (v.length < 3) return '用户名至少3位';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return '仅支持字母、数字、下划线';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'name@example.com',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入邮箱';
                  if (!v.contains('@')) return '邮箱格式不正确';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '姓名',
                  prefixIcon: Icon(Icons.badge_outlined),
                  hintText: '您的真实姓名',
                ),
                validator: (v) => (v == null || v.isEmpty) ? '请输入姓名' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock_outline),
                  hintText: '至少8位',
                ),
                onChanged: _checkStrength,
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入密码';
                  if (v.length < 8) return '密码至少8位';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // 密码强度条
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _strength,
                      backgroundColor: Colors.grey[200],
                      color: _strength < 0.3
                          ? kError
                          : _strength < 0.7
                              ? kWarn
                              : kLoss,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _strength < 0.25
                        ? '弱'
                        : _strength < 0.5
                            ? '一般'
                            : _strength < 0.75
                                ? '较强'
                                : '强',
                    style: TextStyle(
                      fontSize: 12,
                      color: _strength < 0.3
                          ? kError
                          : _strength < 0.7
                              ? kWarn
                              : kLoss,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => v != _passController.text ? '两次密码不一致' : null,
              ),

              // 错误提示
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: kError)),
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('注册', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    setState(() => _strength = strength);
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Api.instance.post('/auth/register', body: {
        'username': _userController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passController.text,
        'full_name': _nameController.text.trim(),
      });

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('注册成功，请登录'), backgroundColor: kLoss),
          );
          Navigator.pop(context);
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '网络错误，请检查连接');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
