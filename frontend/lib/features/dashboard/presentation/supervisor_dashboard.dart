import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../projects/data/weekly_status_api.dart';
import '../application/dashboard_controller.dart';
import 'widgets/app_overflow_menu.dart';
import 'widgets/recent_updates_list.dart';

final _needsReviewProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = WeeklyStatusApi();
  return await api.getNeedsReview();
});

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
          const AppOverflowMenu(basePath: '/supervisor'),
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
                        value: (d['reportSubmittedToday'] == true)
                            ? 'Done'
                            : 'Due',
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
                // Needs Review This Week
                Builder(builder: (context) {
                  final needsReview =
                      ref.watch(_needsReviewProvider).valueOrNull ?? [];
                  if (needsReview.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const Text('⚠️ Needs Review This Week',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.sm),
                      for (final p in needsReview.cast<Map<String, dynamic>>())
                        Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFF44336)),
                            title: Text(
                                p['project_name']?.toString() ?? 'Project',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: const Text('No weekly status set',
                                style: TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.go('/supervisor/projects/${p['id']}'),
                          ),
                        ),
                    ],
                  );
                }),
                const Text(
                  "Today's Work",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (todays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'No work planned for today',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  for (final w in todays.cast<Map<String, dynamic>>())
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(w['projectName']?.toString() ?? 'Site'),
                        subtitle: Text(w['task']?.toString() ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context
                            .go('/supervisor/projects/${w['projectId']}'),
                      ),
                    ),
                const SizedBox(height: AppSpacing.lg),
                // Workers assigned to supervisor
                if ((d['workers'] as List?)?.isNotEmpty == true) ...[
                  const Text(
                    'My Workers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final w
                      in (d['workers'] as List).cast<Map<String, dynamic>>())
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surfaceAlt,
                          child: Text(
                            (w['fullName']?.toString() ?? '?')[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          w['fullName']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${w['projectName'] ?? ''}${w['task'] != null ? ' · ${w['task']}' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _workerStatusBadge(w['status']?.toString()),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const Text(
                  'Recent Updates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                RecentUpdatesList(
                    updates: (d['recentUpdates'] as List?) ?? const []),
              ],
            );
          },
        ),
      ),
    );
  }
}

Widget _workerStatusBadge(String? status) {
  final label = switch (status) {
    'at_site' => 'At Site',
    'leave' => 'Leave',
    'holiday' => 'Holiday',
    _ => 'Workshop',
  };
  final color = switch (status) {
    'at_site' => AppColors.success,
    'leave' => AppColors.warning,
    'holiday' => AppColors.info,
    _ => AppColors.textMuted,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}
