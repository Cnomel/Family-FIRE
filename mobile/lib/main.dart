import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

// ==================== API Service ====================
class Api {
  static final Api i = Api._();
  Api._();
  String? _token;
  String get _base => 'http://localhost:8000/api';
  Map<String, String> get _h => {'Content-Type': 'application/json', if (_token != null) 'Authorization': 'Bearer $_token'};
  bool get loggedIn => _token != null;

  Future<Map<String, dynamic>> get(String p) => _req('GET', p);
  Future<Map<String, dynamic>> post(String p, {Map<String, dynamic>? b}) => _req('POST', p, b: b);
  Future<Map<String, dynamic>> put(String p, {Map<String, dynamic>? b}) => _req('PUT', p, b: b);
  Future<Map<String, dynamic>> del(String p) => _req('DELETE', p);

  Future<Map<String, dynamic>> _req(String m, String p, {Map<String, dynamic>? b}) async {
    final url = Uri.parse('$_base$p');
    http.Response r;
    try {
      if (m == 'GET') { r = await http.get(url, headers: _h); }
      else if (m == 'POST') { r = await http.post(url, headers: _h, body: jsonEncode(b ?? {})); }
      else if (m == 'PUT') { r = await http.put(url, headers: _h, body: jsonEncode(b ?? {})); }
      else { r = await http.delete(url, headers: _h); }
    } catch (e) { throw Exception('网络错误: $e'); }
    final body = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    String msg = '请求失败';
    if (body is Map && body['error'] is Map) msg = body['error']['message'] ?? msg;
    throw Exception(msg);
  }
}

// ==================== Theme ====================
const kPri = Color(0xFF1677FF);
const kPriDark = Color(0xFF0958D9);
const kPriLight = Color(0xFFE6F4FF);
const kRed = Color(0xFFFF4D4F);
const kGreen = Color(0xFF00B578);
const kWarn = Color(0xFFFAAD14);
const kBg = Color(0xFFF5F5F5);
const kText = Color(0xFF1F1F1F);
const kText2 = Color(0xFF8C8C8C);
const kText3 = Color(0xFFBFBFBF);
const kBorder = Color(0xFFE8E8E8);

ThemeData theme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: kPri),
  scaffoldBackgroundColor: kBg,
  appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: kText, elevation: 0, centerTitle: true),
  cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: kPri, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
  inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPri, width: 2))),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(selectedItemColor: kPri, unselectedItemColor: kText3, type: BottomNavigationBarType.fixed),
);

// ==================== Formatters ====================
String fmtAmt(double v) {
  if (v.abs() >= 1e8) return '¥${(v / 1e8).toStringAsFixed(2)}亿';
  if (v.abs() >= 1e4) return '¥${(v / 1e4).toStringAsFixed(2)}万';
  return '¥${v.toStringAsFixed(2)}';
}
String fmtPct(double v) => '${v > 0 ? '+' : ''}${(v * 100).toStringAsFixed(2)}%';
String fmtDate(String s) { try { final d = DateTime.parse(s); return '${d.month}月${d.day}日'; } catch (_) { return s; } }

// ==================== Main ====================
void main() => runApp(const App());
class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'Family Fire', theme: theme(), debugShowCheckedModeBanner: false, home: const Gate());
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}
class _GateState extends State<Gate> {
  @override
  Widget build(BuildContext context) => Api.i.loggedIn ? const Home() : const LoginPage();
}

// ==================== LOGIN PAGE ====================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  final _fk = GlobalKey<FormState>();
  bool _loading = false;
  String? _err;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _fk,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Container(width: 80, height: 80, decoration: BoxDecoration(color: kPriLight, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.local_fire_department, size: 48, color: kPri)),
                const SizedBox(height: 16),
                const Text('Family Fire', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('家庭资产管理系统', textAlign: TextAlign.center, style: TextStyle(color: kText2)),
                const SizedBox(height: 48),
                TextFormField(controller: _id, decoration: const InputDecoration(labelText: '用户名或邮箱', prefixIcon: Icon(Icons.person_outline), hintText: '请输入用户名或邮箱'), validator: (v) => v!.isEmpty ? '请输入' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _pass, obscureText: _obscure, decoration: InputDecoration(labelText: '密码', prefixIcon: const Icon(Icons.lock_outline), hintText: '请输入密码', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure))), validator: (v) => v!.isEmpty ? '请输入' : null),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withValues(alpha: 0.2))), child: Row(children: [const Icon(Icons.error_outline, color: kRed, size: 18), const SizedBox(width: 8), Expanded(child: Text(_err!, style: const TextStyle(color: kRed)))])),
                ],
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _loading ? null : _login, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登录', style: TextStyle(fontSize: 16))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('还没有账号？', style: TextStyle(color: kText2)),
                  GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('立即注册', style: TextStyle(color: kPri, fontWeight: FontWeight.w600))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _login() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _loading = true; _err = null; });
    try {
      final r = await Api.i.post('/auth/login', b: {'identifier': _id.text.trim(), 'password': _pass.text});
      Api.i._token = r['data']['access_token'];
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
    } catch (e) {
      setState(() { _err = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _id.dispose(); _pass.dispose(); super.dispose(); }
}

// ==================== REGISTER PAGE ====================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}
class _RegisterPageState extends State<RegisterPage> {
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _fk = GlobalKey<FormState>();
  bool _loading = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _fk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _user, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person_outline), hintText: '3-20位，字母数字下划线'), validator: (v) { if (v!.isEmpty) return '请输入用户名'; if (v.length < 3) return '至少3位'; return null; }),
              const SizedBox(height: 16),
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined), hintText: 'name@example.com'), validator: (v) { if (v!.isEmpty) return '请输入邮箱'; if (!v.contains('@')) return '邮箱格式不正确'; return null; }),
              const SizedBox(height: 16),
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: '姓名', prefixIcon: Icon(Icons.badge_outlined), hintText: '您的真实姓名'), validator: (v) => v!.isEmpty ? '请输入姓名' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock_outline), hintText: '至少8位'), validator: (v) { if (v!.isEmpty) return '请输入密码'; if (v.length < 8) return '至少8位'; return null; }),
              const SizedBox(height: 16),
              TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: '确认密码', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v != _pass.text ? '密码不一致' : null),
              if (_err != null) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Text(_err!, style: const TextStyle(color: kRed)))],
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loading ? null : _register, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('注册', style: TextStyle(fontSize: 16))),
            ],
          ),
        ),
      ),
    );
  }

  void _register() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _loading = true; _err = null; });
    try {
      await Api.i.post('/auth/register', b: {'username': _user.text.trim(), 'email': _email.text.trim(), 'password': _pass.text, 'full_name': _name.text.trim()});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册成功，请登录'), backgroundColor: kGreen)); Navigator.pop(context); }
    } catch (e) {
      setState(() { _err = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _user.dispose(); _email.dispose(); _name.dispose(); _pass.dispose(); _confirm.dispose(); super.dispose(); }
}

// ==================== HOME PAGE ====================
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  int _tab = 0;
  bool _privacy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Fire'),
        actions: [
          IconButton(icon: Icon(_privacy ? Icons.visibility_off : Icons.visibility_outlined), onPressed: () => setState(() => _privacy = !_privacy)),
          IconButton(icon: const Icon(Icons.logout), onPressed: () { Api.i._token = null; setState(() {}); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())); }),
        ],
      ),
      body: IndexedStack(index: _tab, children: [Dash(privacy: _privacy), AssetsPage(privacy: _privacy), FinancePage(privacy: _privacy), SettingsPage(privacy: _privacy)]),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _tab, onTap: (i) => setState(() => _tab = i), items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '首页'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: '资产'),
        BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined), activeIcon: Icon(Icons.trending_up), label: '财务'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: '设置'),
      ]),
    );
  }
}

// ==================== DASHBOARD ====================
class Dash extends StatefulWidget {
  final bool privacy;
  const Dash({super.key, required this.privacy});
  @override
  State<Dash> createState() => _DashState();
}
class _DashState extends State<Dash> {
  Map<String, dynamic> _nw = {};
  Map<String, dynamic> _fire = {};
  List<dynamic> _tx = [];
  Map<String, dynamic> _alloc = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        Api.i.get('/families/current/finance/fire/net-worth').catchError((_) => {'data': {}}),
        Api.i.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        Api.i.get('/families/current/finance/income-expense?page_size=5').catchError((_) => {'data': {'records': []}}),
        Api.i.get('/families/current/finance/fire/allocation').catchError((_) => {'data': {}}),
      ]);
      setState(() { _nw = r[0]['data'] ?? {}; _fire = r[1]['data'] ?? {}; _tx = r[2]['data']['records'] ?? []; _alloc = r[3]['data'] ?? {}; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // 净资产卡片
        Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPri, kPriDark]), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('净资产', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text(widget.privacy ? '****' : fmtAmt((_nw['net_worth'] ?? 0).toDouble()), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text(widget.privacy ? '****' : '流动资产 ${fmtAmt((_nw['liquid_net_worth'] ?? 0).toDouble())}', style: const TextStyle(color: Colors.white, fontSize: 12))),
          ])),
        const SizedBox(height: 12),
        // FIRE指标
        Row(children: [
          _metric('储蓄率', widget.privacy ? '**%' : fmtPct((_fire['savings_rate'] ?? 0).toDouble()), kRed, Icons.savings_outlined),
          const SizedBox(width: 8),
          _metric('FIRE进度', widget.privacy ? '**%' : fmtPct((_fire['fi_ratio'] ?? 0).toDouble()), kPri, Icons.local_fire_department),
          const SizedBox(width: 8),
          _metric('距FIRE', widget.privacy ? '**' : '${_fire['years_to_fire'] ?? 999}年', kWarn, Icons.timer_outlined),
        ]),
        const SizedBox(height: 24),
        // 资产配置
        const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _alloc.isEmpty ? _empty('暂无资产数据') : Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: _alloc.entries.where((e) => (e.value as num) > 0).map((e) {
            final pct = (e.value * 100).toDouble();
            final colors = [kPri, kGreen, kWarn, Colors.purple, Colors.teal];
            final idx = _alloc.keys.toList().indexOf(e.key);
            return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[idx % colors.length], borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10), Text(_natureLabel(e.key)), const Spacer(),
              Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8), SizedBox(width: 80, child: LinearProgressIndicator(value: pct / 100, backgroundColor: kBorder, color: colors[idx % colors.length], minHeight: 6, borderRadius: BorderRadius.circular(3))),
            ]));
          }).toList())),
        const SizedBox(height: 24),
        // 最近交易
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('最近交易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          TextButton(onPressed: () {}, child: const Text('查看全部')),
        ]),
        const SizedBox(height: 8),
        _tx.isEmpty ? _empty('暂无交易记录') : Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: _tx.map((t) {
            final isInc = t['type'] == 'income';
            return ListTile(
              leading: CircleAvatar(backgroundColor: (isInc ? kRed : kGreen).withValues(alpha: 0.1), child: Icon(isInc ? Icons.arrow_downward : Icons.arrow_upward, color: isInc ? kRed : kGreen, size: 20)),
              title: Text(t['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(fmtDate(t['date'] ?? ''), style: const TextStyle(color: kText2, fontSize: 12)),
              trailing: Text(widget.privacy ? '****' : '${isInc ? '+' : '-'}${fmtAmt((t['amount'] ?? 0).toDouble())}', style: TextStyle(color: isInc ? kRed : kGreen, fontWeight: FontWeight.w600)),
            );
          }).toList())),
      ]),
    );
  }

  Widget _metric(String l, String v, Color c, IconData i) => Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: Column(children: [Icon(i, color: c, size: 22), const SizedBox(height: 6), Text(v, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(l, style: const TextStyle(color: kText2, fontSize: 11))])));

  String _natureLabel(String n) => switch (n) { 'tangible' => '实物资产', 'financial' => '金融资产', 'digital' => '数字资产', 'service' => '服务订阅', 'intangible' => '保险', _ => n };
  Widget _empty(String t) => Container(width: double.infinity, padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: kText2)));
}

// ==================== ASSETS PAGE ====================
class AssetsPage extends StatefulWidget {
  final bool privacy;
  const AssetsPage({super.key, required this.privacy});
  @override
  State<AssetsPage> createState() => _AssetsPageState();
}
class _AssetsPageState extends State<AssetsPage> {
  List<dynamic> _assets = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.i.get('/families/current/assets');
      setState(() { _assets = r['data']['assets'] ?? []; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资产'), automaticallyImplyLeading: false, actions: [IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _add)]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: Column(children: [
        SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
          _chip('全部', 'all'), _chip('📦 实物', 'tangible'), _chip('📈 金融', 'financial'), _chip('💻 数字', 'digital'), _chip('🎬 服务', 'service'), _chip('🛡️ 保险', 'intangible'),
        ])),
        Expanded(child: _list()),
      ])),
    );
  }

  Widget _chip(String l, String v) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FilterChip(label: Text(l, style: TextStyle(fontSize: 13, color: _filter == v ? Colors.white : kText)), selected: _filter == v, onSelected: (_) => setState(() => _filter = v), selectedColor: kPri, backgroundColor: Colors.white, side: BorderSide(color: _filter == v ? kPri : kBorder), showCheckmark: false));

  Widget _list() {
    final filtered = _filter == 'all' ? _assets : _assets.where((a) => a['nature'] == _filter).toList();
    if (filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance_wallet_outlined, size: 64, color: kText3), const SizedBox(height: 16), const Text('暂无资产', style: TextStyle(fontSize: 16, color: kText2)), const SizedBox(height: 8), const Text('点击右上角 + 添加', style: TextStyle(color: kText3))]));
    return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: filtered.length, itemBuilder: (context, i) => _card(filtered[i]));
  }

  Widget _card(Map<String, dynamic> a) {
    final value = (a['financial']?['current_value'] ?? 0).toDouble();
    final natureEmoji = switch (a['nature']) { 'tangible' => '📦', 'financial' => '📈', 'digital' => '💻', 'service' => '🎬', 'intangible' => '🛡️', _ => '📋' };
    return Card(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _detail(a), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: kPriLight, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(natureEmoji, style: const TextStyle(fontSize: 22)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), const SizedBox(height: 2), Text(_natureLabel(a['nature'] ?? ''), style: const TextStyle(color: kText2, fontSize: 12))])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(widget.privacy ? '****' : fmtAmt(value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))]),
    ]))));
  }

  void _add() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String nature = 'tangible';
    String utility = 'essential';
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('添加资产', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '资产名称', prefixIcon: Icon(Icons.label_outline))),
          const SizedBox(height: 16),
          const Text('性质', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [_rc('实物', 'tangible', nature, (v) => setSheet(() => nature = v)), _rc('金融', 'financial', nature, (v) => setSheet(() => nature = v)), _rc('数字', 'digital', nature, (v) => setSheet(() => nature = v)), _rc('服务', 'service', nature, (v) => setSheet(() => nature = v))]),
          const SizedBox(height: 12),
          const Text('用途', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [_rc('必需', 'essential', utility, (v) => setSheet(() => utility = v)), _rc('生活', 'lifestyle', utility, (v) => setSheet(() => utility = v)), _rc('投资', 'productive', utility, (v) => setSheet(() => utility = v)), _rc('消耗', 'consumable', utility, (v) => setSheet(() => utility = v))]),
          const SizedBox(height: 16),
          TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '购买价格', prefixIcon: Icon(Icons.attach_money), hintText: '0.00')),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            try {
              await Api.i.post('/families/current/assets', b: {'name': nameCtrl.text, 'nature': nature, 'utility': utility, 'ownership': 'owned', 'liquidity': 'medium', 'purchase_price': double.tryParse(priceCtrl.text) ?? 0});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('资产添加成功'), backgroundColor: kGreen));
            } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: kRed)); }
          }, child: const Text('添加资产')),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }

  Widget _rc(String l, String v, String sel, ValueChanged<String> onChanged) {
    final s = sel == v;
    return ChoiceChip(label: Text(l, style: TextStyle(color: s ? Colors.white : kText)), selected: s, onSelected: (_) => onChanged(v), selectedColor: kPri, backgroundColor: Colors.white, side: BorderSide(color: s ? kPri : kBorder), showCheckmark: false);
  }

  void _detail(Map<String, dynamic> a) {
    final fin = a['financial'] ?? {};
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: kPriLight, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(switch (a['nature']) { 'tangible' => '📦', 'financial' => '📈', 'digital' => '💻', 'service' => '🎬', 'intangible' => '🛡️', _ => '📋' }, style: const TextStyle(fontSize: 24)))), const SizedBox(width: 12), Expanded(child: Text(a['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))]),
        const SizedBox(height: 20),
        _dr('分类', _natureLabel(a['nature'] ?? '')),
        _dr('用途', a['utility'] ?? ''),
        _dr('持有', a['ownership'] ?? ''),
        _dr('流动性', a['liquidity'] ?? ''),
        const Divider(height: 24),
        _dr('当前价值', fmtAmt((fin['current_value'] ?? 0).toDouble())),
        _dr('购买价格', fmtAmt((fin['purchase_price'] ?? 0).toDouble())),
        if (a['tags'] != null && (a['tags'] as List).isNotEmpty) _dr('标签', (a['tags'] as List).join('、')),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.edit), label: const Text('编辑'))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(onPressed: () async { await Api.i.del('/families/current/assets/${a['id']}'); if (ctx.mounted) Navigator.pop(ctx); _load(); }, icon: const Icon(Icons.archive_outlined, color: kWarn), label: const Text('归档', style: TextStyle(color: kWarn)))),
        ]),
        const SizedBox(height: 8),
      ])),
    );
  }

  Widget _dr(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: kText2)), Text(v, style: const TextStyle(fontWeight: FontWeight.w500))]));
  String _natureLabel(String n) => switch (n) { 'tangible' => '实物资产', 'financial' => '金融资产', 'digital' => '数字资产', 'service' => '服务订阅', 'intangible' => '保险', _ => n };
}

// ==================== FINANCE PAGE ====================
class FinancePage extends StatefulWidget {
  final bool privacy;
  const FinancePage({super.key, required this.privacy});
  @override
  State<FinancePage> createState() => _FinancePageState();
}
class _FinancePageState extends State<FinancePage> {
  Map<String, dynamic> _fire = {};
  Map<String, dynamic> _alloc = {};
  Map<String, dynamic> _sum = {};
  List<dynamic> _records = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        Api.i.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        Api.i.get('/families/current/finance/fire/allocation').catchError((_) => {'data': {}}),
        Api.i.get('/families/current/finance/income-expense/summary').catchError((_) => {'data': {}}),
        Api.i.get('/families/current/finance/income-expense').catchError((_) => {'data': {'records': []}}),
      ]);
      setState(() { _fire = r[0]['data'] ?? {}; _alloc = r[1]['data'] ?? {}; _sum = r[2]['data'] ?? {}; _records = r[3]['data']['records'] ?? []; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // FIRE卡片
        Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPri, kPriDark]), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FIRE 仪表盘', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(children: [_fs('净资产', fmtAmt((_fire['net_worth']?['net_worth'] ?? 0).toDouble())), _fs('FIRE数字', fmtAmt((_fire['fire_number'] ?? 0).toDouble())), _fs('完成度', '${((_fire['fi_ratio'] ?? 0) * 100).toStringAsFixed(1)}%')]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ((_fire['fi_ratio'] ?? 0) as num).toDouble().clamp(0, 1), backgroundColor: Colors.white.withValues(alpha: 0.3), color: Colors.white, minHeight: 8)),
          ])),
        const SizedBox(height: 12),
        // 收支汇总
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _si('收入', (_sum['total_income'] ?? 0).toDouble(), kRed),
            Container(width: 1, height: 40, color: kBorder),
            _si('支出', (_sum['total_expense'] ?? 0).toDouble(), kGreen),
            Container(width: 1, height: 40, color: kBorder),
            _si('结余', (_sum['net'] ?? 0).toDouble(), kPri),
          ])),
        const SizedBox(height: 24),
        const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _alloc.isEmpty ? _empty('暂无资产数据') : Container(height: 200, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: PieChart(PieChartData(sections: _alloc.entries.where((e) => (e.value as num) > 0).toList().asMap().entries.map((e) {
            final pct = (e.value.value * 100).toDouble();
            final colors = [kPri, kGreen, kWarn, Colors.purple, Colors.teal];
            return PieChartSectionData(value: pct, title: '${pct.toStringAsFixed(0)}%', color: colors[e.key % colors.length], radius: 60, titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600));
          }).toList(), sectionsSpace: 2, centerSpaceRadius: 40))),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('收支记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), ElevatedButton.icon(onPressed: _addRecord, icon: const Icon(Icons.add, size: 18), label: const Text('记账'))]),
        const SizedBox(height: 8),
        _records.isEmpty ? _empty('暂无收支记录') : Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: _records.map((r) {
            final isInc = r['type'] == 'income';
            return Dismissible(key: Key(r['id']), direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), color: kRed, child: const Icon(Icons.delete, color: Colors.white)),
              onDismissed: (_) async { await Api.i.del('/families/current/finance/income-expense/${r['id']}'); _load(); },
              child: ListTile(
                leading: CircleAvatar(backgroundColor: (isInc ? kRed : kGreen).withValues(alpha: 0.1), child: Icon(isInc ? Icons.arrow_downward : Icons.arrow_upward, color: isInc ? kRed : kGreen, size: 20)),
                title: Text(r['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(fmtDate(r['date'] ?? ''), style: const TextStyle(color: kText2, fontSize: 12)),
                trailing: Text(widget.privacy ? '****' : '${isInc ? '+' : '-'}${fmtAmt((r['amount'] ?? 0).toDouble())}', style: TextStyle(color: isInc ? kRed : kGreen, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList())),
      ]),
    );
  }

  Widget _fs(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), Text(v, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))]));
  Widget _si(String l, double v, Color c) => Expanded(child: Column(children: [Text(l, style: const TextStyle(color: kText2, fontSize: 12)), const SizedBox(height: 4), Text(fmtAmt(v), style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w600))]));

  void _addRecord() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'expense';
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('记录收支', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setSheet(() => type = 'income'), style: OutlinedButton.styleFrom(backgroundColor: type == 'income' ? kRed.withValues(alpha: 0.1) : null, side: BorderSide(color: type == 'income' ? kRed : kBorder)), child: Text('收入', style: TextStyle(color: type == 'income' ? kRed : kText2)))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(onPressed: () => setSheet(() => type = 'expense'), style: OutlinedButton.styleFrom(backgroundColor: type == 'expense' ? kGreen.withValues(alpha: 0.1) : null, side: BorderSide(color: type == 'expense' ? kGreen : kBorder)), child: Text('支出', style: TextStyle(color: type == 'expense' ? kGreen : kText2)))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '金额', prefixIcon: Icon(Icons.attach_money), hintText: '0.00')),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述', prefixIcon: Icon(Icons.note_outlined), hintText: '例如：超市购物')),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            if (amountCtrl.text.isEmpty || descCtrl.text.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写金额和描述'), backgroundColor: kRed)); return; }
            try {
              await Api.i.post('/families/current/finance/income-expense', b: {'type': type, 'amount': double.tryParse(amountCtrl.text) ?? 0, 'description': descCtrl.text, 'date': DateTime.now().toIso8601String()});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('记录成功'), backgroundColor: kGreen));
            } catch (e) { ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: kRed)); }
          }, child: const Text('保存')),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }

  Widget _empty(String t) => Container(width: double.infinity, padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: kText2)));
}

// ==================== SETTINGS PAGE ====================
class SettingsPage extends StatefulWidget {
  final bool privacy;
  const SettingsPage({super.key, required this.privacy});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.i.get('/auth/me');
      setState(() { _user = r['data']; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), automaticallyImplyLeading: false),
      body: ListView(children: [
        if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_user != null) Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
          child: Row(children: [
            CircleAvatar(radius: 28, backgroundColor: kPriLight, child: Text((_user!['full_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: kPri))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_user!['full_name'] ?? _user!['username'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_user!['email'] ?? '', style: const TextStyle(color: kText2, fontSize: 13)),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kPriLight, borderRadius: BorderRadius.circular(4)), child: Text(_roleLabel(_user!['role'] ?? ''), style: const TextStyle(color: kPri, fontSize: 11))),
            ])),
          ])),
        _section('外观', [_item(Icons.palette_outlined, '主题', '跟随系统'), _item(Icons.language_outlined, '语言', '中文')]),
        _section('通知', [_item(Icons.notifications_outlined, '通知设置', '管理通知偏好')]),
        _section('家庭', [_item(Icons.family_restroom, '家庭管理', '管理家庭和成员')]),
        _section('关于', [_item(Icons.info_outline, '关于 Family Fire', '版本 0.1.0'), _item(Icons.description_outlined, '开源协议', 'MIT License')]),
        const SizedBox(height: 24),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: OutlinedButton.icon(
          onPressed: () { Api.i._token = null; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())); },
          icon: const Icon(Icons.logout, color: kRed), label: const Text('退出登录', style: TextStyle(color: kRed)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed), padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
        const SizedBox(height: 32),
      ]),
    );
  }

  String _roleLabel(String r) => switch (r) { 'admin' => '系统管理员', 'family_admin' => '家庭管理员', 'member' => '成员', _ => r };

  Widget _section(String t, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText2))),
    Container(margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(children: children)),
  ]);

  Widget _item(IconData icon, String t, String sub) => ListTile(leading: Icon(icon, color: kPri, size: 22), title: Text(t, style: const TextStyle(fontSize: 15)), subtitle: Text(sub, style: const TextStyle(color: kText2, fontSize: 12)), trailing: const Icon(Icons.chevron_right, color: kText3));
}
