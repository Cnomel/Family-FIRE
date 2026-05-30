import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

class PdfViewerPage extends ConsumerStatefulWidget {
  final String documentId;
  const PdfViewerPage({super.key, required this.documentId});

  @override
  ConsumerState<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends ConsumerState<PdfViewerPage> {
  String? _previewUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/documents/${widget.documentId}');
      setState(() {
        _previewUrl = response.data['data']?['preview_url'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF预览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share document
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDocument,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _previewUrl != null && _previewUrl!.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('PDF文档'),
                          const SizedBox(height: 8),
                          Text(_previewUrl!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              // TODO: Open PDF with pdfx
                            },
                            child: const Text('打开PDF'),
                          ),
                        ],
                      ),
                    )
                  : const Center(child: Text('无法加载PDF')),
    );
  }
}
