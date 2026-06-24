import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/design/app_gradients.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../application/reports_controller.dart';

/// BUG-04/05: WhatsApp-style chat for project reports.
/// The stage button is NOT here — it lives on the Overview tab.
class WhatsAppReportScreen extends ConsumerStatefulWidget {
  const WhatsAppReportScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<WhatsAppReportScreen> createState() =>
      _WhatsAppReportScreenState();
}

class _WhatsAppReportScreenState extends ConsumerState<WhatsAppReportScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _attachments = <XFile>[];
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectReportsProvider(widget.projectId));
    final userId = ref.watch(authControllerProvider).user?.id;
    final role = ref.watch(authControllerProvider).user?.role ?? 'worker';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Message list
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: ShimmerLoader(count: 5, height: 60)),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: AppGradients.textSecondary),
                ),
              ),
              data: (reports) {
                if (reports.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No updates yet.\nSend the first site update.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppGradients.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: reports.length,
                  itemBuilder: (_, i) {
                    final r = reports[i];
                    final isMe = r['authorId'] == userId;
                    final isBrief = r['isAssignmentBrief'] == true;
                    return _Bubble(report: r, isMe: isMe, isBrief: isBrief);
                  },
                );
              },
            ),
          ),
          // Input bar
          _InputBar(
            textCtrl: _textCtrl,
            attachments: _attachments,
            sending: _sending,
            onSend: () => _send(role),
            onPickImage: _pickImage,
            onPickFile: _pickFile,
            onPickVoice: _pickVoice,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty) setState(() => _attachments.addAll(picked));
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform
          .pickFiles(allowMultiple: true, withData: true);
      if (res != null) {
        setState(
          () => _attachments.addAll(
            res.files.where((f) => f.bytes != null).map((f) => XFile(f.name)),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _pickVoice() async {
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
      if (res != null && res.files.isNotEmpty) {
        setState(
          () => _attachments.addAll(
            res.files.where((f) => f.bytes != null).map((f) => XFile(f.name)),
          ),
        );
      }
    } catch (_) {
      // If custom type fails, try with any type as fallback
      try {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
        if (res != null && res.files.isNotEmpty) {
          setState(
            () => _attachments.addAll(
              res.files.where((f) => f.bytes != null).map((f) => XFile(f.name)),
            ),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _send(String role) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    setState(() => _sending = true);
    try {
      final type = role == 'supervisor'
          ? 'supervisor'
          : role == 'designer'
              ? 'designer'
              : 'worker';
      final report = await ref
          .read(reportsRepositoryProvider)
          .submit(widget.projectId, {'type': type, 'workDone': text});
      final reportId = report['id'] as String;
      for (final a in _attachments) {
        if (a.path.isNotEmpty) {
          final bytes = await a.readAsBytes();
          await ref.read(reportsRepositoryProvider).addMedia(
                reportId: reportId,
                category: 'photo',
                bytes: bytes,
                filename: a.name,
              );
        }
      }
      _textCtrl.clear();
      setState(() => _attachments.clear());
      ref.invalidate(projectReportsProvider(widget.projectId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.textCtrl,
    required this.attachments,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
    required this.onPickFile,
    this.onPickVoice,
  });

  final TextEditingController textCtrl;
  final List<XFile> attachments;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback? onPickVoice;

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(
            top: BorderSide(color: Color(0xFF334155)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file,
                    color: Color(0xFF6C63FF), size: 22),
                onPressed: onPickFile,
                tooltip: 'Attach file',
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt,
                    color: Color(0xFF6C63FF), size: 22),
                onPressed: onPickImage,
                tooltip: 'Photo',
              ),
              IconButton(
                icon: const Icon(Icons.mic, color: Color(0xFF10B981), size: 22),
                onPressed: onPickVoice,
                tooltip: 'Voice note',
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: textCtrl,
                    style:
                        const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF6C63FF)),
                      ),
                    )
                  : GestureDetector(
                      onTap: onSend,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(Icons.send,
                            color: Colors.white, size: 20),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.report,
    required this.isMe,
    required this.isBrief,
  });

  final Map<String, dynamic> report;
  final bool isMe;
  final bool isBrief;

  @override
  Widget build(BuildContext context) {
    final media =
        (report['media'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final text = report['workDone']?.toString().trim() ?? '';
    final progress = report['progressPercent'];

    if (isBrief) {
      return _BriefCard(report: report);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isMe
                ? const [Color(0xFF6C63FF), Color(0xFF3B82F6)]
                : const [Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: (isMe ? const Color(0xFF6C63FF) : const Color(0xFF334155))
                  .withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${report['authorName'] ?? ''} · ${Formatters.roleLabel(report['authorRole'] as String?)}',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 13,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppGradients.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            if (text.isNotEmpty)
              Text(
                text,
                style: const TextStyle(
                  color: AppGradients.textPrimary,
                  fontSize: 14,
                ),
              ),
            if (media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final m in media)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppGradients.surfaceDark.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.attach_file,
                              size: 12,
                              color: AppGradients.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                m['originalName']?.toString() ?? 'file',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppGradients.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatters.dateTime(report['createdAt']),
                  style: const TextStyle(
                    color: AppGradients.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 12,
                    color: (report['readBy'] as List?)?.isNotEmpty == true
                        ? const Color(0xFF6C63FF)
                        : AppGradients.textSecondary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Assignment brief highlighted card (visible only on valid day for workers).
class _BriefCard extends StatelessWidget {
  const _BriefCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.15),
            const Color(0xFF3B82F6).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.assignment, color: Colors.white, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "TODAY'S ASSIGNMENT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                StatusBadge(
                  label: 'Brief',
                  gradient: AppGradients.primary,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              report['workDone']?.toString() ?? '',
              style: const TextStyle(
                color: AppGradients.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
