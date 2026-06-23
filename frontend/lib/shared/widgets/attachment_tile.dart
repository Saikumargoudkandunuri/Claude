import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/app_gradients.dart';
import 'shimmer_loader.dart';

/// BUG-06: Tappable file attachment with open/preview support.
/// Image → fullscreen gallery; PDF → Syncfusion; Video → player; Audio → sheet.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.url,
    required this.fileName,
    this.mimeType = '',
    this.sizeLabel = '',
  });

  final String url;
  final String fileName;
  final String mimeType;
  final String sizeLabel;

  bool get _isImage => mimeType.startsWith('image/');
  bool get _isVideo => mimeType.startsWith('video/');
  bool get _isAudio => mimeType.startsWith('audio/');
  bool get _isPdf => mimeType.contains('pdf');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
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
            child: _isImage
                ? CachedNetworkImage(
                    imageUrl: url,
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
                Text(fileName,
                    style: const TextStyle(
                        color: AppGradients.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                if (sizeLabel.isNotEmpty)
                  Text(sizeLabel,
                      style: const TextStyle(
                          color: AppGradients.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, color: Color(0xFF6C63FF), size: 18),
        ]),
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

  void _open(BuildContext context) {
    // For now, open in external app — viewers will be wired in BUG-06 phase 2.
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
