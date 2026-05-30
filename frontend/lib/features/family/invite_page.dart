import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_client.dart';

class InvitePage extends ConsumerStatefulWidget {
  final String familyId;
  final String? inviteCode;

  const InvitePage({super.key, required this.familyId, this.inviteCode});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  String _code = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty) {
      _code = widget.inviteCode!;
      _isLoading = false;
    } else {
      // 延迟到下一帧执行，确保 ref 可用
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrGenerateCode();
      });
    }
  }

  Future<void> _loadOrGenerateCode() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);

      // 先尝试从家庭详情获取已有邀请码
      try {
        final familyResponse = await client.get('/api/families/${widget.familyId}');
        final data = familyResponse.data['data'];
        if (data != null) {
          final existingCode = data['invite_code'];
          if (existingCode != null && existingCode.toString().isNotEmpty) {
            if (mounted) {
              setState(() {
                _code = existingCode.toString();
                _isLoading = false;
              });
            }
            return;
          }
        }
      } catch (_) {
        // 获取失败，继续生成新的
      }

      // 生成新的邀请码
      final response = await client.post('/api/families/${widget.familyId}/invite');
      final data = response.data['data'];
      final code = data?['invite_code']?.toString() ?? '';

      if (mounted) {
        setState(() {
          _code = code;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '生成邀请码失败，请重试';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邀请成员')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadOrGenerateCode,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text('邀请码', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 12),
          SelectableText(
            _code,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('邀请码有效期7天', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 32),

          // QR Code
          if (_code.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _code,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: 32),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Share.share('邀请你加入我的家庭！邀请码: $_code');
                },
                icon: const Icon(Icons.share),
                label: const Text('分享'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '将邀请码分享给家庭成员，他们可以通过此码加入你的家庭',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
