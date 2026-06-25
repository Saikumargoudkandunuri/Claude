import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/widgets/stage_tracker.dart';
import '../../../activity/application/activity_controller.dart';
import '../../domain/project.dart';

/// Amazon-style animated project progress tracker + activity history.
class TimelineTab extends ConsumerWidget {
  const TimelineTab({super.key, required this.project});
  final Project project;

  /// The 7 fixed customer-facing journey stages.
  static const List<String> _journey = [
    'Project Created',
    'Site Measurement',
    'Design Approval',
    'Material Procurement',
    'Installation',
    'Finishing',
    'Handover',
  ];

  /// Map the backend 13-stage enum onto a 0..1 progress value across 7 nodes.
  double _progressFor(String stage) {
    const map = {
      'discussion': 1,
      'site_measurement': 1,
      '3d_design': 2,
      'drawing': 2,
      'material_purchase': 3,
      'cutting': 4,
      'making': 4,
      'lamination': 4,
      'painting': 4,
      'packing': 4,
      'transport': 4,
      'installation': 4,
      'checking': 5,
      'completed': 6,
    };
    final node = (map[stage] ?? 0).toDouble();
    return (node / (_journey.length - 1)).clamp(0.0, 1.0);
  }

  /// Estimated completion date for each journey node, spread between the
  /// project start and expected completion dates.
  List<TrackerStage> _stages() {
    final start = DateTime.tryParse(project.startDate ?? '');
    final end = DateTime.tryParse(project.expectedCompletionDate ?? '');
    return List.generate(_journey.length, (i) {
      String? dateLabel;
      if (start != null && end != null && end.isAfter(start)) {
        final span = end.difference(start).inDays;
        final d = start.add(Duration(days: (span * i / (_journey.length - 1)).round()));
        dateLabel = 'Est. ${Formatters.date(d.toIso8601String())}';
      }
      return TrackerStage(_journey[i], dateLabel: dateLabel);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = _progressFor(project.currentStage);
    final stages = _stages();
    final activityAsync = ref.watch(projectTimelineProvider(project.id));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(projectTimelineProvider(project.id)),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Project Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary,),),
          const SizedBox(height: AppSpacing.lg),
          // Responsive: horizontal on tablets, vertical on phones.
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth > 700;
              return StageTracker(
                stages: stages,
                progress: progress,
                orientation: horizontal ? Axis.horizontal : Axis.vertical,
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text('Activity History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary,),),
          const SizedBox(height: AppSpacing.sm),
          activityAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LoadingView(),
            ),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(projectTimelineProvider(project.id)),
            ),
            data: (events) {
              if (events.isEmpty) {
                return const EmptyState(message: 'No activity yet', icon: Icons.history);
              }
              return Column(
                children: [
                  for (final e in events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.fiber_manual_record,
                          size: 12, color: AppColors.primary,),
                      title: Text(
                        (e['description'] ?? e['action'] ?? 'Activity').toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${e['userName'] ?? 'System'} · ${Formatters.dateTime(e['createdAt'])}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
