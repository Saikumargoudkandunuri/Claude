import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                message: 'No notifications yet',
                icon: Icons.notifications_none_rounded,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = items[i];
                final isRead = n['isRead'] == true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead
                        ? AppColors.surfaceAlt
                        : AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.notifications,
                      color: isRead ? AppColors.textMuted : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    n['title']?.toString() ?? '',
                    style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,),
                  ),
                  subtitle: Text(
                    '${n['body'] ?? ''}\n${Formatters.dateTime(n['createdAt'])}',
                  ),
                  isThreeLine: true,
                  onTap: () async {
                    if (!isRead) {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .markRead(n['id'] as String);
                      ref.invalidate(notificationsProvider);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
