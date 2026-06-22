import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/reports_controller.dart';
import 'report_form_sheet.dart';

class _Attachment {
  _Attachment(this.category, this.name, this.bytes);
  final String category; // photo | video | voice_note | document
  final String name;
  final List<int> bytes;
}

/// WhatsApp-style report timeline: message bubbles + a simple composer with
/// text, image, video, file and voice attachments. Built for non-technical users.
class ReportChatView extends ConsumerStatefulWidget {
  const ReportChatView({super.key, required this.projectId, this.canCompose = true});

  final String projectId;
  final bool canCompose;

  @override
  ConsumerState<ReportChatView> createState() => _ReportChatViewState();
}

class _ReportChatViewState extends ConsumerState<ReportChatView> {
  final _text = TextEditingController();
  final _attachments = <_Attachment>[];
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(String category, FileType type) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: type, withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      if (f.bytes == null) {
        _snack('Could not read the selected file');
        return;
      }
      setState(() => _attachments.add(_Attachment(category, f.name, f.bytes!)));
    } catch (e) {
      // Fixes the previous file-attachment crash: never throw to the UI.
      _snack('Attachment not supported on this device');
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _send(String role) async {
    final text = _text.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    setState(() => _sending = true);
    try {
      final report = await ref.read(reportsRepositoryProvider).submit(widget.projectId, {
        'type': role == 'supervisor' ? 'supervisor' : 'worker',
        'workDone': text.isEmpty ? null : text,
      });
      final reportId = report['id'] as String;
      for (final a in _attachments) {
        await ref.read(reportsRepositoryProvider).addMedia(
              reportId: reportId,
              category: a.category,
              bytes: a.bytes,
              filename: a.name,
            );
      }
      _text.clear();
      setState(() => _attachments.clear());
      ref.invalidate(projectReportsProvider(widget.projectId));
    } catch (e) {
      _snack(DioClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectReportsProvider(widget.projectId));
    final user = ref.watch(authControllerProvider).user;
    final role = user?.role ?? 'worker';

    return Column(
      children: [
        Expanded(
          child: async.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(projectReportsProvider(widget.projectId)),
            ),
            data: (reports) {
              if (reports.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'No updates yet.\nSend the first site update below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              // reports come newest-first; reverse:true keeps newest at bottom.
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: reports.length,
                itemBuilder: (_, i) {
                  final r = reports[i];
                  final isMine = r['authorId'] == user?.id;
                  return _Bubble(report: r, isMine: isMine);
                },
              );
            },
          ),
        ),
        if (widget.canCompose) _composer(role),
      ],
    );
  }

  Widget _composer(String role) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < _attachments.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Chip(
                          avatar: Icon(_iconFor(_attachments[i].category), size: 16),
                          label: Text(
                            _attachments[i].name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () => setState(() => _attachments.removeAt(i)),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  tooltip: 'Attach',
                  onPressed: _sending ? null : () => _showAttachMenu(role),
                ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Type an update...',
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: () => _send(role),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachMenu(String role) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.primary),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick('photo', FileType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(ctx);
                _pick('video', FileType.video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none, color: AppColors.primary),
              title: const Text('Voice / Audio'),
              onTap: () {
                Navigator.pop(ctx);
                _pick('voice_note', FileType.audio);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: AppColors.primary),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(ctx);
                _pick('document', FileType.any);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined, color: AppColors.primary),
              title: const Text('Detailed report (progress, materials...)'),
              onTap: () {
                Navigator.pop(ctx);
                showReportForm(context, ref, widget.projectId, role);
              },
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String category) {
    switch (category) {
      case 'video':
        return Icons.videocam_outlined;
      case 'voice_note':
        return Icons.mic_none;
      case 'document':
        return Icons.insert_drive_file_outlined;
      default:
        return Icons.image_outlined;
    }
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.report, required this.isMine});
  final Map<String, dynamic> report;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final media = (report['media'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final lines = <String>[];
    void add(String label, dynamic v) {
      if (v != null && v.toString().trim().isNotEmpty) lines.add('$label: $v');
    }

    final main = report['workDone']?.toString().trim();
    final progress = report['progressPercent'];
    add('Pending', report['pendingWork']);
    add('Issues', report['problems']);
    add('Materials used', report['materialsUsed']);
    add('Materials needed', report['materialsNeeded']);
    add('Site progress', report['siteProgress']);
    add('Tomorrow', report['tomorrowNotes']);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 14),
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${report['authorName'] ?? 'User'} · ${Formatters.roleLabel(report['authorRole'] as String?)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark),
                ),
              ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('Progress $progress%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            if (main != null && main.isNotEmpty)
              Text(main, style: const TextStyle(fontSize: 14.5)),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l, style: const TextStyle(fontSize: 13)),
              ),
            if (media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final m in media)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_ReportChatViewState._iconFor(
                                m['category'] as String? ?? 'document'),
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                m['originalName']?.toString() ?? 'file',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Formatters.dateTime(report['createdAt']),
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
