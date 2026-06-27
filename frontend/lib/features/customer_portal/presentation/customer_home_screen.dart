import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/customer_dio_client.dart';
import '../../../core/utils/formatters.dart';
import '../../customer_auth/application/customer_auth_controller.dart';
import '../application/customer_providers.dart';
import '../theme/customer_theme.dart';

/// Customer home screen with hero card, today's update, photos, mini timeline,
/// and payment summary. Pull-to-refresh. No AppBar — hero card IS the header.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

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
      color: CTheme.primary,
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
          // Today's update
          SliverToBoxAdapter(child: _TodaysUpdate(ref: ref)),
          // Latest photos section
          SliverToBoxAdapter(child: _PhotosSection(ref: ref)),
          // Mini timeline
          SliverToBoxAdapter(child: _MiniTimeline(ref: ref)),
          // Payment summary
          SliverToBoxAdapter(child: _PaymentSection(ref: ref)),
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: CTheme.r16),
        title: const Text('Logout', style: TextStyle(color: CTheme.textDark)),
        content: const Text(
          'Log out of customer portal?',
          style: TextStyle(color: CTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: CTheme.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await CustomerDioClient.clearToken();
    ref.read(customerAuthControllerProvider.notifier).logout();

    ref.invalidate(customerOverviewProvider);
    ref.invalidate(customerTimelineProvider);
    ref.invalidate(customerPhotosProvider);
    ref.invalidate(customerDrawingsProvider);
    ref.invalidate(customerPaymentSummaryProvider);
    ref.invalidate(customerNotificationsProvider);
    ref.invalidate(customerMessagesProvider);

    if (context.mounted) {
      context.go('/customer-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(customerOverviewProvider);

    return overview.when(
      loading: () => Container(
        height: 200,
        margin: const EdgeInsets.all(CTheme.p16),
        decoration: BoxDecoration(
          borderRadius: CTheme.r24,
          gradient: CTheme.heroGradient,
        ),
        child: const Center(
          child: CircularProgressIndicator(color: CTheme.bgWhite),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(CTheme.p16),
        child: Container(
          padding: const EdgeInsets.all(CTheme.p24),
          decoration: BoxDecoration(
            borderRadius: CTheme.r24,
            gradient: CTheme.heroGradient,
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: CTheme.bgWhite, size: 32),
              const SizedBox(height: CTheme.p8),
              const Text(
                'Unable to load project info',
                style: TextStyle(color: CTheme.bgWhite, fontSize: 14),
              ),
              const SizedBox(height: CTheme.p8),
              TextButton(
                onPressed: () => ref.invalidate(customerOverviewProvider),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: CTheme.bgWhite),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final projectName = data['project_name']?.toString() ?? 'Your Project';
        final customerName = data['customer_name']?.toString() ?? '';
        final currentStage = data['current_stage']?.toString() ?? '';
        final stageLabel = Formatters.stageLabel(currentStage);
        final expectedDate = data['expected_completion']?.toString();

        final stageIndex = CustomerHomeScreen._stages.indexOf(currentStage);
        final progress = stageIndex >= 0
            ? (stageIndex + 1) / CustomerHomeScreen._stages.length
            : 0.0;

        return _FadeSlideIn(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              CTheme.p16,
              CTheme.p16,
              CTheme.p16,
              CTheme.p8,
            ),
            padding: const EdgeInsets.all(CTheme.p24),
            decoration: BoxDecoration(
              borderRadius: CTheme.r24,
              gradient: CTheme.heroGradient,
              boxShadow: CTheme.heroShadow,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        color: CTheme.bgWhite.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: CTheme.p4),
                    Text(
                      customerName.isNotEmpty ? customerName : 'Customer',
                      style: const TextStyle(
                        color: CTheme.bgWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: CTheme.p4),
                    Text(
                      projectName,
                      style: TextStyle(
                        color: CTheme.bgWhite.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: CTheme.p20),
                    // Progress bar
                    ClipRRect(
                      borderRadius: CTheme.r8,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: CTheme.bgWhite.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          CTheme.bgWhite,
                        ),
                      ),
                    ),
                    const SizedBox(height: CTheme.p12),
                    // Badges
                    Row(
                      children: [
                        _Badge(label: stageLabel, icon: Icons.engineering),
                        const SizedBox(width: CTheme.p8),
                        if (expectedDate != null)
                          _Badge(
                            label: expectedDate,
                            icon: Icons.calendar_today,
                          ),
                        const Spacer(),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: CTheme.bgWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Logout icon top-right
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    icon: Icon(
                      Icons.logout_rounded,
                      color: CTheme.bgWhite.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    tooltip: 'Logout',
                    onPressed: () => _handleLogout(context, ref),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CTheme.p8,
        vertical: CTheme.p4,
      ),
      decoration: BoxDecoration(
        color: CTheme.bgWhite.withValues(alpha: 0.2),
        borderRadius: CTheme.r8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: CTheme.bgWhite, size: 12),
          const SizedBox(width: CTheme.p4),
          Text(
            label,
            style: const TextStyle(
              color: CTheme.bgWhite,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's Update
// ---------------------------------------------------------------------------

class _TodaysUpdate extends StatelessWidget {
  const _TodaysUpdate({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(customerMessagesProvider);

    return messages.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (msgList) {
        if (msgList.isEmpty) return const SizedBox.shrink();
        final latest = msgList.first as Map<String, dynamic>;
        final body =
            latest['body']?.toString() ?? latest['message']?.toString() ?? '';
        if (body.isEmpty) return const SizedBox.shrink();

        return _FadeSlideIn(
          delay: const Duration(milliseconds: 100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CTheme.p16),
            child: Container(
              padding: const EdgeInsets.all(CTheme.p16),
              decoration: BoxDecoration(
                color: CTheme.bgWhite,
                borderRadius: CTheme.r16,
                boxShadow: CTheme.cardShadow,
                border: Border.all(
                  color: CTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CTheme.primary.withValues(alpha: 0.1),
                      borderRadius: CTheme.r8,
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: CTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: CTheme.p12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Update",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CTheme.primary,
                          ),
                        ),
                        const SizedBox(height: CTheme.p4),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CTheme.textMid,
                          ),
                        ),
                      ],
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

        return _FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CTheme.p16,
              CTheme.p20,
              CTheme.p16,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site Photos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CTheme.textDark,
                  ),
                ),
                const SizedBox(height: CTheme.p12),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: latest.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: CTheme.p12),
                    itemBuilder: (context, index) {
                      final photo = latest[index] as Map<String, dynamic>;
                      final url = photo['url']?.toString() ?? '';

                      return GestureDetector(
                        onTap: () => _showFullPhoto(context, url),
                        child: Container(
                          width: 140,
                          decoration: BoxDecoration(
                            borderRadius: CTheme.r16,
                            boxShadow: CTheme.cardShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: CTheme.r16,
                            child: Image.network(
                              url,
                              width: 140,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 140,
                                height: 150,
                                color: CTheme.bgSoft,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: CTheme.textLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
        insetPadding: const EdgeInsets.all(CTheme.p16),
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
// Mini Timeline (last done, current, next)
// ---------------------------------------------------------------------------

class _MiniTimeline extends StatelessWidget {
  const _MiniTimeline({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(customerTimelineProvider);
    final overview = ref.watch(customerOverviewProvider);

    return overview.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (overviewData) {
        final currentStage = overviewData['current_stage']?.toString() ?? '';
        final currentIdx = CustomerHomeScreen._stages.indexOf(currentStage);
        if (currentIdx < 0) return const SizedBox.shrink();

        return timeline.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (_) {
            final stages = <_MiniStageData>[];

            // Previous
            if (currentIdx > 0) {
              stages.add(_MiniStageData(
                label: Formatters.stageLabel(
                  CustomerHomeScreen._stages[currentIdx - 1],
                ),
                status: _MiniStatus.done,
              ));
            }

            // Current
            stages.add(_MiniStageData(
              label: Formatters.stageLabel(currentStage),
              status: _MiniStatus.current,
            ));

            // Next
            if (currentIdx < CustomerHomeScreen._stages.length - 1) {
              stages.add(_MiniStageData(
                label: Formatters.stageLabel(
                  CustomerHomeScreen._stages[currentIdx + 1],
                ),
                status: _MiniStatus.upcoming,
              ));
            }

            return _FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CTheme.p16,
                  CTheme.p20,
                  CTheme.p16,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(CTheme.p20),
                  decoration: BoxDecoration(
                    color: CTheme.bgWhite,
                    borderRadius: CTheme.r16,
                    boxShadow: CTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: CTheme.p16),
                      ...stages.map((s) => _MiniStageRow(data: s)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _MiniStatus { done, current, upcoming }

class _MiniStageData {
  const _MiniStageData({required this.label, required this.status});
  final String label;
  final _MiniStatus status;
}

class _MiniStageRow extends StatelessWidget {
  const _MiniStageRow({required this.data});
  final _MiniStageData data;

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color textColor;
    FontWeight weight;
    IconData? icon;

    switch (data.status) {
      case _MiniStatus.done:
        dotColor = CTheme.primary;
        textColor = CTheme.textMid;
        weight = FontWeight.w500;
        icon = Icons.check_circle;
      case _MiniStatus.current:
        dotColor = CTheme.primary;
        textColor = CTheme.textDark;
        weight = FontWeight.w700;
        icon = Icons.radio_button_checked;
      case _MiniStatus.upcoming:
        dotColor = CTheme.inactive;
        textColor = CTheme.textLight;
        weight = FontWeight.w500;
        icon = Icons.circle_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CTheme.p12),
      child: Row(
        children: [
          Icon(icon, color: dotColor, size: 20),
          const SizedBox(width: CTheme.p12),
          Expanded(
            child: Text(
              data.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: weight,
                color: textColor,
              ),
            ),
          ),
          if (data.status == _MiniStatus.current)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CTheme.p8,
                vertical: CTheme.p4,
              ),
              decoration: BoxDecoration(
                color: CTheme.primary.withValues(alpha: 0.1),
                borderRadius: CTheme.r8,
              ),
              child: const Text(
                'In Progress',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: CTheme.primary,
                ),
              ),
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
        final quotation = (data['total_quoted'] as num?) ??
            (data['quotation_amount'] as num?) ??
            0;
        final received = (data['total_received'] as num?) ?? 0;
        final outstanding = (data['outstanding'] as num?) ??
            (data['outstanding_balance'] as num?) ??
            0;

        if (quotation == 0 && received == 0) return const SizedBox.shrink();

        final percent =
            quotation > 0 ? (received / quotation).clamp(0.0, 1.0) : 0.0;

        return _FadeSlideIn(
          delay: const Duration(milliseconds: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CTheme.p16,
              CTheme.p20,
              CTheme.p16,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(CTheme.p20),
              decoration: BoxDecoration(
                color: CTheme.bgWhite,
                borderRadius: CTheme.r16,
                boxShadow: CTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Payment Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CTheme.textDark,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(percent * 100).round()}% paid',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CTheme.p16),
                  ClipRRect(
                    borderRadius: CTheme.r8,
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: CTheme.inactive,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(CTheme.success),
                    ),
                  ),
                  const SizedBox(height: CTheme.p16),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentMiniItem(
                          label: 'Received',
                          value: Formatters.currency(received),
                          color: CTheme.success,
                        ),
                      ),
                      Expanded(
                        child: _PaymentMiniItem(
                          label: 'Outstanding',
                          value: Formatters.currency(outstanding),
                          color: CTheme.warning,
                        ),
                      ),
                    ],
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

class _PaymentMiniItem extends StatelessWidget {
  const _PaymentMiniItem({
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: CTheme.textLight),
        ),
        const SizedBox(height: CTheme.p4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fade + Slide entrance animation
// ---------------------------------------------------------------------------

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
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
