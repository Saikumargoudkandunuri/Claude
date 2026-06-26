import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stage_chip.dart';
import '../../../shared/widgets/weekly_status_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../reports/presentation/reports_tab.dart';
import '../application/projects_controller.dart';
import '../data/weekly_status_api.dart';
import '../domain/project.dart';
import 'edit_project_sheet.dart';
import 'set_weekly_status_sheet.dart';
import 'tabs/details_tab.dart';
import 'tabs/drawings_tab.dart';
import 'tabs/payments_tab.dart';
import 'tabs/timeline_tab.dart';
import 'widgets/stage_timeline_widget.dart';
import 'weekly_status_history_screen.dart';
import 'site_photos_screen.dart';
import 'snag_list_screen.dart';

final _weeklyStatusProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, projectId) async {
  final api = WeeklyStatusApi();
  return await api.getCurrentStatus(projectId);
});

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
        final weeklyStatus =
            ref.watch(_weeklyStatusProvider(projectId)).valueOrNull;
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
                  actions: isAdmin
                      ? [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit Project',
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => EditProjectSheet(
                                project: project,
                                onUpdated: () {
                                  ref.invalidate(
                                    projectDetailProvider(projectId),
                                  );
                                  ref.invalidate(projectsListProvider);
                                },
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Project'),
                                    content: const Text(
                                      'Are you sure you want to delete this project? '
                                      'It will be archived and can be restored later.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  try {
                                    final repo =
                                        ref.read(projectsRepositoryProvider);
                                    await repo.delete(project.id);
                                    ref.invalidate(projectsListProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Project deleted'),
                                        ),
                                      );
                                      context.pop();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            DioClient.toApiException(e).message,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete Project',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ]
                      : null,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(132),
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
                        if (role != 'worker')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.xs,
                              AppSpacing.lg,
                              AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                WeeklyStatusChip(
                                  status: weeklyStatus?['status'] as String?,
                                ),
                                const Spacer(),
                                if (role == 'admin' || role == 'supervisor')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon:
                                            const Icon(Icons.history, size: 20),
                                        tooltip: 'Status History',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                WeeklyStatusHistoryScreen(
                                              projectId: project.id,
                                              projectName: project.projectName,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.bar_chart_rounded,
                                          size: 20,
                                          color: Color(0xFF00D1DC),
                                        ),
                                        tooltip: 'Set Weekly Status',
                                        onPressed: () => showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => SetWeeklyStatusSheet(
                                            projectId: project.id,
                                            projectName: project.projectName,
                                            currentStatus:
                                                weeklyStatus?['status']
                                                    as String?,
                                            currentNotes: weeklyStatus?['notes']
                                                as String?,
                                            onUpdated: () => ref.invalidate(
                                              _weeklyStatusProvider(projectId),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                SliverToBoxAdapter(
                  child: StageTimelineWidget(projectId: projectId),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (role != 'worker')
                          ActionChip(
                            avatar: const Icon(Icons.photo_library_outlined,
                                size: 18, color: Color(0xFF00D1DC)),
                            label: const Text('Photos'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SitePhotosScreen(
                                  projectId: project.id,
                                  projectName: project.projectName,
                                ),
                              ),
                            ),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.checklist_rounded,
                              size: 18, color: Color(0xFF00D1DC)),
                          label: const Text('Snag List'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SnagListScreen(
                                projectId: project.id,
                                projectName: project.projectName,
                                userRole: role ?? 'worker',
                              ),
                            ),
                          ),
                        ),
                        if (isAdmin)
                          ActionChip(
                            avatar: const Icon(Icons.picture_as_pdf_rounded,
                                size: 18, color: Color(0xFF00D1DC)),
                            label: const Text('Export PDF'),
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Generating PDF...'),
                                      duration: Duration(seconds: 2)));
                              try {
                                final res = await DioClient.instance.dio.get(
                                  '/projects/${project.id}/export-pdf',
                                  options:
                                      Options(responseType: ResponseType.bytes),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('✅ PDF downloaded'),
                                          backgroundColor: Color(0xFF00D1DC)));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Export failed: $e'),
                                          backgroundColor: Colors.red));
                                }
                              }
                            },
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
                    final reportsIndex =
                        tabs.indexWhere((t) => t.text == 'Reports');
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
