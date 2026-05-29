import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

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
                // Logo
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.local_fire_department, size: 48, color: kPrimaryColor),
                ),
                const SizedBox(height: 16),
                const Text('Family Fire', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const SizedBox(height: 4),
                const Text('家庭资产管理系统', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: kTextSecondary)),
                const SizedBox(height: 48),

                // 用户名/邮箱
                TextFormField(
                  controller: _idCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户名或邮箱',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: '请输入用户名或邮箱',
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入用户名或邮箱' : null,
                  onChanged: (_) => authState.clearError(),
                ),
                const SizedBox(height: 16),

                // 密码
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: '请输入密码',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                  onChanged: (_) => authState.clearError(),
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
                        border: Border.all(color: kErrorColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: kErrorColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(authState.error!, style: const TextStyle(color: kErrorColor, fontSize: 14))),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 登录按钮
                ListenableBuilder(
                  listenable: authState,
                  builder: (context, _) {
                    return ElevatedButton(
                      onPressed: authState.loading ? null : _login,
                      child: authState.loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('登录'),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 注册链接
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('还没有账号？', style: TextStyle(color: kTextSecondary)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                      child: const Text('立即注册', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    authState.login(_idCtrl.text.trim(), _passCtrl.text);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
