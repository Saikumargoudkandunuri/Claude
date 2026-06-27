import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/customer_providers.dart';
import '../theme/portal_theme.dart';
import 'milestone_celebration_overlay.dart';

/// Vertical project journey — all 13 stages as premium cards with completed,
/// current (pulsing), and future visual states. Data fetching preserved.
class CustomerTimelineScreen extends ConsumerWidget {
  const CustomerTimelineScreen({super.key});

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
      backgroundColor: PortalColors.neutral,
      appBar: AppBar(
        title: Text('Project Journey', style: PortalText.heading(size: 20)),
        backgroundColor: PortalColors.cardBg,
        foregroundColor: PortalColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: overviewAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: PortalColors.primary),
        ),
        error: (e, _) => _error(
          'Failed to load timeline',
          () {
            ref.invalidate(customerOverviewProvider);
            ref.invalidate(customerTimelineProvider);
          },
        ),
        data: (overview) {
          final currentStage = (overview['current_stage'] as String?) ?? '';

          return timelineAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: PortalColors.primary),
            ),
            error: (e, _) => _error('Failed to load timeline data',
                () => ref.invalidate(customerTimelineProvider),),
            data: (timelineEntries) {
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

              final currentIdx = _stageKeys.indexOf(currentStage);

              return RefreshIndicator(
                color: PortalColors.primary,
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
                    final nextLabel = index < _stageKeys.length - 1
                        ? (_stageLabels[_stageKeys[index + 1]] ?? '')
                        : '';

                    return _StaggeredItem(
                      index: index,
                      child: _TimelineItem(
                        label: label,
                        status: status,
                        dateStr: dateStr,
                        nextLabel: nextLabel,
                        isLast: isLast,
                        onTap: () => _maybeCelebrate(
                          context,
                          stageKey: stageKey,
                          label: label,
                          nextLabel: nextLabel,
                          dateStr: dateStr,
                          status: status,
                        ),
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

  Future<void> _maybeCelebrate(
    BuildContext context, {
    required String stageKey,
    required String label,
    required String nextLabel,
    required String? dateStr,
    required _StageStatus status,
  }) async {
    if (status != _StageStatus.completed || dateStr == null) return;
    final completedAt = DateTime.tryParse(dateStr);
    if (completedAt == null) return;
    if (DateTime.now().difference(completedAt).inHours > 24) return;

    await MilestoneCelebrationOverlay.showOnce(
      context,
      stageKey: stageKey,
      stageName: label,
      nextStageName: nextLabel,
      completedOn: DateFormat('d MMM yyyy').format(completedAt),
    );
  }

  Widget _error(String message, VoidCallback onRetry) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: PortalColors.textSoft,),
            const SizedBox(height: 12),
            Text(message, style: PortalText.body(color: PortalColors.textSoft)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: PortalText.body(color: PortalColors.primary),),
            ),
          ],
        ),
      );
}

enum _StageStatus { completed, current, upcoming }

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.status,
    required this.isLast,
    required this.nextLabel,
    required this.onTap,
    this.dateStr,
  });

  final String label;
  final _StageStatus status;
  final String? dateStr;
  final String nextLabel;
  final bool isLast;
  final VoidCallback onTap;

  String _formatDate(String iso) {
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
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
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 4),
                _buildIndicator(),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: status == _StageStatus.upcoming
                          ? PortalColors.border
                          : PortalColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _card()),
        ],
      ),
    );
  }

  Widget _card() {
    switch (status) {
      case _StageStatus.completed:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FFFE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PortalColors.primary, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: PortalText.heading(
                      size: 15, color: PortalColors.primaryDark,),),
              const SizedBox(height: 4),
              Text(
                dateStr != null
                    ? 'Completed on ${_formatDate(dateStr!)}'
                    : 'Completed',
                style: PortalText.caption(size: 12),
              ),
            ],
          ),
        );
      case _StageStatus.current:
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PortalColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PortalColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: PortalColors.primary.withValues(alpha: 0.125),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: PortalText.heading(size: 16)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4,),
                      decoration: BoxDecoration(
                        color: PortalColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('In Progress',
                          style: PortalText.caption(
                              size: 11, color: Colors.white,),),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Work is actively underway at your site.',
                    style: PortalText.caption(size: 12),),
                if (nextLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Next: $nextLabel',
                      style: PortalText.caption(size: 11)
                          .copyWith(fontStyle: FontStyle.italic),),
                ],
              ],
            ),
          ),
        );
      case _StageStatus.upcoming:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PortalColors.border),
          ),
          child: Text(label,
              style: PortalText.body(size: 14, color: PortalColors.textSoft),),
        );
    }
  }

  Widget _buildIndicator() {
    switch (status) {
      case _StageStatus.completed:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: PortalColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 15),
        );
      case _StageStatus.current:
        return const SizedBox(
          width: 28,
          height: 28,
          child: Center(child: PortalPulseDot(size: 14)),
        );
      case _StageStatus.upcoming:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: PortalColors.neutral,
            shape: BoxShape.circle,
            border: Border.all(color: PortalColors.border, width: 1.5),
          ),
        );
    }
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
