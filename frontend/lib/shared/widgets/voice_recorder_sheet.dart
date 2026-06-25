import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Result of a voice recording / audio selection.
class VoiceRecording {
  VoiceRecording(this.bytes, this.filename);
  final List<int> bytes;
  final String filename;
}

/// Voice note helper. Opens a sheet that guides the user to record using their
/// phone's recorder app and attach it, or pick an existing audio file.
///
/// Note: Native in-app recording (the `record` package) is not used because its
/// Linux platform dependency fails to compile in this Flutter toolchain. This
/// picker-based flow is reliable across all Android devices.
class VoiceRecorderSheet {
  /// Opens the audio picker and returns the selected recording, or null.
  static Future<VoiceRecording?> show(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mic, size: 48, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Add a voice note',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Record using your phone\'s voice recorder, then attach it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'pick'),
                icon: const Icon(Icons.audiotrack),
                label: const Text('Select Audio File'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if (action != 'pick') return null;

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'aac',
          'm4a',
          'ogg',
          'opus',
          'amr',
          '3gp'
        ],
        withData: true,
      );
      if (res != null &&
          res.files.isNotEmpty &&
          res.files.first.bytes != null) {
        final f = res.files.first;
        return VoiceRecording(f.bytes!, f.name);
      }
    } catch (_) {
      // Fallback: any file
      try {
        final res = await FilePicker.platform.pickFiles(withData: true);
        if (res != null &&
            res.files.isNotEmpty &&
            res.files.first.bytes != null) {
          final f = res.files.first;
          return VoiceRecording(f.bytes!, f.name);
        }
      } catch (_) {}
    }
    return null;
  }
}
