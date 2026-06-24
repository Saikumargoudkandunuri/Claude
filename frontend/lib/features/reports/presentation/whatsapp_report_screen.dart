import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../auth/application/auth_controller.dart';
import '../application/reports_controller.dart';

/// WhatsApp Business-style chat for project reports.
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
  final _attachments = <_MediaAttachment>[];
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
      // WhatsApp Business light background
      backgroundColor: const Color(0xFFECE5DD),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: ShimmerLoader(count: 5, height: 60)),
              error: (e, _) => Center(
                child: Text(e.toString(),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
              data: (reports) {
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No updates yet.\nSend the first site update.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: reports.length,
                  itemBuilder: (_, i) {
                    final r = reports[i];
                    final isMe = r['authorId'] == userId;
                    return _Bubble(report: r, isMe: isMe);
                  },
                );
              },
            ),
          ),
          // Attachment preview
          if (_attachments.isNotEmpty)
            Container(
              color: Colors.white,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < _attachments.length; i++)
                    Padding(
                      padding:
                          const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                      child: Chip(
                        avatar:
                            Icon(_iconFor(_attachments[i].category), size: 16),
                        label: Text(_attachments[i].name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                        onDeleted: () =>
                            setState(() => _attachments.removeAt(i)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          // Input bar
          _buildInputBar(role),
        ],
      ),
    );
  }

  Widget _buildInputBar(String role) {
    return Container(
      color: const Color(0xFFF0F2F5),
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 6,
        bottom: 6 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Camera button → opens device camera
          IconButton(
            icon: const Icon(Icons.camera_alt,
                color: Color(0xFF54656F), size: 24),
            onPressed: _sending ? null : _captureCamera,
            tooltip: 'Camera',
          ),
          // Expanded text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attach file
                  IconButton(
                    icon: const Icon(Icons.attach_file,
                        color: Color(0xFF54656F), size: 22),
                    onPressed: _sending ? null : _pickFile,
                    tooltip: 'Attach',
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: Color(0xFF8696A0)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: 5,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Voice / Send button
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Material(
                  color: const Color(0xFF00A884),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (_textCtrl.text.trim().isNotEmpty ||
                          _attachments.isNotEmpty) {
                        _send(role);
                      } else {
                        _recordVoice();
                      }
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      child: Icon(
                        (_textCtrl.text.trim().isNotEmpty ||
                                _attachments.isNotEmpty)
                            ? Icons.send
                            : Icons.mic,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// Open device camera and capture a photo
  Future<void> _captureCamera() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() =>
            _attachments.add(_MediaAttachment('photo', picked.name, bytes)));
      }
    } catch (e) {
      _snack('Camera not available');
    }
  }

  /// Pick files from device
  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (res != null) {
        for (final f in res.files) {
          if (f.bytes != null) {
            final category = _categorize(f.name);
            setState(() =>
                _attachments.add(_MediaAttachment(category, f.name, f.bytes!)));
          }
        }
      }
    } catch (_) {
      _snack('Could not pick file');
    }
  }

  /// Record voice note using ImagePicker (audio source)
  /// Falls back to file picker if not supported
  Future<void> _recordVoice() async {
    try {
      // Try to pick audio file (voice recordings from device recorder)
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
        setState(() => _attachments.add(_MediaAttachment(
            'voice_note', res.files.first.name, res.files.first.bytes!)));
      }
    } catch (_) {
      _snack(
          'Voice recording not available. Use your phone recorder app and attach the file.');
    }
  }

  String _categorize(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext))
      return 'photo';
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) return 'video';
    if (['mp3', 'wav', 'aac', 'm4a', 'ogg', 'opus', 'amr'].contains(ext))
      return 'voice_note';
    return 'document';
  }

  Future<void> _send(String role) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    setState(() => _sending = true);
    try {
      final type = role == 'supervisor' ? 'supervisor' : 'worker';
      final report = await ref
          .read(reportsRepositoryProvider)
          .submit(widget.projectId, {'type': type, 'workDone': text});
      final reportId = report['id'] as String;
      for (final a in _attachments) {
        await ref.read(reportsRepositoryProvider).addMedia(
              reportId: reportId,
              category: a.category,
              bytes: a.bytes,
              filename: a.name,
            );
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

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'video':
        return Icons.videocam_outlined;
      case 'voice_note':
        return Icons.mic;
      case 'document':
        return Icons.insert_drive_file;
      default:
        return Icons.image;
    }
  }
}

class _MediaAttachment {
  _MediaAttachment(this.category, this.name, this.bytes);
  final String category;
  final String name;
  final List<int> bytes;
}

/// WhatsApp Business-style message bubble
class _Bubble extends StatelessWidget {
  const _Bubble({required this.report, required this.isMe});
  final Map<String, dynamic> report;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final media =
        (report['media'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final text = report['workDone']?.toString().trim() ?? '';
    final progress = report['progressPercent'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author name for others
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${report['authorName'] ?? ''} · ${Formatters.roleLabel(report['authorRole'] as String?)}',
                  style: const TextStyle(
                    color: Color(0xFF00A884),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Progress
            if (progress != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '📈 $progress% complete',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00A884)),
                ),
              ),
            // Message text
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  text,
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF111B21)),
                ),
              ),
            // Media attachments
            if (media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final m in media)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_attachIcon(m['category'] as String?),
                                size: 14, color: const Color(0xFF54656F)),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                m['originalName']?.toString() ?? 'file',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF54656F)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            // Timestamp
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  Formatters.dateTime(report['createdAt']),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF667781)),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.done_all,
                      size: 14, color: Color(0xFF53BDEB)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _attachIcon(String? category) {
    switch (category) {
      case 'video':
        return Icons.videocam;
      case 'voice_note':
        return Icons.mic;
      case 'photo':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
}
