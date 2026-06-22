import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../projects/application/projects_controller.dart';

/// Admin payments overview: contract value per project, tap to manage.
class PaymentsOverviewScreen extends ConsumerWidget {
  const PaymentsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(projectsListProvider),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(projectsListProvider),
          ),
          data: (projects) {
            if (projects.isEmpty) {
              return const EmptyState(
                message: 'No projects yet',
                icon: Icons.payments_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final p = projects[i];
                return Card(
                  child: ListTile(
                    title: Text(p.projectName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      'Contract ${Formatters.currency(p.quotationAmount)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/admin/projects/${p.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
