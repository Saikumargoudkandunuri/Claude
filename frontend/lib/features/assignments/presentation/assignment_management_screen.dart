import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stage_chip.dart';
import '../../projects/application/projects_controller.dart';
import 'assignment_editor_screen.dart';

/// Dedicated page to manage assignments across all projects.
class AssignmentManagementScreen extends ConsumerWidget {
  const AssignmentManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assignment Management')),
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
                message: 'No projects to manage',
                icon: Icons.group_outlined,
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
                    subtitle: Text('${p.projectNumber} · ${p.customerName}',
                        overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.group_add_outlined,
                        color: AppColors.primary),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssignmentEditorScreen(
                          projectId: p.id,
                          projectName: p.projectName,
                        ),
                      ),
                    ),
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
