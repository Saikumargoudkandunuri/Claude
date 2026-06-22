import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../projects/application/projects_controller.dart';

/// Assign / change Designer, Supervisor and Workers for a project at any time.
class AssignmentEditorScreen extends ConsumerWidget {
  const AssignmentEditorScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).user?.role;
    final isAdmin = role == 'admin';
    final async = ref.watch(projectAssignmentsProvider(projectId));
    final repo = ref.read(projectsRepositoryProvider);

    Future<void> refresh() async {
      ref.invalidate(projectAssignmentsProvider(projectId));
    }

    Future<void> pickAndAssign(String roleToAssign) async {
      final options = await repo.assignable(roleToAssign);
      if (!context.mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (_) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Select ${roleToAssign[0].toUpperCase()}${roleToAssign.substring(1)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (options.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('No approved users for this role'),
                ),
              for (final o in options)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(o['fullName']?.toString() ?? ''),
                  onTap: () => Navigator.pop(context, o),
                ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      try {
        String? task;
        if (roleToAssign == 'worker') {
          task = await _askTask(context);
        }
        await repo.assign(projectId, selected['id'] as String, roleToAssign, task: task);
        await refresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DioClient.toApiException(e).message)),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Assignments · $projectName')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: refresh),
        data: (assignments) {
          final supervisors =
              assignments.where((a) => a['role'] == 'supervisor').toList();
          final designers =
              assignments.where((a) => a['role'] == 'designer').toList();
          final workers = assignments.where((a) => a['role'] == 'worker').toList();

          Future<void> remove(Map<String, dynamic> a) async {
            await repo.removeAssignment(projectId, a['id'] as String);
            await refresh();
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (isAdmin) ...[
                _RoleSection(
                  title: 'Supervisor',
                  members: supervisors,
                  onAdd: () => pickAndAssign('supervisor'),
                  onRemove: remove,
                  addLabel: supervisors.isEmpty ? 'Assign' : 'Change',
                ),
                _RoleSection(
                  title: 'Designer',
                  members: designers,
                  onAdd: () => pickAndAssign('designer'),
                  onRemove: remove,
                  addLabel: designers.isEmpty ? 'Assign' : 'Change',
                ),
              ],
              _RoleSection(
                title: 'Workers',
                members: workers,
                onAdd: () => pickAndAssign('worker'),
                onRemove: remove,
                addLabel: 'Add Worker',
                allowMultiple: true,
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<String?> _askTask(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Task (optional)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Kitchen Installation'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Assign')),
        ],
      ),
    );
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.title,
    required this.members,
    required this.onAdd,
    required this.onRemove,
    required this.addLabel,
    this.allowMultiple = false,
  });

  final String title;
  final List<Map<String, dynamic>> members;
  final VoidCallback onAdd;
  final Future<void> Function(Map<String, dynamic>) onRemove;
  final String addLabel;
  final bool allowMultiple;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(addLabel),
              ),
            ],
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text('Not assigned',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final m in members)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: ListTile(
                  leading: const Icon(Icons.person, color: AppColors.primary),
                  title: Text(m['fullName']?.toString() ?? ''),
                  subtitle: (m['task'] != null &&
                          m['task'].toString().isNotEmpty)
                      ? Text(m['task'].toString())
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.danger),
                    onPressed: () => onRemove(m),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
