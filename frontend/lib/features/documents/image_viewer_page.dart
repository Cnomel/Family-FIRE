import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/api/api_client.dart';

class ImageViewerPage extends ConsumerStatefulWidget {
  final String documentId;
  const ImageViewerPage({super.key, required this.documentId});

  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  String? _imageUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/documents/${widget.documentId}');
      setState(() {
        _imageUrl = response.data['data']?['preview_url'] ?? '';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片预览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share image
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.white)),
                )
              : _imageUrl != null && _imageUrl!.isNotEmpty
                  ? PhotoView(
                      imageProvider: CachedNetworkImageProvider(_imageUrl!),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3,
                      loadingBuilder: (_, __) => const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                      ),
                    )
                  : const Center(
                      child: Text('无法加载图片', style: TextStyle(color: Colors.white)),
                    ),
    );
  }
}
