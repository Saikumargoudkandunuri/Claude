import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../projects/application/projects_controller.dart';
import 'report_form_sheet.dart';

/// Nav tab for workers/supervisors: pick a site and submit its daily report.
class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsListProvider);
    final role = ref.watch(authControllerProvider).user?.role ?? 'worker';

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Reports')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(projectsListProvider),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const EmptyState(
              message: 'No sites assigned',
              icon: Icons.assignment_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Text(
                'Select a site to submit your end-of-day report',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final p in projects)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Text(p.projectName),
                    subtitle: Text(p.projectNumber),
                    trailing:
                        const Icon(Icons.edit_note, color: AppColors.primary),
                    onTap: () => showReportForm(context, ref, p.id, role),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
