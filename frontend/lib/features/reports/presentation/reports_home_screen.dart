import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/loading_view.dart';
import '../../projects/application/projects_controller.dart';
import 'whatsapp_report_screen.dart';

/// Nav tab for workers/supervisors: WhatsApp-style project chat rooms.
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

    // If a project is selected, show the WhatsApp-style chat.
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_selectedProjectName ?? 'Chat',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Text('Project Chat',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        body: WhatsAppReportScreen(projectId: _selectedProjectId!),
      );
    }

    // Chat room list
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Chats'),
      ),
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
                      Icon(Icons.chat_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: AppSpacing.lg),
                      const Text('No project chats yet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Once you are assigned to a project, your chat room will appear here.\n'
                        'You can message your supervisor and team.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: projects.length,
              itemBuilder: (_, i) {
                final p = projects[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      p.customerName.isNotEmpty
                          ? p.customerName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                  title: Text(p.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(p.projectName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textMuted),
                  onTap: () => setState(() {
                    _selectedProjectId = p.id;
                    _selectedProjectName = p.customerName;
                  }),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
