import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/dashboard_controller.dart';

/// Intentionally simple home for workers: today's work, sites, drawings, report.
class WorkerDashboard extends ConsumerWidget {
  const WorkerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final async = ref.watch(dashboardProvider('worker'));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.fullName.split(' ').first ?? 'there'}'),
        actions: [
          _StatusMenu(current: user?.workerStatus ?? 'workshop'),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.go('/worker/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider('worker')),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(dashboardProvider('worker')),
          ),
          data: (d) {
            final todays = (d['todaysWork'] as List?) ?? const [];
            final assigned = (d['assignedSites'] as List?) ?? const [];
            final reportDue = d['reportDueToday'] == true;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (reportDue)
                  Card(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    child: ListTile(
                      leading: const Icon(Icons.assignment_late_outlined,
                          color: AppColors.warning,),
                      title: const Text('End-of-day report due'),
                      subtitle: const Text('Submit before you leave the site'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/worker/reports'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const Text("Today's Work",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),),
                const SizedBox(height: AppSpacing.sm),
                if (todays.isEmpty)
                  const EmptyState(
                    message: 'No work assigned for today',
                    icon: Icons.event_available_outlined,
                  )
                else
                  for (final w in todays.cast<Map<String, dynamic>>())
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(w['projectName']?.toString() ?? 'Site',
                            style: const TextStyle(fontWeight: FontWeight.w700),),
                        subtitle: Text(w['task']?.toString() ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.go('/worker/sites/${w['projectId']}'),
                      ),
                    ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Assigned Sites',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
                const SizedBox(height: AppSpacing.sm),
                for (final s in assigned.cast<Map<String, dynamic>>())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary,),
                    title: Text(s['projectName']?.toString() ?? ''),
                    subtitle: Text(
                      '${s['task'] ?? ''} · ${Formatters.stageLabel(s['currentStage'] as String?)}',
                    ),
                    onTap: () => context.go('/worker/sites/${s['id']}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusMenu extends ConsumerWidget {
  const _StatusMenu({required this.current});
  final String current;

  static const _options = {
    'workshop': 'Workshop',
    'at_site': 'At Site',
    'leave': 'Leave',
    'holiday': 'Holiday',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Set status',
      onSelected: (v) =>
          ref.read(authControllerProvider.notifier).updateWorkerStatus(v),
      itemBuilder: (_) => [
        for (final e in _options.entries)
          PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 10, color: AppColors.success),
            const SizedBox(width: 4),
            Text(_options[current] ?? 'Status',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
