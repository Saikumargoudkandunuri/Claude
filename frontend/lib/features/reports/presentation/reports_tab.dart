import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/reports_controller.dart';
import 'report_form_sheet.dart';

class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectReportsProvider(projectId));
    final role = ref.watch(authControllerProvider).user?.role;
    final canSubmit = role == 'worker' || role == 'supervisor';

    return Scaffold(
      floatingActionButton: canSubmit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_note),
              label: const Text('Submit Report'),
              onPressed: () => showReportForm(context, ref, projectId, role!),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(projectReportsProvider(projectId)),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const EmptyState(
              message: 'No reports submitted yet',
              icon: Icons.assignment_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _ReportCard(report: reports[i]),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final type = report['type'] as String? ?? 'worker';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == 'supervisor' ? Icons.supervisor_account : Icons.engineering,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${report['authorName'] ?? 'User'} · ${Formatters.roleLabel(type)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(Formatters.date(report['reportDate']),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _field('Work Done', report['workDone']),
            _field('Pending', report['pendingWork']),
            _field('Problems', report['problems']),
            _field('Materials Needed', report['materialsNeeded']),
            _field('Site Progress', report['siteProgress']),
            _field('Tomorrow', report['tomorrowNotes']),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            TextSpan(text: value.toString()),
          ],
        ),
      ),
    );
  }
}
