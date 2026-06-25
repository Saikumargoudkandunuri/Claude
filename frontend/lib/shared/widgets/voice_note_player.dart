import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/config/env.dart';
import '../../core/storage/secure_store.dart';

/// WhatsApp-style voice note player widget with play/pause, seek bar, duration.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.url,
    this.fileName,
    this.isMe = false,
  });

  final String url;
  final String? fileName;
  final bool isMe;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAndPlay() async {
    if (_hasError) return;
    setState(() => _isLoading = true);
    try {
      // Build full URL with auth header
      String resolvedUrl = widget.url;
      if (!resolvedUrl.startsWith('http')) {
        resolvedUrl = '${Env.apiBaseUrl}${widget.url}';
      }
      // Rewrite localhost/private IPs to configured API base
      if (resolvedUrl.contains('localhost') ||
          resolvedUrl.contains('127.0.0.1') ||
          resolvedUrl.contains('10.0.2.2')) {
        final uri = Uri.parse(resolvedUrl);
        final apiUri = Uri.parse(Env.apiBaseUrl);
        resolvedUrl = uri
            .replace(
                scheme: apiUri.scheme, host: apiUri.host, port: apiUri.port)
            .toString();
      }
      final token = await SecureStore.instance.accessToken;

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(resolvedUrl),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      await _player.play();
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _player.pause();
    } else if (_duration > Duration.zero) {
      _player.play();
    } else {
      _loadAndPlay();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe ? const Color(0xFFC8E6C9) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _isLoading
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : GestureDetector(
                  onTap: _hasError ? null : _togglePlay,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError ? Colors.grey : const Color(0xFF00A884),
                    ),
                    child: Icon(
                      _hasError
                          ? Icons.error_outline
                          : _isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
          const SizedBox(width: 8),
          // Waveform / progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: const Color(0xFF00A884),
                    inactiveTrackColor: Colors.grey.shade400,
                    thumbColor: const Color(0xFF00A884),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      if (_duration > Duration.zero) {
                        final pos = Duration(
                            milliseconds:
                                (v * _duration.inMilliseconds).round());
                        _player.seek(pos);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _duration > Duration.zero
                        ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                        : '🎤 Voice note',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
