import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/application/auth_controller.dart';
import '../application/dashboard_controller.dart';
import 'widgets/recent_updates_list.dart';

class SupervisorDashboard extends ConsumerWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final async = ref.watch(dashboardProvider('supervisor'));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.fullName.split(' ').first ?? 'Supervisor'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.go('/supervisor/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider('supervisor')),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(dashboardProvider('supervisor')),
          ),
          data: (d) {
            final todays = (d['todaysWork'] as List?) ?? const [];
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'My Sites',
                        value: '${d['mySites'] ?? 0}',
                        icon: Icons.home_work_outlined,
                        onTap: () => context.go('/supervisor/projects'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatCard(
                        label: 'My Report Today',
                        value: (d['reportSubmittedToday'] == true) ? 'Done' : 'Due',
                        icon: Icons.assignment_outlined,
                        color: (d['reportSubmittedToday'] == true)
                            ? AppColors.success
                            : AppColors.warning,
                        onTap: () => context.go('/supervisor/reports'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text("Today's Work",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
                const SizedBox(height: AppSpacing.sm),
                if (todays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text('No work planned for today',
                        style: TextStyle(color: AppColors.textSecondary),),
                  )
                else
                  for (final w in todays.cast<Map<String, dynamic>>())
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(w['projectName']?.toString() ?? 'Site'),
                        subtitle: Text(w['task']?.toString() ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.go('/supervisor/projects/${w['projectId']}'),
                      ),
                    ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Recent Updates',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
                RecentUpdatesList(updates: (d['recentUpdates'] as List?) ?? const []),
              ],
            );
          },
        ),
      ),
    );
  }
}
