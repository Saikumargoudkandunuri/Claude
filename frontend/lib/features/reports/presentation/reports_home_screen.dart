import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../projects/application/projects_controller.dart';
import 'report_chat_view.dart';

/// Nav tab for workers/supervisors: pick a site → open WhatsApp-style report chat.
class ReportsHomeScreen extends ConsumerStatefulWidget {
  const ReportsHomeScreen({super.key});

  @override
  ConsumerState<ReportsHomeScreen> createState() => _ReportsHomeScreenState();
}

class _ReportsHomeScreenState extends ConsumerState<ReportsHomeScreen> {
  String? _selectedProjectId;
  String? _selectedProjectName;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectsListProvider);
    final role = ref.watch(authControllerProvider).user?.role ?? 'worker';

    // If a project is selected, show the chat view.
    if (_selectedProjectId != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
              _selectedProjectId = null;
              _selectedProjectName = null;
            }),
          ),
          title: Text(_selectedProjectName ?? 'Reports'),
        ),
        body: ReportChatView(
          projectId: _selectedProjectId!,
          canCompose: role == 'worker' || role == 'supervisor',
        ),
      );
    }

    // Otherwise show site list.
    return Scaffold(
      appBar: AppBar(title: const Text('Site Reports')),
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: AppSpacing.lg),
                      const Text('No projects assigned yet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Your administrator needs to assign you to a project.\n'
                        'Once assigned, your project reports and chat will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: projects.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final p = projects[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceAlt,
                      child:
                          Icon(Icons.chat_outlined, color: AppColors.primary),
                    ),
                    title: Text(
                      p.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${p.projectNumber} · ${p.projectName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() {
                      _selectedProjectId = p.id;
                      _selectedProjectName = p.customerName;
                    }),
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
