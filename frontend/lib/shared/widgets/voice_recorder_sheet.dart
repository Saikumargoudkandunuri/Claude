import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Result of a voice recording.
class VoiceRecording {
  VoiceRecording(this.bytes, this.filename, this.durationSeconds);
  final List<int> bytes;
  final String filename;
  final int durationSeconds;
}

/// WhatsApp-style in-app voice recorder bottom sheet.
/// Records audio directly inside the app — no external app opens.
class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});

  static Future<VoiceRecording?> show(BuildContext context) {
    return showModalBottomSheet<VoiceRecording>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const VoiceRecorderSheet(),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  Timer? _timer;
  int _seconds = 0;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isInitializing = true;
  String? _filePath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _isInitializing = false;
        _error = 'Microphone permission denied. Please enable it in Settings.';
      });
      return;
    }

    try {
      await _recorder.openRecorder();
      // Start recording immediately
      await _startRecording();
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _error = 'Could not start recorder: $e';
      });
    }
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    _filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(
      toFile: _filePath,
      codec: Codec.aacADTS,
    );

    setState(() {
      _isInitializing = false;
      _isRecording = true;
      _isPaused = false;
      _seconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() => _seconds++);
      }
    });
  }

  Future<void> _pauseRecording() async {
    await _recorder.pauseRecorder();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _recorder.resumeRecorder();
    setState(() => _isPaused = false);
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    try {
      if (_isRecording) await _recorder.stopRecorder();
      await _recorder.closeRecorder();
    } catch (_) {}
    // Delete temp file
    if (_filePath != null) {
      try {
        await File(_filePath!).delete();
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _send() async {
    _timer?.cancel();
    try {
      await _recorder.stopRecorder();
      await _recorder.closeRecorder();
    } catch (_) {}

    if (_filePath == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final file = File(_filePath!);
    if (!await file.exists()) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final bytes = await file.readAsBytes();
    final filename = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.aac';

    if (mounted) {
      Navigator.pop(context, VoiceRecording(bytes, filename, _seconds));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _recorder.closeRecorder();
    } catch (_) {}
    super.dispose();
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewPadding.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            const Icon(Icons.mic_off, size: 56, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ] else if (_isInitializing) ...[
            const SizedBox(height: AppSpacing.lg),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            const Text('Starting microphone...'),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            // Recording indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isPaused
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : AppColors.danger.withValues(alpha: 0.15),
              ),
              child: Icon(
                _isPaused ? Icons.pause : Icons.mic,
                size: 40,
                color: _isPaused ? AppColors.warning : AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Timer
            Text(
              _timeLabel,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isPaused ? 'Paused' : 'Recording...',
              style: TextStyle(
                color: _isPaused ? AppColors.warning : AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel
                _ControlButton(
                  icon: Icons.delete_outline,
                  label: 'Cancel',
                  color: AppColors.danger,
                  onTap: _cancel,
                ),
                // Pause/Resume
                _ControlButton(
                  icon: _isPaused ? Icons.play_arrow : Icons.pause,
                  label: _isPaused ? 'Resume' : 'Pause',
                  color: AppColors.warning,
                  onTap: _isPaused ? _resumeRecording : _pauseRecording,
                ),
                // Send
                _ControlButton(
                  icon: Icons.send,
                  label: 'Send',
                  color: const Color(0xFF00A884),
                  onTap: _seconds > 0 ? _send : null,
                  filled: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? color : color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: filled ? Colors.white : color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
