import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stage_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../application/projects_controller.dart';

/// Shared project list for admin / supervisor / designer.
/// [basePath] is the role route prefix (e.g. '/admin').
class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key, required this.basePath});
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsListProvider);
    final role = ref.watch(authControllerProvider).user?.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search projects...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (q) {
                ref.read(projectsFilterProvider.notifier).state =
                    ref.read(projectsFilterProvider).copyWith(query: q);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: role == 'admin'
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.go('$basePath/projects/new'),
              child: const Icon(Icons.add),
            )
          : null,
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
                icon: Icons.home_work_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final p = projects[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    onTap: () => context.go('$basePath/projects/${p.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.projectName,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700,),
                                ),
                              ),
                              StageChip(stage: p.currentStage),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.projectNumber} · ${p.customerName}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: p.progress / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceAlt,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${p.progress}% complete',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted,),),
                        ],
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
