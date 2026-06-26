import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stat_card.dart';
import '../../payroll/presentation/admin_payroll_screen.dart';
import 'staff_detail_screen.dart';

/// Provider that fetches workforce operations data.
final workforceProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/dashboard/workforce');
  return res.data['data'] as Map<String, dynamic>;
});

/// Workforce Operations Center — replaces the simple workers list.
class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workforceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workforce Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_rounded),
            tooltip: 'Worker Payroll',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminPayrollScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(workforceProvider),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(workforceProvider),
          ),
          data: (data) => _WorkforceBody(data: data),
        ),
      ),
    );
  }
}

class _WorkforceBody extends StatelessWidget {
  const _WorkforceBody({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final staff = (data['staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final projectWorkforce =
        (data['projectWorkforce'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final recentReports =
        (data['recentReports'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // --- Summary Cards ---
        _SummaryCards(summary: summary),
        const SizedBox(height: AppSpacing.xl),

        // --- Staff Directory ---
        const _SectionHeader(title: 'Staff Directory'),
        const SizedBox(height: AppSpacing.sm),
        if (staff.isEmpty)
          const _EmptySection(message: 'No staff found')
        else
          ...staff.map((s) => _StaffTile(staff: s)),
        const SizedBox(height: AppSpacing.xl),

        // --- Project Workforce Distribution ---
        const _SectionHeader(title: 'Project Workforce'),
        const SizedBox(height: AppSpacing.sm),
        if (projectWorkforce.isEmpty)
          const _EmptySection(message: 'No active projects')
        else
          ...projectWorkforce.map((p) => _ProjectWorkforceCard(project: p)),
        const SizedBox(height: AppSpacing.xl),

        // --- Recent Reports Feed ---
        const _SectionHeader(title: 'Recent Reports'),
        const SizedBox(height: AppSpacing.sm),
        if (recentReports.isEmpty)
          const _EmptySection(message: 'No recent reports')
        else
          ...recentReports.map((r) => _ReportCard(report: r)),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ─── Summary Cards ───────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: [
        StatCard(
          label: 'Total Staff',
          value: '${summary['totalStaff'] ?? 0}',
          icon: Icons.people_outlined,
          color: AppColors.primary,
        ),
        StatCard(
          label: 'At Site',
          value: '${summary['atSite'] ?? 0}',
          icon: Icons.location_on_outlined,
          color: AppColors.success,
        ),
        StatCard(
          label: 'Workshop',
          value: '${summary['inWorkshop'] ?? 0}',
          icon: Icons.warehouse_outlined,
          color: AppColors.warning,
        ),
        StatCard(
          label: 'On Leave',
          value: '${summary['onLeave'] ?? 0}',
          icon: Icons.event_busy_outlined,
          color: AppColors.danger,
        ),
      ],
    );
  }
}

// ─── Staff Directory ─────────────────────────────────────────────────────────

class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.staff});
  final Map<String, dynamic> staff;

  Color _statusColor(String? status) {
    switch (status) {
      case 'at_site':
        return AppColors.success;
      case 'workshop':
        return AppColors.warning;
      case 'leave':
        return AppColors.danger;
      case 'showroom':
        return AppColors.info;
      default:
        return AppColors.info;
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'supervisor':
        return Icons.supervisor_account;
      case 'designer':
        return Icons.design_services;
      default:
        return Icons.engineering;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = staff['id']?.toString() ?? '';
    final name = staff['fullName']?.toString() ?? '';
    final role = staff['role']?.toString() ?? '';
    final workerStatus = staff['workerStatus']?.toString();
    final activeProjects = staff['activeProjects'] as int? ?? 0;
    final reports30d = staff['reports30d'] as int? ?? 0;
    // Designers are always in Showroom
    final displayStatus = (role == 'designer') ? 'showroom' : workerStatus;
    final statusColor = _statusColor(displayStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StaffDetailScreen(userId: id, userName: name),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Icon(_roleIcon(role), color: statusColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _RoleBadge(role: role),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusBadge(status: displayStatus, color: statusColor),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$activeProjects projects',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$reports30d reports',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        Formatters.roleLabel(role),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String? status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = Formatters.stageLabel(status ?? 'unknown');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Project Workforce Distribution ──────────────────────────────────────────

class _ProjectWorkforceCard extends StatelessWidget {
  const _ProjectWorkforceCard({required this.project});
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final name = project['projectName']?.toString() ?? '';
    final customer = project['customerName']?.toString() ?? '';
    final stage = project['currentStage']?.toString() ?? '';
    final workers = project['workerCount'] as int? ?? 0;
    final supervisors = project['supervisorCount'] as int? ?? 0;
    final designers = project['designerCount'] as int? ?? 0;
    final total = workers + supervisors + designers;

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
                  child: Text(
                    customer.isNotEmpty ? customer : name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (AppColors.stageColors[stage] ?? AppColors.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Text(
                    Formatters.stageLabel(stage),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stageColors[stage] ?? AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (name.isNotEmpty && customer.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _CountChip(
                  icon: Icons.engineering,
                  count: workers,
                  label: 'Workers',
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                _CountChip(
                  icon: Icons.supervisor_account,
                  count: supervisors,
                  label: 'Supervisors',
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.md),
                _CountChip(
                  icon: Icons.design_services,
                  count: designers,
                  label: 'Designers',
                  color: AppColors.warning,
                ),
                const Spacer(),
                Text(
                  '$total total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
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

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Recent Reports Feed ─────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final authorName = report['authorName']?.toString() ?? '';
    final authorRole = report['authorRole']?.toString() ?? '';
    final projectName = report['projectName']?.toString() ?? '';
    final workDone = report['workDone']?.toString() ?? '';
    final createdAt = report['createdAt'];
    final progressPercent = report['progressPercent'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.info.withValues(alpha: 0.12),
                  child: Icon(
                    authorRole == 'supervisor'
                        ? Icons.supervisor_account
                        : Icons.engineering,
                    size: 14,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  Formatters.date(createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.home_work_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    projectName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progressPercent != null)
                  Text(
                    '$progressPercent%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
            if (workDone.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                workDone,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
