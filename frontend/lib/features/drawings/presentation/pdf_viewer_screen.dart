import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_colors.dart';

/// Full-screen PDF/drawing viewer with zoom, page navigation and download.
/// Receives the file's download URL and name via [extra].
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

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    final token = await SecureStore.instance.accessToken;
    setState(() {
      _headers = {if (token != null) 'Authorization': 'Bearer $token'};
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
      body: _headers == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SfPdfViewer.network(
              widget.url,
              headers: _headers,
              controller: _controller,
              canShowScrollHead: true,
              enableDoubleTapZooming: true,
            ),
    );
  }
}
