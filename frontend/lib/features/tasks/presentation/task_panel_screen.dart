import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../projects/application/projects_controller.dart';
import '../application/tasks_controller.dart';

/// Admin/Supervisor task panel: assign work to workers for Today or Tomorrow
/// and track their status.
class TaskPanelScreen extends ConsumerWidget {
  const TaskPanelScreen({super.key});

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
  String _tomorrow() =>
      DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(taskPanelDateProvider);
    final async = ref.watch(taskPanelProvider);
    final isToday = date == _today();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Tasks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Today')),
                ButtonSegment(value: false, label: Text('Tomorrow')),
              ],
              selected: {isToday},
              onSelectionChanged: (s) => ref
                  .read(taskPanelDateProvider.notifier)
                  .state = s.first ? _today() : _tomorrow(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Assign Work'),
        onPressed: () => _assignFlow(context, ref, date),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(taskPanelProvider),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(taskPanelProvider),
          ),
          data: (data) {
            final plans = (data['plans'] as List?) ?? const [];
            if (plans.isEmpty) {
              return const EmptyState(
                message: 'No work assigned for this day',
                icon: Icons.task_alt_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) =>
                  _PlanCard(plan: plans[i] as Map<String, dynamic>),
            );
          },
        ),
      ),
    );
  }

  Future<void> _assignFlow(BuildContext context, WidgetRef ref, String date) async {
    final projects = await ref.read(projectsRepositoryProvider).list();
    if (!context.mounted) return;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No projects available')));
      return;
    }
    final project = await showModalBottomSheet<dynamic>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Select project',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),),
            ),
            for (final p in projects)
              ListTile(
                title: Text(p.projectName),
                subtitle: Text(p.projectNumber),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (project == null || !context.mounted) return;

    final workers = await ref.read(projectsRepositoryProvider).assignable('worker');
    if (!context.mounted) return;
    final selected = <String>{};
    final taskController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Assign workers — ${project.projectName}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,),),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: taskController,
                  decoration: const InputDecoration(
                      labelText: 'Task (e.g. Kitchen Installation)',),
                ),
                const SizedBox(height: AppSpacing.md),
                if (workers.isEmpty)
                  const Text('No approved workers available'),
                for (final w in workers)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(w['id']),
                    title: Text(w['fullName']?.toString() ?? ''),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        selected.add(w['id'] as String);
                      } else {
                        selected.remove(w['id']);
                      }
                    }),
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Assign'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(tasksRepositoryProvider).assign(
            projectId: project.id as String,
            planDate: date,
            workerIds: selected.toList(),
            task: taskController.text.trim().isEmpty ? null : taskController.text.trim(),
          );
      ref.invalidate(taskPanelProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Work assigned')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final workers = (plan['workers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan['projectName']?.toString() ?? 'Project',
                style: const TextStyle(fontWeight: FontWeight.w700),),
            if ((plan['task']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(plan['task'].toString(),
                    style: const TextStyle(color: AppColors.textSecondary),),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final w in workers)
                  Chip(
                    label: Text(w['fullName']?.toString() ?? ''),
                    avatar: Icon(
                      _statusIcon(w['status']?.toString()),
                      size: 16,
                      color: _statusColor(w['status']?.toString()),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String? s) => switch (s) {
        'completed' => Icons.check_circle,
        'started' => Icons.timelapse,
        _ => Icons.schedule,
      };

  Color _statusColor(String? s) => switch (s) {
        'completed' => AppColors.success,
        'started' => AppColors.info,
        _ => AppColors.warning,
      };
}
