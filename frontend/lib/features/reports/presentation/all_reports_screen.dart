import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/reports_controller.dart';
import 'report_card.dart';

/// All reports across projects — visible to Admin (all) and Supervisor (own).
class AllReportsScreen extends ConsumerWidget {
  const AllReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Reports')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allReportsProvider),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(allReportsProvider),
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
              itemBuilder: (_, i) => ReportCard(report: reports[i], showProject: true),
            );
          },
        ),
      ),
    );
  }
}
