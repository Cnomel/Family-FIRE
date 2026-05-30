import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _isScanning = false;
  String? _scannedCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码添加')),
      body: Column(
        children: [
          // 相机预览区域
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 相机占位
                  const Center(
                    child: Text(
                      '相机预览区域\n请对准条形码或二维码',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  // 扫描框
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // 扫描线动画
                  if (_isScanning)
                    AnimatedPositioned(
                      duration: const Duration(seconds: 2),
                      top: _isScanning ? 250 : 0,
                      child: Container(
                        width: 230,
                        height: 2,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 操作区域
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_scannedCode != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text('扫描结果', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(
                              _scannedCode!,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/assets/create'),
                            icon: const Icon(Icons.add),
                            label: const Text('创建资产'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _scannedCode = null;
                                _isScanning = false;
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新扫描'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Icon(
                      Icons.qr_code_scanner,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '将条形码或二维码放入扫描框内',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('开始扫描'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/assets/create'),
                      icon: const Icon(Icons.edit),
                      label: const Text('手动输入'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startScan() {
    setState(() => _isScanning = true);
    // 模拟扫描结果
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scannedCode = '6901234567890'; // 示例条形码
        });
      }
    });
  }
}
