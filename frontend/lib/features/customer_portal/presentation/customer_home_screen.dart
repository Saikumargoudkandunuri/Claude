import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/customer_providers.dart';

/// Customer home screen with hero card, photos, stage strip, payments, and messages.
///
/// Uses [RefreshIndicator] wrapping a [CustomScrollView] so the customer can
/// pull-to-refresh all data at once.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  static const _brandTeal = Color(0xFF00D1DC);
  static const _brandTealDark = Color(0xFF0097A7);

  /// The 13 standard project stages in order.
  static const _stages = [
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: _brandTeal,
      onRefresh: () async {
        ref.invalidate(customerOverviewProvider);
        ref.invalidate(customerPhotosProvider);
        ref.invalidate(customerTimelineProvider);
        ref.invalidate(customerPaymentSummaryProvider);
        ref.invalidate(customerMessagesProvider);
      },
      child: CustomScrollView(
        slivers: [
          // Hero progress card
          SliverToBoxAdapter(child: _HeroCard(ref: ref)),
          // Latest photos section
          SliverToBoxAdapter(child: _PhotosSection(ref: ref)),
          // Stage strip
          SliverToBoxAdapter(child: _StageStrip(ref: ref)),
          // Payment summary
          SliverToBoxAdapter(child: _PaymentSection(ref: ref)),
          // Recent messages
          SliverToBoxAdapter(child: _MessagesSection(ref: ref)),
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxl),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Card
// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(customerOverviewProvider);

    return overview.when(
      loading: () => Container(
        height: 180,
        margin: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          gradient: const LinearGradient(
            colors: [
              CustomerHomeScreen._brandTeal,
              CustomerHomeScreen._brandTealDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ErrorView(
          message: 'Unable to load project info',
          onRetry: () => ref.invalidate(customerOverviewProvider),
        ),
      ),
      data: (data) {
        final projectName = data['project_name']?.toString() ?? 'Your Project';
        final currentStage = data['current_stage']?.toString() ?? '';
        final stageLabel = Formatters.stageLabel(currentStage);

        return Container(
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            gradient: const LinearGradient(
              colors: [
                CustomerHomeScreen._brandTeal,
                CustomerHomeScreen._brandTealDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: CustomerHomeScreen._brandTeal.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projectName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Current Stage: $stageLabel',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Stage progress indicator
              _StageProgressBar(currentStage: currentStage),
            ],
          ),
        );
      },
    );
  }
}

class _StageProgressBar extends StatelessWidget {
  const _StageProgressBar({required this.currentStage});
  final String currentStage;

  @override
  Widget build(BuildContext context) {
    final stageIndex = CustomerHomeScreen._stages.indexOf(currentStage);
    final progress = stageIndex >= 0
        ? (stageIndex + 1) / CustomerHomeScreen._stages.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).round()}%',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Latest Photos Section
// ---------------------------------------------------------------------------

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(customerPhotosProvider);

    return photos.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (photoList) {
        if (photoList.isEmpty) return const SizedBox.shrink();
        final latest = photoList.take(10).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Latest Photos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: latest.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final photo = latest[index] as Map<String, dynamic>;
                    final url = photo['url']?.toString() ?? '';

                    return GestureDetector(
                      onTap: () => _showFullPhoto(context, url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        child: Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.border,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  void _showFullPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stage Strip — Horizontal scrollable 13-stage progression
// ---------------------------------------------------------------------------

class _StageStrip extends StatelessWidget {
  const _StageStrip({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(customerTimelineProvider);

    return timeline.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stages) {
        // Build a set of completed/current stages from timeline data
        final completedStages = <String>{};
        String? currentStage;

        for (final s in stages) {
          final stage = (s as Map<String, dynamic>)['stage']?.toString() ?? '';
          final isCurrent = s['is_current'] == true;
          final completedAt = s['completed_at'];

          if (isCurrent) {
            currentStage = stage;
          }
          if (completedAt != null) {
            completedStages.add(stage);
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Project Stages',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CustomerHomeScreen._stages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 2),
                  itemBuilder: (context, index) {
                    final stage = CustomerHomeScreen._stages[index];
                    final isCompleted = completedStages.contains(stage);
                    final isCurrent = stage == currentStage;

                    return _StageChipItem(
                      label: Formatters.stageLabel(stage),
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

class _StageChipItem extends StatelessWidget {
  const _StageChipItem({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData? icon;

    if (isCompleted) {
      bgColor = AppColors.success.withValues(alpha: 0.1);
      textColor = AppColors.success;
      icon = Icons.check_circle;
    } else if (isCurrent) {
      bgColor = CustomerHomeScreen._brandTeal.withValues(alpha: 0.15);
      textColor = CustomerHomeScreen._brandTeal;
      icon = Icons.radio_button_checked;
    } else {
      bgColor = AppColors.border.withValues(alpha: 0.5);
      textColor = AppColors.textMuted;
      icon = Icons.circle_outlined;
    }

    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment Summary Section
// ---------------------------------------------------------------------------

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(customerPaymentSummaryProvider);

    return payments.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final quotation = (data['total_quoted'] as num?) ?? 0;
        final received = (data['total_received'] as num?) ?? 0;
        final outstanding = (data['outstanding'] as num?) ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentItem(
                          label: 'Quotation',
                          value: Formatters.currency(quotation),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: _PaymentItem(
                          label: 'Received',
                          value: Formatters.currency(received),
                          color: AppColors.success,
                        ),
                      ),
                      Expanded(
                        child: _PaymentItem(
                          label: 'Outstanding',
                          value: Formatters.currency(outstanding),
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Progress bar showing received / quotation
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: quotation > 0
                          ? (received / quotation).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentItem extends StatelessWidget {
  const _PaymentItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Messages Section
// ---------------------------------------------------------------------------

class _MessagesSection extends StatelessWidget {
  const _MessagesSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(customerMessagesProvider);

    return messages.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (msgList) {
        if (msgList.isEmpty) return const SizedBox.shrink();
        final latest = msgList.take(3).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Messages',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final msg in latest)
                _MessageTile(message: msg as Map<String, dynamic>),
            ],
          ),
        );
      },
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final body = message['message']?.toString() ?? '';
    final createdAt = message['created_at']?.toString();
    final isRead = message['is_read'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread,
              size: 20,
              color:
                  isRead ? AppColors.textMuted : CustomerHomeScreen._brandTeal,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      Formatters.dateTime(createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
