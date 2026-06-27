import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/customer_providers.dart';
import '../theme/customer_theme.dart';

/// Vertical timeline showing all 13 project stages with visual distinction
/// between completed, current, and upcoming stages.
class CustomerTimelineScreen extends ConsumerWidget {
  const CustomerTimelineScreen({super.key});

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
      backgroundColor: CTheme.bgSoft,
      appBar: AppBar(
        title: const Text(
          'Project Journey',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: CTheme.textDark,
          ),
        ),
        backgroundColor: CTheme.bgWhite,
        foregroundColor: CTheme.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: overviewAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CTheme.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(CTheme.p24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: CTheme.textLight),
                const SizedBox(height: CTheme.p12),
                const Text(
                  'Failed to load timeline',
                  style: TextStyle(color: CTheme.textMid),
                ),
                const SizedBox(height: CTheme.p8),
                TextButton(
                  onPressed: () {
                    ref.invalidate(customerOverviewProvider);
                    ref.invalidate(customerTimelineProvider);
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: CTheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (overview) {
          final currentStage = (overview['current_stage'] as String?) ?? '';

          return timelineAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: CTheme.primary),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: CTheme.textLight,
                  ),
                  const SizedBox(height: CTheme.p12),
                  const Text(
                    'Failed to load timeline data',
                    style: TextStyle(color: CTheme.textMid),
                  ),
                  const SizedBox(height: CTheme.p8),
                  TextButton(
                    onPressed: () => ref.invalidate(customerTimelineProvider),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: CTheme.primary),
                    ),
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
                color: CTheme.primary,
                onRefresh: () async {
                  ref.invalidate(customerOverviewProvider);
                  ref.invalidate(customerTimelineProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CTheme.p20,
                    vertical: CTheme.p24,
                  ),
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

                    if (stageDates.containsKey(stageKey) &&
                        status == _StageStatus.upcoming &&
                        currentIdx < 0) {
                      status = _StageStatus.completed;
                    }

                    final dateStr = stageDates[stageKey];

                    return _StaggeredItem(
                      index: index,
                      child: _TimelineItem(
                        label: label,
                        status: status,
                        dateStr: dateStr,
                        isLast: isLast,
                      ),
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
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 4),
                _buildIndicator(),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: status == _StageStatus.upcoming
                          ? CTheme.inactive
                          : CTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: CTheme.p12),
          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: CTheme.p12),
              padding: const EdgeInsets.all(CTheme.p16),
              decoration: BoxDecoration(
                color: CTheme.bgWhite,
                borderRadius: CTheme.r12,
                boxShadow: CTheme.cardShadow,
                border: status == _StageStatus.current
                    ? Border.all(color: CTheme.primary, width: 1.5)
                    : null,
              ),
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
                          ? CTheme.textLight
                          : CTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: CTheme.p4),
                  if (status == _StageStatus.completed && dateStr != null)
                    Text(
                      _formatDate(dateStr!),
                      style: TextStyle(
                        fontSize: 12,
                        color: CTheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (status == _StageStatus.current)
                    Row(
                      children: [
                        _PulsingDot(color: CTheme.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Work in progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: CTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else if (status == _StageStatus.upcoming)
                    const Text(
                      'Upcoming',
                      style: TextStyle(
                        fontSize: 12,
                        color: CTheme.textLight,
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
            color: CTheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: CTheme.bgWhite, size: 16),
        );
      case _StageStatus.current:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: CTheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: CTheme.primary, width: 2.5),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: CTheme.primary,
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
            color: CTheme.bgSoft,
            shape: BoxShape.circle,
            border: Border.all(color: CTheme.inactive, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: CTheme.inactive,
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

/// Stagger animation wrapper — each item appears with 80ms delay.
class _StaggeredItem extends StatefulWidget {
  const _StaggeredItem({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
