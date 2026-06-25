import 'package:flutter/material.dart';

import '../../../core/network/file_access.dart';
import '../../../core/theme/app_colors.dart';

/// Full-screen zoomable image viewer with the auth header attached and
/// graceful error handling (never a blank screen / browser 404).
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.url, required this.name});

  final String url;
  final String name;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    FileAccess.authHeaders().then((h) {
      if (mounted) setState(() => _headers = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.name, overflow: TextOverflow.ellipsis),
      ),
      body: _headers == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),)
          : InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  widget.url,
                  headers: _headers,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    FileAccess.log('image load failed: $error');
                    return const _ViewerError(
                      message:
                          'Could not open this image.\nIt may be missing or you may not have access.',
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _ViewerError extends StatelessWidget {
  const _ViewerError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 56,),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
