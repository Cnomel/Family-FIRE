import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_repository.dart';

const String _defaultFamilyId = 'current';

final documentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    // Get all assets first, then get documents for each
    final assetsResp = await api.dio.get('/families/$_defaultFamilyId/assets');
    final assets = assetsResp.data['data']['assets'] ?? [];
    
    List<dynamic> allDocs = [];
    for (final asset in assets) {
      try {
        final docsResp = await api.dio.get('/api/documents/asset/${asset['id']}?family_id=$_defaultFamilyId');
        final docs = docsResp.data['data'] ?? [];
        for (final doc in docs) {
          doc['asset_name'] = asset['name'];
          allDocs.add(doc);
        }
      } catch (e) {
        // Skip if error
      }
    }
    return allDocs;
  } catch (e) {
    return [];
  }
});

class DocumentListPage extends ConsumerWidget {
  const DocumentListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('文档')),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  const Text('暂无文档', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('在资产详情中上传文档', style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(documentsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) => _buildDocumentCard(context, docs[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, Map<String, dynamic> doc) {
    final fileName = doc['file_name'] ?? '';
    final mimeType = doc['mime_type'] ?? '';
    final fileSize = doc['file_size'] ?? 0;
    final assetName = doc['asset_name'] ?? '';
    final docType = doc['type'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(_getDocIcon(mimeType), color: AppColors.primary, size: 20),
        ),
        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (assetName.isNotEmpty) Text('资产: $assetName', style: const TextStyle(fontSize: 12)),
            Text('${_getDocTypeLabel(docType)} · ${_formatFileSize(fileSize)}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Open document preview
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文档预览功能开发中')),
          );
        },
      ),
    );
  }

  IconData _getDocIcon(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('image')) return Icons.image;
    return Icons.description;
  }

  String _getDocTypeLabel(String type) {
    switch (type) {
      case 'receipt': return '收据';
      case 'warranty': return '保修卡';
      case 'policy': return '保单';
      case 'contract': return '合同';
      case 'manual': return '说明书';
      case 'photo': return '照片';
      case 'appraisal': return '评估报告';
      default: return type;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
