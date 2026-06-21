import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';

/// Renders an activity-log feed used on dashboards.
class RecentUpdatesList extends StatelessWidget {
  const RecentUpdatesList({super.key, required this.updates});
  final List updates;

  @override
  Widget build(BuildContext context) {
    if (updates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyState(
          message: 'No recent activity yet',
          icon: Icons.history,
        ),
      );
    }
    return Column(
      children: [
        for (final u in updates.cast<Map<String, dynamic>>())
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceAlt,
              child: Icon(Icons.bolt, color: AppColors.primary, size: 20),
            ),
            title: Text(
              (u['description'] ?? u['action'] ?? 'Activity').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${u['userName'] ?? 'System'} · ${Formatters.dateTime(u['createdAt'])}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
