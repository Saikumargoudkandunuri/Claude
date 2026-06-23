import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stage_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../reports/presentation/reports_tab.dart';
import '../application/projects_controller.dart';
import '../domain/project.dart';
import 'tabs/details_tab.dart';
import 'tabs/drawings_tab.dart';
import 'tabs/payments_tab.dart';
import 'tabs/timeline_tab.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectDetailProvider(projectId));
    final role = ref.watch(authControllerProvider).user?.role;
    final isAdmin = role == 'admin';

    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(projectDetailProvider(projectId)),
        ),
      ),
      data: (project) {
        final tabs = <Tab>[
          const Tab(text: 'Details'),
          const Tab(text: 'Drawings'),
          const Tab(text: 'Reports'),
          if (isAdmin) const Tab(text: 'Payments'),
          const Tab(text: 'Timeline'),
        ];
        final views = <Widget>[
          DetailsTab(project: project),
          DrawingsTab(projectId: project.id),
          ReportsTab(projectId: project.id),
          if (isAdmin) PaymentsTab(projectId: project.id),
          TimelineTab(project: project),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  pinned: true,
                  title: Text(project.projectName),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(96),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${project.projectNumber} · ${project.customerName}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              StageChip(stage: project.currentStage),
                            ],
                          ),
                        ),
                        TabBar(
                          isScrollable: true,
                          labelColor: AppColors.primaryDark,
                          indicatorColor: AppColors.primary,
                          tabs: tabs,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(children: views),
            ),
            // BUG-05: hide the stage button on the Reports tab so it never
            // overlaps the chat send button.
            floatingActionButton: Builder(
              builder: (ctx) {
                final controller = DefaultTabController.of(ctx);
                return AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) {
                    final reportsIndex = tabs.indexWhere((t) => t.text == 'Reports');
                    if (controller.index == reportsIndex) {
                      return const SizedBox.shrink();
                    }
                    return _StageFab(project: project, role: role);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Advance the project stage (admin: any, supervisor: execution, designer: design).
class _StageFab extends ConsumerWidget {
  const _StageFab({required this.project, required this.role});
  final Project project;
  final String? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllable = kProjectStages
        .where((s) => Permissions.canControlStage(role, s))
        .toList();
    if (controllable.isEmpty) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.timeline),
      label: const Text('Update Stage'),
      onPressed: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Set current stage',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                for (final s in controllable)
                  ListTile(
                    title: Text(Formatters.stageLabel(s)),
                    trailing: s == project.currentStage
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, s),
                  ),
              ],
            ),
          ),
        );
        if (selected == null) return;
        final status = selected == 'completed' ? 'completed' : 'in_progress';
        await ref
            .read(projectsRepositoryProvider)
            .setStage(project.id, selected, status: status);
        ref.invalidate(projectDetailProvider(project.id));
        ref.invalidate(projectsListProvider);
      },
    );
  }
}
