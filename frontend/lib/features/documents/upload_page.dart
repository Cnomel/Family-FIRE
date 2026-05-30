import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final _descController = TextEditingController();
  String? _selectedAssetId;
  String _docType = 'receipt';
  File? _selectedFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _selectedFile = File(image.path));
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedFile = File(image.path));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final client = ref.read(apiClientProvider);
      final fileName = _selectedFile!.path.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_selectedFile!.path, filename: fileName),
        'type': _docType,
        if (_selectedAssetId != null) 'asset_id': _selectedAssetId,
        if (_descController.text.isNotEmpty) 'description': _descController.text.trim(),
      });

      await client.upload('/api/documents/upload', data: formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传成功')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传失败')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上传文档')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 文件选择
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择文件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPickButton(Icons.camera_alt, '拍照', _pickFromCamera),
                      _buildPickButton(Icons.photo_library, '相册', _pickFromGallery),
                      _buildPickButton(Icons.insert_drive_file, '文件', _pickFile),
                    ],
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFile!.path.split('/').last,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _selectedFile = null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 文档类型
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('文档类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ('receipt', '收据'),
                      ('warranty', '保修卡'),
                      ('policy', '保单'),
                      ('contract', '合同'),
                      ('manual', '说明书'),
                      ('photo', '照片'),
                      ('appraisal', '评估'),
                    ].map((type) => ChoiceChip(
                      label: Text(type.$2),
                      selected: _docType == type.$1,
                      onSelected: (_) => setState(() => _docType = type.$1),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 描述
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '描述 (可选)'),
                maxLines: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 上传按钮
          ElevatedButton(
            onPressed: _selectedFile != null && !_isUploading ? _upload : null,
            child: _isUploading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('上传'),
          ),
        ],
      ),
    );
  }

  Widget _buildPickButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
