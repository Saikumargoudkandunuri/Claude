import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/responsive_grid.dart';
import '../../../core/widgets/simple_bar_chart.dart';
import '../../../core/widgets/stage_chip.dart';
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

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final async = ref.watch(dashboardProvider('admin'));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.fullName.split(' ').first ?? 'Admin'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.go('/admin/notifications'),
          ),
          const AppOverflowMenu(basePath: '/admin'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.go('/admin/projects/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider('admin')),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(dashboardProvider('admin')),
          ),
          data: (d) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ResponsiveGrid(
                minItemWidth: 150,
                children: [
                  StatCard(
                    label: 'Total Sites',
                    value: '${d['totalSites'] ?? 0}',
                    icon: Icons.home_work_outlined,
                    onTap: () => context.go('/admin/projects'),
                  ),
                  StatCard(
                    label: 'Active',
                    value: '${d['activeSites'] ?? 0}',
                    icon: Icons.bolt_outlined,
                    color: AppColors.info,
                    onTap: () => context.go('/admin/projects'),
                  ),
                  StatCard(
                    label: 'Completed',
                    value: '${d['completedSites'] ?? 0}',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    onTap: () => context.go('/admin/projects'),
                  ),
                  StatCard(
                    label: 'Workers Today',
                    value: '${d['workersToday'] ?? 0}',
                    icon: Icons.engineering_outlined,
                    onTap: () => context.go('/admin/workers'),
                  ),
                  StatCard(
                    label: 'Active Workers',
                    value: '${d['activeWorkers'] ?? 0}',
                    icon: Icons.people_outlined,
                    color: AppColors.success,
                    onTap: () => context.go('/admin/workers'),
                  ),
                  StatCard(
                    label: "Today's Tasks",
                    value: '${d['todaysAssignments'] ?? 0}',
                    icon: Icons.task_alt_outlined,
                    color: AppColors.info,
                    onTap: () => context.go('/admin/tasks'),
                  ),
                  StatCard(
                    label: 'Pending Reports',
                    value: '${d['pendingReports'] ?? 0}',
                    icon: Icons.assignment_late_outlined,
                    color: AppColors.warning,
                    onTap: () => context.go('/admin/all-reports'),
                  ),
                  StatCard(
                    label: 'Approvals',
                    value: '${d['pendingApprovals'] ?? 0}',
                    icon: Icons.how_to_reg_outlined,
                    color: AppColors.warning,
                    onTap: () => context.go('/admin/approvals'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _PaymentsCard(
                received: d['amountReceived'] as num? ?? 0,
                outstanding: d['outstandingAmount'] as num? ?? 0,
                pending: d['pendingPayments'] as int? ?? 0,
                onTap: () => context.go('/admin/payments'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _StageGraph(
                distribution: (d['stageDistribution'] as Map?) ?? const {},
              ),
              const SizedBox(height: AppSpacing.xl),
              // Needs Review This Week section
              Builder(builder: (context) {
                final needsReview =
                    ref.watch(_needsReviewProvider).valueOrNull ?? [];
                if (needsReview.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Card(
                      color: const Color(0xFFE8F5E9),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF4CAF50), size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '✅ All projects reviewed this week',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️ Needs Review This Week',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: needsReview.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final p = needsReview[i] as Map<String, dynamic>;
                          return GestureDetector(
                            onTap: () =>
                                context.go('/admin/projects/${p['id']}'),
                            child: Container(
                              width: 180,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFFF44336), width: 1.5),
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFF44336)
                                    .withValues(alpha: 0.05),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p['project_name']?.toString() ?? 'Project',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('No weekly status set',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFF44336))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: 'Projects',
                actionLabel: 'View all',
                onAction: () => context.go('/admin/projects'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProjectCards(projects: (d['projects'] as List?) ?? const []),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Recent Updates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              RecentUpdatesList(
                updates: (d['recentUpdates'] as List?) ?? const [],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _StageGraph extends StatelessWidget {
  const _StageGraph({required this.distribution});
  final Map distribution;

  @override
  Widget build(BuildContext context) {
    final items = distribution.entries
        .map(
          (e) => BarChartItem(
            Formatters.stageLabel(e.key.toString()),
            (e.value as num?) ?? 0,
            color: AppColors.stageColors[e.key.toString()] ?? AppColors.primary,
          ),
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Projects by Stage',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              const Text(
                'No project data',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              SimpleBarChart(items: items),
          ],
        ),
      ),
    );
  }
}

class _ProjectCards extends StatelessWidget {
  const _ProjectCards({required this.projects});
  final List projects;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Text(
        'No projects yet',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Column(
      children: [
        for (final p in projects.cast<Map<String, dynamic>>())
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              onTap: () => context.go('/admin/projects/${p['id']}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p['customerName']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StageChip(
                          stage: p['currentStage']?.toString() ?? 'discussion',
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p['projectNumber']} · ${p['projectName'] ?? ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Value ${Formatters.currency(p['quotationAmount'] as num?)}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Received ${Formatters.currency(p['totalReceived'] as num?)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({
    required this.received,
    required this.outstanding,
    required this.pending,
    this.onTap,
  });

  final num received;
  final num outstanding;
  final int pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _Money(
                      label: 'Received',
                      value: Formatters.currency(received),
                      color: AppColors.success,
                    ),
                  ),
                  Expanded(
                    child: _Money(
                      label: 'Outstanding',
                      value: Formatters.currency(outstanding),
                      color: AppColors.danger,
                    ),
                  ),
                  Expanded(
                    child: _Money(
                      label: 'Pending',
                      value: '$pending',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
