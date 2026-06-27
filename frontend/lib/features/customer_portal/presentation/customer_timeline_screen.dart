import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/customer_providers.dart';

/// Vertical timeline showing all 13 project stages with visual distinction
/// between completed, current, and upcoming stages.
///
/// Requirements: 19.1, 19.2, 19.3, 19.4
class CustomerTimelineScreen extends ConsumerWidget {
  const CustomerTimelineScreen({super.key});

  static const _brandTeal = Color(0xFF00D1DC);

  /// The 13 stages in order (matching backend enum values).
  static const _stageKeys = [
    'discussion',
    'site_measurement',
    'quotation',
    'design',
    'material_procurement',
    'fabrication',
    'surface_treatment',
    'installation',
    'carpentry',
    'painting',
    'cleaning',
    'final_inspection',
    'handover',
  ];

  /// Human-readable labels for each stage.
  static const _stageLabels = {
    'discussion': 'Discussion',
    'site_measurement': 'Site Measurement',
    'quotation': 'Quotation',
    'design': 'Design',
    'material_procurement': 'Material Procurement',
    'fabrication': 'Fabrication',
    'surface_treatment': 'Surface Treatment',
    'installation': 'Installation',
    'carpentry': 'Carpentry',
    'painting': 'Painting',
    'cleaning': 'Cleaning',
    'final_inspection': 'Final Inspection',
    'handover': 'Handover',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(customerTimelineProvider);
    final overviewAsync = ref.watch(customerOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Timeline'),
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'Failed to load timeline',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.invalidate(customerOverviewProvider);
                    ref.invalidate(customerTimelineProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (overview) {
          final currentStage = (overview['current_stage'] as String?) ?? '';

          return timelineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load timeline data',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(customerTimelineProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (timelineEntries) {
              // Build a map of stage → earliest changed_at date from API data
              final stageDates = <String, String>{};
              for (final entry in timelineEntries) {
                final stage = entry['stage'] as String? ?? '';
                final changedAt = entry['changed_at'] as String? ?? '';
                if (stage.isNotEmpty &&
                    changedAt.isNotEmpty &&
                    !stageDates.containsKey(stage)) {
                  stageDates[stage] = changedAt;
                }
              }

              // Determine the index of the current stage
              final currentIdx = _stageKeys.indexOf(currentStage);

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(customerOverviewProvider);
                  ref.invalidate(customerTimelineProvider);
                },
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: _stageKeys.length,
                  itemBuilder: (context, index) {
                    final stageKey = _stageKeys[index];
                    final label = _stageLabels[stageKey] ?? stageKey;
                    final isLast = index == _stageKeys.length - 1;

                    // Determine stage status
                    _StageStatus status;
                    if (currentIdx >= 0 && index < currentIdx) {
                      status = _StageStatus.completed;
                    } else if (index == currentIdx) {
                      status = _StageStatus.current;
                    } else {
                      status = _StageStatus.upcoming;
                    }

                    // Also mark as completed if we have timeline data for it
                    // and it's before or at the current stage
                    if (stageDates.containsKey(stageKey) &&
                        status == _StageStatus.upcoming &&
                        currentIdx < 0) {
                      // If no current_stage set but we have data, use dates
                      status = _StageStatus.completed;
                    }

                    final dateStr = stageDates[stageKey];

                    return _TimelineItem(
                      label: label,
                      status: status,
                      dateStr: dateStr,
                      isLast: isLast,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _StageStatus { completed, current, upcoming }

/// A single row in the vertical timeline.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.status,
    required this.isLast,
    this.dateStr,
  });

  final String label;
  final _StageStatus status;
  final String? dateStr;
  final bool isLast;

  static const _brandTeal = Color(0xFF00D1DC);
  static const _completedColor = Color(0xFF00D1DC);
  static const _upcomingColor = Color(0xFFBDBDBD);

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector column (dot + line)
          SizedBox(
            width: 40,
            child: Column(
              children: [
                const SizedBox(height: 4),
                _buildIndicator(),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: status == _StageStatus.upcoming
                          ? _upcomingColor.withValues(alpha: 0.4)
                          : _completedColor.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: status == _StageStatus.current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: status == _StageStatus.upcoming
                          ? Colors.grey
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (status == _StageStatus.completed && dateStr != null)
                    Text(
                      _formatDate(dateStr!),
                      style: TextStyle(
                        fontSize: 12,
                        color: _brandTeal.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (status == _StageStatus.current)
                    const Row(
                      children: [
                        _PulsingDot(color: _brandTeal),
                        SizedBox(width: 6),
                        Text(
                          'In Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: _brandTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else if (status == _StageStatus.upcoming && dateStr != null)
                    Text(
                      'Planned: ${_formatDate(dateStr!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )
                  else if (status == _StageStatus.upcoming)
                    const Text(
                      'Upcoming',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    switch (status) {
      case _StageStatus.completed:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: _completedColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        );
      case _StageStatus.current:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _brandTeal.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: _brandTeal, width: 2.5),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: _brandTeal,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _StageStatus.upcoming:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: _upcomingColor, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _upcomingColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
    }
  }
}

/// A small dot that pulses (scales in and out) to indicate the current stage.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
