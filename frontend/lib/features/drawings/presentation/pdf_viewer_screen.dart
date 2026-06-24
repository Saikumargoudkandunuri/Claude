import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/network/file_access.dart';
import '../../../core/theme/app_colors.dart';

/// Full-screen in-app PDF/drawing viewer (zoom, scroll) with the auth header
/// attached and graceful load-failure handling.
class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({super.key, required this.url, required this.name});

  final String url;
  final String name;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final _controller = PdfViewerController();
  Map<String, String>? _headers;
  String? _error;

  @override
  void initState() {
    super.initState();
    FileAccess.log('opening PDF ${widget.name} url=${widget.url}');
    FileAccess.authHeaders().then((h) {
      if (mounted) setState(() => _headers = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _controller.zoomLevel = _controller.zoomLevel + 0.25,
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _controller.zoomLevel =
                (_controller.zoomLevel - 0.25).clamp(1.0, 5.0),
          ),
        ],
      ),
      body: _error != null
          ? _PdfError(message: _error!)
          : _headers == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : SfPdfViewer.network(
                  widget.url,
                  headers: _headers,
                  controller: _controller,
                  canShowScrollHead: true,
                  enableDoubleTapZooming: true,
                  onDocumentLoadFailed: (details) {
                    FileAccess.log(
                        'PDF load failed: ${details.error} — ${details.description}');
                    if (mounted) {
                      setState(() => _error = _friendly(details.description));
                    }
                  },
                ),
    );
  }

  String _friendly(String description) {
    final d = description.toLowerCase();
    if (d.contains('404') || d.contains('not found')) {
      return 'File not found on server.';
    }
    if (d.contains('401') || d.contains('403') || d.contains('forbidden')) {
      return 'You do not have access to this file.';
    }
    return 'Could not open this file. Please try again later.';
  }
}

class _PdfError extends StatelessWidget {
  const _PdfError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 56),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
