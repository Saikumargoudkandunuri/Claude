import 'package:flutter/material.dart';

import '../../../core/network/file_access.dart';
import 'image_viewer_screen.dart';
import 'pdf_viewer_screen.dart';

/// Opens any stored file IN-APP using its file id (never the browser).
///  • PDF / drawing → in-app PDF viewer
///  • image          → zoomable image viewer
///  • other          → friendly "preview not available" message
///
/// The URL is built from API_BASE_URL and the viewers attach the JWT, so this
/// works for workers on Render without 404s.
Future<void> openAttachment(
  BuildContext context, {
  required String fileId,
  required String name,
  String? mimeType,
}) async {
  if (fileId.isEmpty) {
    _showMessage(context, 'Invalid attachment URL.');
    return;
  }

  final url = FileAccess.urlFor(fileId);
  FileAccess.log('open id=$fileId name=$name mime=$mimeType url=$url');

  final lower = name.toLowerCase();
  final mt = (mimeType ?? '').toLowerCase();
  final isPdf = mt.contains('pdf') || lower.endsWith('.pdf');
  const imageExt = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.bmp'];
  final isImage = mt.startsWith('image/') || imageExt.any(lower.endsWith);

  if (isPdf) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PdfViewerScreen(url: url, name: name)),
    );
  } else if (isImage) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImageViewerScreen(url: url, name: name)),
    );
  } else {
    _showMessage(
      context,
      'Preview is not available for this file type ($name). '
      'Ask an admin to upload it as a PDF or image.',
    );
  }
}

void _showMessage(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Attachment'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
