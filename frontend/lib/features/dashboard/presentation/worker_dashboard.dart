import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../tasks/application/tasks_controller.dart';
import '../application/dashboard_controller.dart';
import 'widgets/app_overflow_menu.dart';

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
          const AppOverflowMenu(basePath: '/worker'),
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
            final tomorrow = (d['tomorrowWork'] as List?) ?? const [];
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
                          color: AppColors.warning),
                      title: const Text('End-of-day report due'),
                      subtitle: const Text('Submit before you leave the site'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/worker/reports'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const Text("Today's Work",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                if (todays.isEmpty)
                  const EmptyState(
                    message: 'No work assigned for today',
                    icon: Icons.event_available_outlined,
                  )
                else
                  for (final w in todays.cast<Map<String, dynamic>>())
                    _TaskCard(task: w),
                if (tomorrow.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text("Tomorrow's Work",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final w in tomorrow.cast<Map<String, dynamic>>())
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.event_outlined,
                            color: AppColors.info),
                        title: Text(w['projectName']?.toString() ?? 'Site'),
                        subtitle: Text(w['task']?.toString() ?? ''),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('Assigned Sites',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                for (final s in assigned.cast<Map<String, dynamic>>())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                    title: Text(s['projectName']?.toString() ?? ''),
                    subtitle: Text(
                      '${s['task'] ?? ''} · ${Formatters.stageLabel(s['currentStage'] as String?)}',
                      overflow: TextOverflow.ellipsis,
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

class _TaskCard extends ConsumerStatefulWidget {
  const _TaskCard({required this.task});
  final Map<String, dynamic> task;

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(tasksRepositoryProvider)
          .updateStatus(widget.task['id'] as String, status);
      ref.invalidate(dashboardProvider('worker'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.task;
    final status = w['status']?.toString() ?? 'assigned';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(w['projectName']?.toString() ?? 'Site',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if ((w['task']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(w['task'].toString(),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/worker/sites/${w['projectId']}'),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Open'),
                ),
                if (status != 'started' && status != 'completed')
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _setStatus('started'),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                  ),
                if (status != 'completed')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success),
                    onPressed: _busy ? null : () => _setStatus('completed'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Complete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => AppColors.success,
      'started' => AppColors.info,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 10, color: AppColors.success),
            const SizedBox(width: 4),
            Text(_options[current] ?? 'Status',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
