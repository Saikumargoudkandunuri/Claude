import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/customer_providers.dart';
import '../theme/customer_theme.dart';

/// Displays admin announcements for the customer, ordered newest first.
///
/// Each card shows an avatar circle, sender name, time, and message.
/// Unread messages have a teal tint background + teal border.
class CustomerMessagesScreen extends ConsumerWidget {
  const CustomerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(customerMessagesProvider);

    return Scaffold(
      backgroundColor: CTheme.bgSoft,
      appBar: AppBar(
        title: const Text(
          'Project Updates',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: CTheme.textDark,
          ),
        ),
        backgroundColor: CTheme.bgWhite,
        foregroundColor: CTheme.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: messagesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CTheme.primary),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(CTheme.p24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(height: CTheme.p12),
                const Text(
                  'Failed to load updates',
                  style: TextStyle(
                    fontSize: 16,
                    color: CTheme.textMid,
                  ),
                ),
                const SizedBox(height: CTheme.p16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(customerMessagesProvider),
                  icon: const Icon(Icons.refresh, color: CTheme.primary),
                  label: const Text(
                    'Retry',
                    style: TextStyle(color: CTheme.primary),
                  ),
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
            color: CTheme.primary,
            onRefresh: () async => ref.invalidate(customerMessagesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(CTheme.p16),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: CTheme.p12),
              itemBuilder: (context, index) {
                final msg = messages[index] as Map<String, dynamic>;
                return _MessageCard(
                  title: msg['title'] as String? ?? '',
                  body: msg['body'] as String? ?? '',
                  createdAt: msg['created_at'] as String? ?? '',
                  isRead: msg['is_read'] == true,
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
            Icons.campaign_outlined,
            size: 64,
            color: CTheme.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: CTheme.p16),
          const Text(
            'No updates yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CTheme.textMid,
            ),
          ),
          const SizedBox(height: CTheme.p8),
          const Text(
            'Project updates will appear here',
            style: TextStyle(fontSize: 13, color: CTheme.textLight),
          ),
        ],
      ),
    );
  }
}

/// A single update card with avatar, sender, time, and message text.
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  final String title;
  final String body;
  final String createdAt;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CTheme.p16),
      decoration: BoxDecoration(
        color: isRead ? CTheme.bgWhite : CTheme.primary.withValues(alpha: 0.04),
        borderRadius: CTheme.r16,
        boxShadow: CTheme.cardShadow,
        border: Border.all(
          color:
              isRead ? CTheme.inactive : CTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar circle
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: CTheme.heroGradient,
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CTheme.bgWhite,
                ),
              ),
            ),
          ),
          const SizedBox(width: CTheme.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Metal & More',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CTheme.textDark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimeAgo(createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: CTheme.textLight,
                      ),
                    ),
                  ],
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: CTheme.p4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: CTheme.p4),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CTheme.textMid,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

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
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return isoDate;
    }
  }
}
