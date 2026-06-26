import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';

/// Provider fetching a single staff member's full details + history.
final staffDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, userId) async {
  final dio = ref.watch(dioProvider);
  final workforceRes = await dio.get('/dashboard/workforce');
  final data = workforceRes.data['data'] as Map<String, dynamic>;
  final staff = (data['staff'] as List).cast<Map<String, dynamic>>();
  final assignments =
      (data['assignments'] as List).cast<Map<String, dynamic>>();
  final reports = (data['recentReports'] as List).cast<Map<String, dynamic>>();

  final user = staff.firstWhere((s) => s['id'] == userId, orElse: () => {});
  final userAssignments =
      assignments.where((a) => a['userId'] == userId).toList();
  final userReports =
      reports.where((r) => r['authorName'] == user['fullName']).toList();

  return {
    'user': user,
    'assignments': userAssignments,
    'reports': userReports,
  };
});

/// Staff detail screen showing Employee ID, contact info, assignments, report history.
class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen(
      {super.key, required this.userId, required this.userName,});
  final String userId;
  final String userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffDetailProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(userName)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(staffDetailProvider(userId)),
        ),
        data: (data) {
          final user = data['user'] as Map<String, dynamic>? ?? {};
          final assignments =
              (data['assignments'] as List?)?.cast<Map<String, dynamic>>() ??
                  [];
          final reports =
              (data['reports'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Profile header
              _ProfileHeader(user: user, userId: userId),
              const SizedBox(height: AppSpacing.xl),

              // Employee ID (copyable)
              _EmployeeIdCard(userId: userId),
              const SizedBox(height: AppSpacing.xl),

              // Contact info
              _InfoSection(user: user),
              const SizedBox(height: AppSpacing.xl),

              // Current Assignments
              const Text('Current Assignments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
              const SizedBox(height: AppSpacing.sm),
              if (assignments.isEmpty)
                const Text('No active assignments',
                    style: TextStyle(color: AppColors.textSecondary),)
              else
                ...assignments.map((a) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.home_work_outlined,
                            color: AppColors.primary,),
                        title: Text(
                            a['customerName']?.toString() ??
                                a['projectName']?.toString() ??
                                '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),),
                        subtitle: Text(
                          '${a['projectName'] ?? ''} · ${Formatters.stageLabel(a['currentStage']?.toString())}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: a['task'] != null
                            ? Chip(
                                label: Text(a['task'].toString(),
                                    style: const TextStyle(fontSize: 11),),)
                            : null,
                      ),
                    ),),
              const SizedBox(height: AppSpacing.xl),

              // Report History
              const Text('Report History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
              const SizedBox(height: AppSpacing.sm),
              if (reports.isEmpty)
                const Text('No recent reports',
                    style: TextStyle(color: AppColors.textSecondary),)
              else
                ...reports.map((r) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Navigate to the project's report chat
                          // Reports don't have a direct deep-link yet
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Report on ${r['projectName']}'),),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.assignment,
                                      size: 16, color: AppColors.primary,),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      r['projectName']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    Formatters.date(r['createdAt']),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,),
                                  ),
                                ],
                              ),
                              if (r['workDone'] != null &&
                                  r['workDone'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  r['workDone'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                              if (r['progressPercent'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Progress: ${r['progressPercent']}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.userId});
  final Map<String, dynamic> user;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final name = user['fullName']?.toString() ?? '';
    final role = user['role']?.toString() ?? '';

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              Formatters.roleLabel(role),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeIdCard extends StatelessWidget {
  const _EmployeeIdCard({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Employee ID',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,),),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    userId,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy,
                      size: 18, color: AppColors.primary,),
                  tooltip: 'Copy ID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: userId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Employee ID copied')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Share this ID with the staff member for PIN reset.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _infoTile(Icons.phone_outlined, 'Phone',
              user['phone']?.toString() ?? 'N/A',),
          const Divider(height: 1),
          _infoTile(Icons.work_outline, 'Status',
              Formatters.stageLabel(user['workerStatus']?.toString()),),
          const Divider(height: 1),
          _infoTile(Icons.folder_outlined, 'Active Projects',
              '${user['activeProjects'] ?? 0}',),
          const Divider(height: 1),
          _infoTile(Icons.assignment_outlined, 'Reports (30 days)',
              '${user['reports30d'] ?? 0}',),
          const Divider(height: 1),
          _infoTile(Icons.calendar_today_outlined, 'Joined',
              Formatters.date(user['joinedAt']),),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),),
      trailing: Text(value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
    );
  }
}
