import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/reports_controller.dart';
import 'report_card.dart';
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
            itemBuilder: (_, i) => ReportCard(report: reports[i]),
          );
        },
      ),
    );
  }
}
