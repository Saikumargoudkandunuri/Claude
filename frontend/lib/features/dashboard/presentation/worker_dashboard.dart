import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../shared/widgets/voice_recorder_sheet.dart';
import '../../auth/application/auth_controller.dart';
import '../../payroll/presentation/worker_attendance_card.dart';
import '../../payroll/presentation/my_salary_screen.dart';
import '../../tasks/application/tasks_controller.dart';
import '../application/dashboard_controller.dart';
import 'widgets/app_overflow_menu.dart';
import 'widgets/attendance_card.dart';

/// Complete Worker Dashboard — personal work assistant for field workers.
class WorkerDashboard extends ConsumerWidget {
  const WorkerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final async = ref.watch(dashboardProvider('worker'));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${user?.fullName.split(' ').first ?? 'there'} 👋',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          _StatusChip(current: user?.workerStatus ?? 'workshop'),
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
          data: (d) => _WorkerBody(data: d, ref: ref),
        ),
      ),
    );
  }
}

class _WorkerBody extends StatelessWidget {
  const _WorkerBody({required this.data, required this.ref});
  final Map<String, dynamic> data;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final todays =
        (data['todaysWork'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final assigned =
        (data['assignedSites'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final reportDue = data['reportDueToday'] == true;
    final drawings =
        (data['recentDrawings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final contacts =
        (data['contacts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ═══ Payroll Attendance ═══
        const WorkerAttendanceCard(),
        const SizedBox(height: AppSpacing.lg),

        // ═══ Report Status Banner ═══
        if (reportDue)
          _ReportBanner(onTap: () => context.go('/worker/reports')),
        if (!reportDue) _ReportSubmittedBanner(),
        const SizedBox(height: AppSpacing.lg),

        // ═══ Attendance Check-In ═══
        const AttendanceCard(),
        const SizedBox(height: AppSpacing.lg),

        // ═══ Quick Actions ═══
        _QuickActions(ref: ref),
        const SizedBox(height: AppSpacing.lg),

        // ═══ My Salary Tile ═══
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x1A185FA5),
              child: Icon(Icons.payments_rounded,
                  color: Color(0xFF185FA5), size: 20),
            ),
            title: const Text('My Salary',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: const Text('View breakdown & payment history',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MySalaryScreen())),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ═══ Today's Project ═══
        if (assigned.isNotEmpty) ...[
          const _SectionTitle(title: "Today's Site"),
          const SizedBox(height: AppSpacing.sm),
          _ProjectCard(site: assigned.first),
          const SizedBox(height: AppSpacing.lg),
        ] else ...[
          Card(
            color: AppColors.info.withValues(alpha: 0.08),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: 32,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'No project assigned',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ask your administrator to assign you to a project.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ═══ Today's Tasks ═══
        const _SectionTitle(title: "Today's Tasks"),
        const SizedBox(height: AppSpacing.sm),
        if (todays.isEmpty)
          const _EmptyCard(
              icon: Icons.task_alt, message: 'No tasks assigned today')
        else
          ...todays.map((t) => _TaskTile(task: t, ref: ref)),
        const SizedBox(height: AppSpacing.lg),

        // ═══ Drawings ═══
        if (drawings.isNotEmpty) ...[
          const _SectionTitle(title: 'Recent Drawings'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: drawings.map((d) => _DrawingChip(drawing: d)).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ═══ All Assigned Sites ═══
        if (assigned.length > 1) ...[
          _SectionTitle(title: 'My Sites (${assigned.length})'),
          const SizedBox(height: AppSpacing.sm),
          ...assigned.map((s) => _SiteTile(site: s)),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ═══ Contacts ═══
        if (contacts.isNotEmpty) ...[
          const _SectionTitle(title: 'Contacts'),
          const SizedBox(height: AppSpacing.sm),
          ...contacts.map((c) => _ContactTile(contact: c)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _ReportBanner extends StatelessWidget {
  const _ReportBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_late,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Report Pending',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Submit your end-of-day report',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSubmittedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.success.withValues(alpha: 0.08),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: AppSpacing.md),
            Text(
              "Today's report submitted ✓",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.mic,
          label: 'Voice',
          color: const Color(0xFF00A884),
          onTap: () async {
            final recording = await VoiceRecorderSheet.show(context);
            if (recording != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Voice note recorded. Open Reports to send.'),
                ),
              );
            }
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        _ActionButton(
          icon: Icons.camera_alt,
          label: 'Photo',
          color: AppColors.info,
          onTap: () => context.go('/worker/reports'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ActionButton(
          icon: Icons.description_outlined,
          label: 'Report',
          color: AppColors.primary,
          onTap: () => context.go('/worker/reports'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ActionButton(
          icon: Icons.draw_outlined,
          label: 'Drawings',
          color: AppColors.warning,
          onTap: () {
            // Navigate to first assigned site's drawings
            final sites = (ref
                    .read(dashboardProvider('worker'))
                    .value?['assignedSites'] as List?) ??
                [];
            if (sites.isNotEmpty) {
              context.go('/worker/sites/${(sites.first as Map)['id']}');
            }
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.site});
  final Map<String, dynamic> site;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/worker/sites/${site['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.home_work,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site['projectName']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (site['siteLocation'] != null)
                          Text(
                            site['siteLocation'].toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (site['task'] != null &&
                  site['task'].toString().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.assignment_outlined,
                        size: 14,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          site['task'].toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Chip(
                    label: Formatters.stageLabel(
                      site['currentStage'] as String?,
                    ),
                    color: AppColors.primary,
                  ),
                  const Spacer(),
                  const Text(
                    'View Details →',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _TaskTile extends ConsumerStatefulWidget {
  const _TaskTile({required this.task, required this.ref});
  final Map<String, dynamic> task;
  final WidgetRef ref;

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> {
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
    final isCompleted = status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: _busy
                  ? null
                  : () => _setStatus(isCompleted ? 'assigned' : 'completed'),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppColors.success : Colors.transparent,
                  border: Border.all(
                    color:
                        isCompleted ? AppColors.success : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w['task']?.toString() ??
                        w['projectName']?.toString() ??
                        'Task',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    w['projectName']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _Chip(
              label: status[0].toUpperCase() + status.substring(1),
              color: isCompleted
                  ? AppColors.success
                  : status == 'started'
                      ? AppColors.info
                      : AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingChip extends StatelessWidget {
  const _DrawingChip({required this.drawing});
  final Map<String, dynamic> drawing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final fileId = drawing['id']?.toString() ?? '';
        final name = drawing['originalName']?.toString() ?? 'Drawing';
        if (fileId.isNotEmpty) {
          final url =
              '${DioClient.instance.dio.options.baseUrl}/files/$fileId/download';
          context.push('/viewer', extra: {'url': url, 'name': name});
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: AppColors.danger, size: 20),
            const SizedBox(height: 6),
            Text(
              drawing['originalName']?.toString() ?? 'Drawing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              drawing['projectName']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({required this.site});
  final Map<String, dynamic> site;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading:
            const Icon(Icons.location_on_outlined, color: AppColors.primary),
        title: Text(
          site['projectName']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          site['task']?.toString() ??
              Formatters.stageLabel(site['currentStage'] as String?),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: () => context.go('/worker/sites/${site['id']}'),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});
  final Map<String, dynamic> contact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(
            contact['role'] == 'admin'
                ? Icons.admin_panel_settings
                : Icons.supervisor_account,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          contact['name']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${Formatters.roleLabel(contact['role'] as String?)} · ${contact['phone'] ?? ''}',
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 36, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends ConsumerWidget {
  const _StatusChip({required this.current});
  final String current;

  static const _options = {
    'workshop': 'Workshop',
    'at_site': 'At Site',
    'leave': 'Leave',
    'holiday': 'Holiday',
  };

  Color get _color => switch (current) {
        'at_site' => AppColors.success,
        'leave' => AppColors.danger,
        _ => AppColors.warning,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: _color),
            const SizedBox(width: 4),
            Text(
              _options[current] ?? 'Status',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
