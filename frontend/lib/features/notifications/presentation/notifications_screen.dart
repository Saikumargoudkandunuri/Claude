import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                      _iconForType(n['type'] as String?),
                      color: isRead ? AppColors.textMuted : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    n['title']?.toString() ?? '',
                    style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${n['body'] ?? ''}\n${Formatters.dateTime(n['createdAt'])}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    if (!isRead) {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .markRead(n['id'] as String);
                      ref.invalidate(notificationsProvider);
                    }
                    if (!context.mounted) return;
                    _navigate(context, n);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Navigate to the related entity (project, report, payment, user).
  void _navigate(BuildContext context, Map<String, dynamic> notification) {
    // Try the deep-link route from notification data payload first.
    final data = notification['data'] as Map<String, dynamic>?;
    final route = data?['route']?.toString();
    final projectId = notification['projectId'] as String?;

    if (route != null && route.startsWith('icms://')) {
      // Convert icms://project/<id> → /<role>/projects/<id> (role-aware).
      final parts = route.replaceFirst('icms://', '').split('/');
      if (parts.isNotEmpty) {
        final entity = parts[0]; // project, approvals, etc.
        final id = parts.length > 1 ? parts[1] : null;
        final currentLoc = GoRouterState.of(context).uri.toString();
        final rolePrefix = _extractRolePrefix(currentLoc);

        switch (entity) {
          case 'project':
            if (id != null) {
              context.push('$rolePrefix/projects/$id');
              return;
            }
            break;
          case 'approvals':
            context.go('/admin/approvals');
            return;
          case 'home':
            return; // already on home
        }
      }
    }

    // Fallback: if we have a projectId, navigate to its detail.
    if (projectId != null) {
      final currentLoc = GoRouterState.of(context).uri.toString();
      final rolePrefix = _extractRolePrefix(currentLoc);
      context.push('$rolePrefix/projects/$projectId');
    }
  }

  String _extractRolePrefix(String location) {
    if (location.startsWith('/admin')) return '/admin';
    if (location.startsWith('/supervisor')) return '/supervisor';
    if (location.startsWith('/designer')) return '/designer';
    if (location.startsWith('/worker')) return '/worker';
    return '/admin'; // default
  }

  static IconData _iconForType(String? type) {
    switch (type) {
      case 'project.created':
      case 'project.stage':
        return Icons.home_work_outlined;
      case 'report.submitted':
        return Icons.assignment_outlined;
      case 'payment.updated':
        return Icons.payments_outlined;
      case 'drawing.uploaded':
      case 'drawing.replaced':
      case 'design3d.uploaded':
        return Icons.brush_outlined;
      case 'worker.assigned':
      case 'workplan.assigned':
        return Icons.group_add_outlined;
      case 'work.completed':
        return Icons.check_circle_outline;
      case 'user.registration':
      case 'user.approved':
        return Icons.person_add_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
