import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../activity/application/activity_controller.dart';

/// Complete project history: every action with date, time, user and description.
class TimelineTab extends ConsumerWidget {
  const TimelineTab({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectTimelineProvider(projectId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(projectTimelineProvider(projectId)),
      child: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(projectTimelineProvider(projectId)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(message: 'No activity yet', icon: Icons.history);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: events.length,
            itemBuilder: (_, i) {
              final e = events[i];
              final isLast = i == events.length - 1;
              return _TimelineRow(event: e, isLast: isLast);
            },
          );
        },
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});
  final Map<String, dynamic> event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (event['description'] ?? event['action'] ?? 'Activity').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event['userName'] ?? 'System'} · ${event['day'] ?? ''} '
                    '${Formatters.dateTime(event['createdAt'])}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
