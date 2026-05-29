import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
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
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person_outline), hintText: '3-20位，字母数字下划线'),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入用户名';
                  if (v.length < 3) return '用户名至少3位';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return '仅支持字母、数字、下划线';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined), hintText: 'name@example.com'),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入邮箱';
                  if (!v.contains('@') || !v.contains('.')) return '邮箱格式不正确';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '姓名', prefixIcon: Icon(Icons.badge_outlined), hintText: '您的真实姓名'),
                validator: (v) => (v == null || v.isEmpty) ? '请输入姓名' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock_outline), hintText: '至少8位'),
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
                      color: _strength < 0.3 ? kErrorColor : _strength < 0.7 ? kWarningColor : kLossColor,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_strengthLabel, style: TextStyle(fontSize: 12, color: _strengthColor)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v != _passCtrl.text ? '两次密码不一致' : null,
              ),

              // 错误提示
              ListenableBuilder(
                listenable: authState,
                builder: (context, _) {
                  if (authState.error == null) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kErrorColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(authState.error!, style: const TextStyle(color: kErrorColor)),
                  );
                },
              ),
              const SizedBox(height: 24),

              ListenableBuilder(
                listenable: authState,
                builder: (context, _) {
                  return ElevatedButton(
                    onPressed: authState.loading ? null : _register,
                    child: authState.loading
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

  String get _strengthLabel {
    if (_strength < 0.25) return '弱';
    if (_strength < 0.5) return '一般';
    if (_strength < 0.75) return '较强';
    return '强';
  }

  Color get _strengthColor {
    if (_strength < 0.3) return kErrorColor;
    if (_strength < 0.7) return kWarningColor;
    return kLossColor;
  }

  void _checkStrength(String p) {
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (p.contains(RegExp(r'[a-z]'))) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    setState(() => _strength = s);
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;
    authState.register(
      _userCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
      _nameCtrl.text.trim(),
    ).then((ok) {
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录'), backgroundColor: kLossColor),
        );
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}
