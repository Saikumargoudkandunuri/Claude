import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/application/auth_controller.dart';
import '../application/dashboard_controller.dart';
import 'widgets/recent_updates_list.dart';

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
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
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
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.92,
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
                  ),
                  StatCard(
                    label: 'Completed',
                    value: '${d['completedSites'] ?? 0}',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  StatCard(
                    label: 'Workers Today',
                    value: '${d['workersToday'] ?? 0}',
                    icon: Icons.engineering_outlined,
                  ),
                  StatCard(
                    label: 'Pending Reports',
                    value: '${d['pendingReports'] ?? 0}',
                    icon: Icons.assignment_late_outlined,
                    color: AppColors.warning,
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
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Recent Updates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
              const SizedBox(height: AppSpacing.sm),
              RecentUpdatesList(updates: (d['recentUpdates'] as List?) ?? const []),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({
    required this.received,
    required this.outstanding,
    required this.pending,
  });

  final num received;
  final num outstanding;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
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
        Text(value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),),
      ],
    );
  }
}
