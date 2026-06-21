import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/dashboard_controller.dart';

class DesignerDashboard extends ConsumerWidget {
  const DesignerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final async = ref.watch(dashboardProvider('designer'));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.fullName.split(' ').first ?? 'Designer'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.go('/designer/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider('designer')),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(dashboardProvider('designer')),
          ),
          data: (d) {
            final needing = (d['sitesNeedingDesign'] as List?) ?? const [];
            final uploads = (d['recentUploads'] as List?) ?? const [];
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const Text('Sites Needing Design',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                if (needing.isEmpty)
                  const EmptyState(
                    message: 'No design work pending',
                    icon: Icons.design_services_outlined,
                  )
                else
                  for (final p in needing.cast<Map<String, dynamic>>())
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(p['projectName']?.toString() ?? ''),
                        subtitle: Text(
                          '${p['projectNumber']} · ${Formatters.stageLabel(p['currentStage'] as String?)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/designer/projects/${p['id']}'),
                      ),
                    ),
                const SizedBox(height: AppSpacing.xl),
                const Text('My Recent Uploads',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                if (uploads.isEmpty)
                  const Text('No uploads yet',
                      style: TextStyle(color: AppColors.textSecondary))
                else
                  for (final f in uploads.cast<Map<String, dynamic>>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined,
                          color: AppColors.primary),
                      title: Text(f['originalName']?.toString() ?? ''),
                      subtitle: Text(
                        '${Formatters.stageLabel(f['category'] as String?)} · ${f['projectName']}',
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
