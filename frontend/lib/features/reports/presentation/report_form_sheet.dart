import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/reports_controller.dart';

/// A media file queued for upload after the report is saved.
class _PendingMedia {
  _PendingMedia(this.category, this.name, this.bytes);
  final String category; // photo | video | voice_note
  final String name;
  final List<int> bytes;
}

/// End-of-day report form for workers and supervisors.
/// Captures text fields, progress %, and queued media (image/video/voice/file).
Future<void> showReportForm(
  BuildContext context,
  WidgetRef ref,
  String projectId,
  String role,
) {
  final isSupervisor = role == 'supervisor';
  final workDone = TextEditingController();
  final pending = TextEditingController();
  final problems = TextEditingController();
  final materialsUsed = TextEditingController();
  final materialsNeeded = TextEditingController();
  final tomorrow = TextEditingController();
  final siteProgress = TextEditingController();
  double progress = 0;
  final media = <_PendingMedia>[];
  bool submitting = false;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> pick(String category, FileType type,
              {List<String>? ext}) async {
            try {
              final res = await FilePicker.platform.pickFiles(
                type: type,
                allowedExtensions: ext,
                withData: true,
              );
              if (res == null || res.files.isEmpty) return;
              final f = res.files.first;
              if (f.bytes == null) return;
              setState(() => media.add(_PendingMedia(category, f.name, f.bytes!)));
            } catch (_) {
              // Fixes file-attachment error on some devices.
            }
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isSupervisor ? 'Supervisor Daily Report' : 'End-of-Day Report',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Progress %
                Row(
                  children: [
                    const Text('Progress', style: TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Slider(
                        value: progress,
                        max: 100,
                        divisions: 20,
                        activeColor: AppColors.primary,
                        label: '${progress.round()}%',
                        onChanged: (v) => setState(() => progress = v),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('${progress.round()}%',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),

                _field("Today's work done", workDone),
                if (isSupervisor) _field('Site progress notes', siteProgress),
                _field('Pending work', pending),
                _field('Issues faced', problems),
                _field('Materials used', materialsUsed),
                _field('Materials needed', materialsNeeded),
                _field("Tomorrow's plan", tomorrow),

                const SizedBox(height: AppSpacing.sm),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Attachments',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => pick('photo', FileType.image),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => pick('video', FileType.video),
                      icon: const Icon(Icons.videocam_outlined, size: 18),
                      label: const Text('Video'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => pick('voice_note', FileType.audio),
                      icon: const Icon(Icons.mic_none, size: 18),
                      label: const Text('Voice'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => pick('photo', FileType.any),
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('File'),
                    ),
                  ],
                ),
                if (media.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ...media.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(_iconFor(e.value.category),
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(e.value.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => media.removeAt(e.key)),
                            ),
                          ],
                        ),
                      )),
                ],

                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setState(() => submitting = true);
                          try {
                            final report = await ref
                                .read(reportsRepositoryProvider)
                                .submit(projectId, {
                              'type': isSupervisor ? 'supervisor' : 'worker',
                              'workDone': workDone.text,
                              'pendingWork': pending.text,
                              'problems': problems.text,
                              'materialsUsed': materialsUsed.text,
                              'materialsNeeded': materialsNeeded.text,
                              'tomorrowNotes': tomorrow.text,
                              'progressPercent': progress.round(),
                              if (isSupervisor) 'siteProgress': siteProgress.text,
                            });
                            final reportId = report['id'] as String;
                            for (final m in media) {
                              await ref.read(reportsRepositoryProvider).addMedia(
                                    reportId: reportId,
                                    category: m.category,
                                    bytes: m.bytes,
                                    filename: m.name,
                                  );
                            }
                            ref.invalidate(projectReportsProvider(projectId));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Report submitted')),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content:
                                        Text(DioClient.toApiException(e).message)),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setState(() => submitting = false);
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Report'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    ),
  );
}

IconData _iconFor(String category) {
  switch (category) {
    case 'video':
      return Icons.videocam_outlined;
    case 'voice_note':
      return Icons.mic_none;
    default:
      return Icons.image_outlined;
  }
}

Widget _field(String label, TextEditingController c) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      controller: c,
      maxLines: 2,
      minLines: 1,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
