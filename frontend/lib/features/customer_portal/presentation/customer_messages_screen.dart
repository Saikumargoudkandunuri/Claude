import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../application/customer_providers.dart';
import '../theme/portal_theme.dart';

/// "Project Journal" — daily updates from the team, shown as premium cards.
/// Text updates and voice updates (with an animated waveform + playback) are
/// rendered distinctly. Data fetching (customerMessagesProvider) preserved.
class CustomerMessagesScreen extends ConsumerWidget {
  const CustomerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(customerMessagesProvider);

    return Scaffold(
      backgroundColor: PortalColors.neutral,
      appBar: AppBar(
        title: Text('Project Journal', style: PortalText.heading(size: 20)),
        backgroundColor: PortalColors.cardBg,
        foregroundColor: PortalColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: messagesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: PortalColors.primary),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load updates',
                  style: PortalText.body(color: PortalColors.textSoft),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(customerMessagesProvider),
                  icon: const Icon(Icons.refresh, color: PortalColors.primary),
                  label: Text(
                    'Retry',
                    style: PortalText.body(color: PortalColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (messages) {
          if (messages.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: PortalColors.primary,
            onRefresh: () async => ref.invalidate(customerMessagesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final msg = messages[index] as Map<String, dynamic>;
                final audioUrl = (msg['voice_url'] ??
                        msg['audio_url'] ??
                        msg['voice'] ??
                        msg['audio'])
                    ?.toString();

                if (audioUrl != null && audioUrl.isNotEmpty) {
                  return _VoiceCard(
                    id: '${msg['id'] ?? index}',
                    sender:
                        (msg['sender_name'] ?? 'Your Supervisor').toString(),
                    audioUrl: audioUrl,
                    createdAt: msg['created_at']?.toString() ?? '',
                  );
                }

                return _TextCard(
                  title: msg['title']?.toString() ?? '',
                  body: (msg['body'] ?? msg['message'] ?? '').toString(),
                  createdAt: msg['created_at']?.toString() ?? '',
                  type: (msg['type'] ?? '').toString(),
                  isRead: msg['is_read'] == true,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _formatTimeAgo(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    // Parse the UTC timestamp from the backend and convert to local time so
    // both the difference calculation and the fallback format are correct.
    final dt = DateTime.parse(isoDate).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  } catch (_) {
    return isoDate;
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    required this.isRead,
  });

  final String title;
  final String body;
  final String createdAt;
  final String type;
  final bool isRead;

  ({String label, Color color}) _typePill() {
    final t = type.toLowerCase();
    if (t.contains('milestone')) {
      return (label: 'Milestone', color: PortalColors.primary);
    }
    if (t.contains('photo')) {
      return (label: 'Photo', color: const Color(0xFF3B82F6));
    }
    if (t.contains('daily')) {
      return (label: 'Daily', color: PortalColors.success);
    }
    return (label: 'Update', color: PortalColors.textSoft);
  }

  @override
  Widget build(BuildContext context) {
    final pill = _typePill();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? PortalColors.cardBg : const Color(0xFFF0FFFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? PortalColors.border
              : PortalColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _BrandAvatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metal & More Interiors',
                      style: PortalText.body(size: 13)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _formatTimeAgo(createdAt),
                      style: PortalText.caption(size: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pill.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pill.label,
                  style: PortalText.caption(size: 11, color: pill.color),
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              title,
              style: PortalText.body(size: 14)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: PortalText.body(size: 14)),
          ],
        ],
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: PortalColors.heroGradient,
      ),
      child: Center(
        child: Text(
          'M',
          style: PortalText.body(size: 16, color: Colors.white)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice update card
// ---------------------------------------------------------------------------

class _VoiceCard extends StatefulWidget {
  const _VoiceCard({
    required this.id,
    required this.sender,
    required this.audioUrl,
    required this.createdAt,
  });

  final String id;
  final String sender;
  final String audioUrl;
  final String createdAt;

  @override
  State<_VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<_VoiceCard> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;
  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    _bars = _generateBars(widget.id);
    _init();
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing);
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _total = d);
    });
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.audioUrl);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // leave _ready false → show disabled control
    }
  }

  List<double> _generateBars(String id) {
    var hash = id.hashCode;
    return List.generate(20, (i) {
      hash = 0x1fffffff & (hash * 1103515245 + 12345 + i);
      return 4 + (hash % 21).toDouble(); // 4..24
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_total.inMilliseconds > 0)
        ? _pos.inMilliseconds / _total.inMilliseconds
        : 0.0;
    final playhead = (progress * _bars.length).floor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PortalColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _BrandAvatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sender,
                      style: PortalText.body(size: 13)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Voice update${_total.inSeconds > 0 ? ' · ${_total.inSeconds}s' : ''}',
                      style: PortalText.caption(size: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _ready
                    ? () => _playing ? _player.pause() : _player.play()
                    : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ready ? PortalColors.primary : PortalColors.border,
                  ),
                  child: Icon(
                    _playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_bars.length, (i) {
                final played = i <= playhead;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: _bars[i],
                    decoration: BoxDecoration(
                      color:
                          played ? PortalColors.primary : PortalColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_fmt(_pos)} / ${_fmt(_total)}',
                style: PortalText.caption(size: 11),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(widget.createdAt),
                style: PortalText.caption(size: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: PortalColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your Project Journal',
              style: PortalText.heading(size: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Updates from our team will appear here.',
              style: PortalText.body(size: 14, color: PortalColors.textSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'We share daily progress, photos, and\nvoice updates from your site.',
              style: PortalText.caption(size: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
