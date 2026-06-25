import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/network/file_access.dart';
import '../../features/drawings/presentation/attachment_opener.dart';
import '../design/app_gradients.dart';
import 'shimmer_loader.dart';

/// Tappable file attachment that opens IN-APP (PDF/image viewer with JWT) —
/// never the browser, so workers don't hit 404s.
class AttachmentTile extends StatefulWidget {
  const AttachmentTile({
    super.key,
    required this.fileId,
    required this.fileName,
    this.mimeType = '',
    this.sizeLabel = '',
  });

  final String fileId;
  final String fileName;
  final String mimeType;
  final String sizeLabel;

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  Map<String, String>? _headers;

  bool get _isImage =>
      widget.mimeType.startsWith('image/') ||
      const ['.jpg', '.jpeg', '.png', '.webp', '.gif']
          .any(widget.fileName.toLowerCase().endsWith);
  bool get _isVideo => widget.mimeType.startsWith('video/');
  bool get _isAudio => widget.mimeType.startsWith('audio/');
  bool get _isPdf =>
      widget.mimeType.contains('pdf') ||
      widget.fileName.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    FileAccess.authHeaders().then((h) {
      if (mounted) setState(() => _headers = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openAttachment(
        context,
        fileId: widget.fileId,
        name: widget.fileName,
        mimeType: widget.mimeType,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppGradients.surfaceCard, AppGradients.surfaceDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppGradients.borderGlow),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (_isImage && _headers != null)
                ? CachedNetworkImage(
                    imageUrl: FileAccess.urlFor(widget.fileId),
                    httpHeaders: _headers,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ShimmerLoader(width: 48, height: 48, borderRadius: 8),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: AppGradients.textSecondary),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: AppGradients.surfaceDark,
                    child: Icon(_fileIcon, color: _iconColor, size: 28),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.fileName,
                    style: const TextStyle(
                        color: AppGradients.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,),
                    overflow: TextOverflow.ellipsis,),
                if (widget.sizeLabel.isNotEmpty)
                  Text(widget.sizeLabel,
                      style: const TextStyle(
                          color: AppGradients.textSecondary, fontSize: 11,),),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, color: Color(0xFF6C63FF), size: 18),
        ],),
      ),
    );
  }

  IconData get _fileIcon {
    if (_isPdf) return Icons.picture_as_pdf;
    if (_isVideo) return Icons.play_circle_filled;
    if (_isAudio) return Icons.audiotrack;
    return Icons.insert_drive_file;
  }

  Color get _iconColor {
    if (_isPdf) return const Color(0xFFEF4444);
    if (_isVideo) return const Color(0xFF10B981);
    if (_isAudio) return const Color(0xFFF59E0B);
    return const Color(0xFF6C63FF);
  }
}
