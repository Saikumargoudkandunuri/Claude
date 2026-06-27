import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/customer_providers.dart';

const _brandTeal = Color(0xFF00D1DC);

/// Displays admin announcements for the customer, ordered newest first.
///
/// Each message shows title, body preview (max 2 lines), and created_at date.
/// Tapping a message expands it to reveal the full body text.
/// Shows a friendly empty state when no messages exist.
class CustomerMessagesScreen extends ConsumerWidget {
  const CustomerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(customerMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
      ),
      body: messagesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _brandTeal),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text(
                  'Failed to load messages',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(customerMessagesProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (messages) {
          if (messages.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            color: _brandTeal,
            onRefresh: () async => ref.invalidate(customerMessagesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final msg = messages[index] as Map<String, dynamic>;
                return _MessageCard(
                  title: msg['title'] as String? ?? '',
                  body: msg['body'] as String? ?? '',
                  createdAt: msg['created_at'] as String? ?? '',
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single message card that expands on tap to reveal the full body.
class _MessageCard extends StatefulWidget {
  const _MessageCard({
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String title;
  final String body;
  final String createdAt;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _brandTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: _brandTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedCrossFade(
                firstChild: Text(
                  widget.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                secondChild: Text(
                  widget.body,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats an ISO 8601 date string into a readable format (e.g. "Mar 15, 2024").
  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);

      // Show relative time for recent messages
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      // Otherwise show formatted date
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
