import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';

/// The 3-dot menu shown on dashboards: Profile, Assignments, Reports, Payments,
/// Notifications, Settings, Logout — entries shown depend on the role.
class AppOverflowMenu extends ConsumerWidget {
  const AppOverflowMenu({super.key, required this.basePath});

  /// e.g. '/admin', '/supervisor', '/designer', '/worker'
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).user?.role;
    final isAdmin = role == 'admin';
    final isSupervisor = role == 'supervisor';

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            context.push('/profile');
            break;
          case 'workers':
            context.go('$basePath/workers');
            break;
          case 'assignments':
            context.go('$basePath/assignments');
            break;
          case 'tasks':
            context.go('$basePath/tasks');
            break;
          case 'reports':
            if (isAdmin || isSupervisor) {
              context.go('$basePath/all-reports');
            } else if (role == 'worker') {
              context.go('/worker/reports');
            } else {
              context.go('$basePath/projects');
            }
            break;
          case 'payments':
            context.go('/admin/payments');
            break;
          case 'notifications':
            context.go('$basePath/notifications');
            break;
          case 'settings':
            context.push('/settings');
            break;
          case 'logout':
            await ref.read(authControllerProvider.notifier).logout();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Profile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (isAdmin)
          const PopupMenuItem(
            value: 'workers',
            child: ListTile(
              leading: Icon(Icons.engineering_outlined),
              title: Text('Workers'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (isAdmin || isSupervisor)
          const PopupMenuItem(
            value: 'assignments',
            child: ListTile(
              leading: Icon(Icons.group_add_outlined),
              title: Text('Assignments'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (isAdmin || isSupervisor)
          const PopupMenuItem(
            value: 'tasks',
            child: ListTile(
              leading: Icon(Icons.task_alt_outlined),
              title: Text('Worker Tasks'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'reports',
          child: ListTile(
            leading: Icon(Icons.assignment_outlined),
            title: Text('Reports'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (isAdmin)
          const PopupMenuItem(
            value: 'payments',
            child: ListTile(
              leading: Icon(Icons.payments_outlined),
              title: Text('Payments'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'notifications',
          child: ListTile(
            leading: Icon(Icons.notifications_none),
            title: Text('Notifications'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: AppColors.danger),
            title: Text('Logout', style: TextStyle(color: AppColors.danger)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
