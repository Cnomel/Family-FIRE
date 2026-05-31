import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../../core/api/api_client.dart';

class DocumentListPage extends ConsumerStatefulWidget {
  const DocumentListPage({super.key});

  @override
  ConsumerState<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends ConsumerState<DocumentListPage> {
  List<dynamic> _folders = [];
  List<dynamic> _documents = [];
  bool _isLoading = true;
  String? _currentFolderId;
  String? _currentFolderName;
  final List<Map<String, String>> _folderStack = []; // 导航历史

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final queryParams = _currentFolderId != null ? {'folder_id': _currentFolderId} : null;
      final response = await client.get('/api/documents/', queryParams: queryParams);
      final data = response.data['data'];
      setState(() {
        _folders = data['folders'] ?? [];
        _documents = data['documents'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToFolder(String folderId, String folderName) {
    setState(() {
      _folderStack.add({'id': _currentFolderId ?? '', 'name': _currentFolderName ?? '文档'});
      _currentFolderId = folderId;
      _currentFolderName = folderName;
    });
    _loadData();
  }

  void _navigateBack() {
    if (_folderStack.isNotEmpty) {
      final prev = _folderStack.removeLast();
      setState(() {
        _currentFolderId = prev['id']!.isEmpty ? null : prev['id'];
        _currentFolderName = prev['name'];
      });
      _loadData();
    }
  }

  void _navigateToRoot() {
    setState(() {
      _folderStack.clear();
      _currentFolderId = null;
      _currentFolderName = null;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFolderName ?? '文档'),
        leading: _folderStack.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateBack,
              )
            : null,
        actions: [
          if (_folderStack.isNotEmpty)
            TextButton(
              onPressed: _navigateToRoot,
              child: const Text('根目录'),
            ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _showCreateFolderDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty && _documents.isEmpty
              ? _buildEmptyState()
              : _buildListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/documents/upload');
          _loadData();
        },
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('暂无文档', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          const Text('点击右下角按钮上传文档', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView(
      children: [
        // 文件夹列表
        if (_folders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('文件夹', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          ..._folders.map((folder) => _buildFolderTile(folder)),
        ],

        // 文档列表
        if (_documents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('文档', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          ..._documents.map((doc) => _buildDocumentTile(doc)),
        ],
      ],
    );
  }

  Widget _buildFolderTile(Map<String, dynamic> folder) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.folder, color: Colors.amber),
      ),
      title: Text(folder['name'] ?? ''),
      trailing: PopupMenuButton(
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
        onSelected: (value) {
          if (value == 'delete') _deleteFolder(folder['id']);
        },
      ),
      onTap: () => _navigateToFolder(folder['id'], folder['name']),
    );
  }

  Widget _buildDocumentTile(Map<String, dynamic> doc) {
    final name = doc['name'] ?? doc['file_name'] ?? '';
    final docType = doc['doc_type'] ?? doc['type'] ?? '';
    final fileSize = doc['file_size'] ?? 0;
    final createdAt = doc['created_at'] as String?;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getDocTypeColor(docType).withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getDocTypeIcon(docType), color: _getDocTypeColor(docType)),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_getDocTypeLabel(docType)} · ${_formatFileSize(fileSize)}${createdAt != null ? ' · ${_formatDate(createdAt)}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton(
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'download', child: Text('下载')),
          const PopupMenuItem(value: 'move', child: Text('移动')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
        onSelected: (value) {
          if (value == 'download') _downloadDocument(doc['id'], doc['name'] ?? doc['file_name'] ?? 'document');
          if (value == 'move') _showMoveDialog(doc['id']);
          if (value == 'delete') _deleteDocument(doc['id']);
        },
      ),
      onTap: () => _viewDocument(doc['id']),
    );
  }

  IconData _getDocTypeIcon(String type) {
    switch (type) {
      case 'receipt': return Icons.receipt;
      case 'warranty': return Icons.verified_user;
      case 'policy': return Icons.policy;
      case 'contract': return Icons.description;
      case 'manual': return Icons.menu_book;
      case 'photo': return Icons.photo;
      case 'appraisal': return Icons.assessment;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getDocTypeColor(String type) {
    switch (type) {
      case 'receipt': return Colors.green;
      case 'warranty': return Colors.blue;
      case 'policy': return Colors.purple;
      case 'contract': return Colors.orange;
      case 'manual': return Colors.teal;
      case 'photo': return Colors.pink;
      case 'appraisal': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  String _getDocTypeLabel(String type) {
    switch (type) {
      case 'receipt': return '收据';
      case 'warranty': return '保修卡';
      case 'policy': return '保单';
      case 'contract': return '合同';
      case 'manual': return '说明书';
      case 'photo': return '照片';
      case 'appraisal': return '评估';
      default: return '文档';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '文件夹名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                final client = ref.read(apiClientProvider);
                await client.post('/api/documents/folders', data: FormData.fromMap({
                  'name': name,
                  if (_currentFolderId != null) 'parent_id': _currentFolderId,
                }));
                if (mounted) Navigator.pop(ctx);
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建失败')));
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog(String docId) {
    // 获取所有文件夹列表
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移动到'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_special),
                title: const Text('根目录'),
                onTap: () async {
                  await _moveDocument(docId, null);
                  if (mounted) Navigator.pop(ctx);
                },
              ),
              ..._folders.map((folder) => ListTile(
                leading: const Icon(Icons.folder, color: Colors.amber),
                title: Text(folder['name']),
                onTap: () async {
                  await _moveDocument(docId, folder['id']);
                  if (mounted) Navigator.pop(ctx);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveDocument(String docId, String? targetFolderId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/api/documents/$docId/move', data: FormData.fromMap({
        'folder_id': targetFolderId ?? '',
      }));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('移动成功')));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('移动失败')));
      }
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹'),
        content: const Text('文件夹内的文档将移到根目录，确定删除吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.delete('/api/documents/folders/$folderId');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
        }
      }
    }
  }

  Future<void> _deleteDocument(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文档'),
        content: const Text('确定删除此文档吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.delete('/api/documents/$docId');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
        }
      }
    }
  }

  void _viewDocument(String docId) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/documents/$docId');
      final data = response.data['data'];
      final previewUrl = data['preview_url'] as String?;
      final mimeType = data['mime_type'] as String? ?? '';
      final name = data['name'] as String? ?? data['file_name'] as String? ?? '';

      if (mounted && previewUrl != null && previewUrl.isNotEmpty) {
        _showPreviewDialog(previewUrl, mimeType, name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('获取文档信息失败')));
      }
    }
  }

  Future<void> _downloadDocument(String docId, String fileName) async {
    try {
      // 显示下载进度
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在下载...')));
      }

      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/documents/$docId');
      final data = response.data['data'];
      final previewUrl = data['preview_url'] as String?;

      if (previewUrl == null || previewUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法获取下载链接')));
        }
        return;
      }

      // 获取下载目录
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // 下载文件
      final dio = Dio();
      await dio.download(previewUrl, filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载完成: $fileName'),
            action: SnackBarAction(
              label: '打开',
              onPressed: () => OpenFile.open(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下载失败')));
      }
    }
  }

  void _showPreviewDialog(String url, String mimeType, String name) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(name, style: const TextStyle(fontSize: 14)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: mimeType.contains('pdf')
                    ? const Center(child: Text('PDF预览暂不支持'))
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Text('加载失败'));
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
