import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/customer_dio_client.dart';
import '../../../core/utils/formatters.dart';
import '../../customer_auth/application/customer_auth_controller.dart';
import '../application/customer_providers.dart';
import '../theme/portal_theme.dart';

/// Premium customer home dashboard.
///
/// Hero progress card → today's pulse → recent photos → project journey
/// preview → payment summary → strategic message → about. Pull-to-refresh.
/// All data fetching (providers) and the logout flow are preserved exactly.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  /// The 13 standard project stages in order.
  static const stages = [
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
    return Scaffold(
      backgroundColor: PortalColors.neutral,
      body: RefreshIndicator(
        color: PortalColors.primary,
        onRefresh: () async {
          ref.invalidate(customerOverviewProvider);
          ref.invalidate(customerPhotosProvider);
          ref.invalidate(customerTimelineProvider);
          ref.invalidate(customerPaymentSummaryProvider);
          ref.invalidate(customerMessagesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _StaggerIn(order: 0, child: _HeroCard(ref: ref)),
            _StaggerIn(order: 1, child: _TodaysPulse(ref: ref)),
            _StaggerIn(order: 2, child: _PhotosSection(ref: ref)),
            _StaggerIn(order: 3, child: _JourneyPreview(ref: ref)),
            _StaggerIn(order: 4, child: _PaymentSection(ref: ref)),
            const _StaggerIn(order: 5, child: _StrategicSection()),
            const _StaggerIn(order: 6, child: _AboutSection()),
            const SizedBox(height: 100),
          ],
        ),
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
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PortalColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: PortalText.heading(size: 18)),
        content: Text(
          'Log out of customer portal?',
          style: PortalText.body(color: PortalColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: PortalText.body(color: PortalColors.textSoft),),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: overview.when(
        loading: () => _shell(
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        error: (e, _) => _shell(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text('Unable to load project info',
                  style: PortalText.body(color: Colors.white),),
              TextButton(
                onPressed: () => ref.invalidate(customerOverviewProvider),
                child:
                    Text('Retry', style: PortalText.body(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (data) {
          final projectName =
              data['project_name']?.toString() ?? 'Your Project';
          final customerName = data['customer_name']?.toString() ?? '';
          final currentStage = data['current_stage']?.toString() ?? '';
          final stageLabel = Formatters.stageLabel(currentStage);
          final expectedDate = data['expected_completion']?.toString();
          final city = data['city']?.toString();

          final stageIndex = CustomerHomeScreen.stages.indexOf(currentStage);
          final progress = stageIndex >= 0
              ? (stageIndex + 1) / CustomerHomeScreen.stages.length
              : 0.0;

          return _shell(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(),
                              style: PortalText.body(
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.8),),),
                          const SizedBox(height: 4),
                          Text(
                            customerName.isNotEmpty
                                ? '$customerName 🌅'
                                : 'Welcome 🌅',
                            style:
                                PortalText.hero(size: 26, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            city != null && city.isNotEmpty
                                ? '$projectName — $city'
                                : projectName,
                            style: PortalText.body(
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.8),),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 20,),
                      tooltip: 'Logout',
                      onPressed: () => _handleLogout(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Overall Progress',
                        style: PortalText.label(
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.7),),),
                    const Spacer(),
                    _pill('On Track', PortalColors.success),
                  ],
                ),
                const SizedBox(height: 10),
                PortalProgressBar(
                  value: progress,
                  height: 6,
                  color: Colors.white,
                  trackColor: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 8),
                AnimatedNumber(
                  value: (progress * 100),
                  suffix: '%',
                  style: PortalText.number(size: 28, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(Icons.engineering, stageLabel),
                    if (expectedDate != null && expectedDate.isNotEmpty)
                      _chip(Icons.calendar_today, 'Expected: $expectedDate'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shell(Widget child) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: PortalColors.heroGradient,
          boxShadow: [
            BoxShadow(
              color: PortalColors.primary.withValues(alpha: 0.3),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: PortalText.label(size: 11, color: Colors.white)
                .copyWith(fontWeight: FontWeight.w600),),
      );

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 6),
            Text(label,
                style: PortalText.label(size: 11, color: Colors.white)
                    .copyWith(fontWeight: FontWeight.w600),),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Today's Pulse — 3 quick stat chips (horizontal scroll)
// ---------------------------------------------------------------------------

class _TodaysPulse extends StatelessWidget {
  const _TodaysPulse({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(customerPhotosProvider);

    final todayCount = photos.maybeWhen(
      data: (list) {
        final now = DateTime.now();
        return list.where((p) {
          final c = (p as Map)['created_at']?.toString();
          if (c == null) return false;
          final d = DateTime.tryParse(c);
          return d != null &&
              d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        }).length;
      },
      orElse: () => 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _pulseChip('📸', '$todayCount Photos today'),
            const SizedBox(width: 10),
            _pulseChip('🔨', 'Stage update'),
            const SizedBox(width: 10),
            _pulseChip('✅', 'On schedule'),
          ],
        ),
      ),
    );
  }

  Widget _pulseChip(String emoji, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: PortalColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: PortalColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: PortalText.label(size: 12)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Recent Site Photos
// ---------------------------------------------------------------------------

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({required this.ref});
  final WidgetRef ref;

  bool _isToday(String? iso) {
    if (iso == null) return false;
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(customerPhotosProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Site photos', style: PortalText.heading(size: 16)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/customer/photos'),
                child: Text('View all →',
                    style: PortalText.label(
                        size: 13, color: PortalColors.primary,),),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: photos.when(
              loading: () => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) =>
                    const PortalShimmer(width: 100, height: 80, radius: 12),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) {
                  return Text('No photos shared yet',
                      style: PortalText.caption(),);
                }
                final latest = list.take(10).toList();
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: latest.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final photo = latest[index] as Map<String, dynamic>;
                    final url = photo['url']?.toString() ?? '';
                    final today =
                        index == 0 && _isToday(photo['created_at']?.toString());
                    return _PhotoThumb(
                      url: url,
                      showToday: today,
                      order: index,
                      onTap: () => context.go('/customer/photos'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.url,
    required this.showToday,
    required this.order,
    required this.onTap,
  });

  final String url;
  final bool showToday;
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                url,
                width: 100,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 100,
                  height: 80,
                  color: PortalColors.shimmer1,
                  child: const Icon(Icons.broken_image_outlined,
                      color: PortalColors.textSoft,),
                ),
              ),
              if (showToday)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: PortalColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Today',
                        style:
                            PortalText.caption(size: 10, color: Colors.white),),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Project Journey Preview (prev / current / next)
// ---------------------------------------------------------------------------

class _JourneyPreview extends StatelessWidget {
  const _JourneyPreview({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(customerOverviewProvider);

    return overview.maybeWhen(
      data: (data) {
        final currentStage = data['current_stage']?.toString() ?? '';
        final idx = CustomerHomeScreen.stages.indexOf(currentStage);
        if (idx < 0) return const SizedBox.shrink();

        final rows = <Widget>[];
        if (idx > 0) {
          rows.add(_stageRow(
            Formatters.stageLabel(CustomerHomeScreen.stages[idx - 1]),
            _JStatus.done,
            isLast: false,
          ),);
        }
        rows.add(_stageRow(
          Formatters.stageLabel(currentStage),
          _JStatus.current,
          isLast: idx >= CustomerHomeScreen.stages.length - 1,
        ),);
        if (idx < CustomerHomeScreen.stages.length - 1) {
          rows.add(_stageRow(
            Formatters.stageLabel(CustomerHomeScreen.stages[idx + 1]),
            _JStatus.upcoming,
            isLast: true,
          ),);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: PortalCard(
            elevation: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Project journey',
                        style: PortalText.heading(size: 16),),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/customer/timeline'),
                      child: Text('Full timeline →',
                          style: PortalText.label(
                              size: 13, color: PortalColors.primary,),),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...rows,
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _stageRow(String label, _JStatus status, {required bool isLast}) {
    Widget dot;
    Color textColor;
    FontWeight weight;
    switch (status) {
      case _JStatus.done:
        dot = const Icon(Icons.check_circle,
            color: PortalColors.primary, size: 24,);
        textColor = PortalColors.textSoft;
        weight = FontWeight.w500;
      case _JStatus.current:
        dot = const PortalPulseDot(size: 14);
        textColor = PortalColors.text;
        weight = FontWeight.w700;
      case _JStatus.upcoming:
        dot = Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: PortalColors.border, width: 2),
          ),
        );
        textColor = PortalColors.textSoft;
        weight = FontWeight.w500;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(child: dot),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: status == _JStatus.upcoming
                          ? PortalColors.border
                          : PortalColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: PortalText.body(size: 14, color: textColor)
                            .copyWith(fontWeight: weight),),
                  ),
                  if (status == _JStatus.current)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4,),
                      decoration: BoxDecoration(
                        color: PortalColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('In Progress',
                          style: PortalText.caption(
                              size: 10, color: PortalColors.primary,),),
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

enum _JStatus { done, current, upcoming }

// ---------------------------------------------------------------------------
// Payment Summary
// ---------------------------------------------------------------------------

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(customerPaymentSummaryProvider);

    return payments.maybeWhen(
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: PortalCard(
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Payment summary',
                        style: PortalText.heading(size: 16),),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/customer/payments'),
                      child: Text('Details →',
                          style: PortalText.label(
                              size: 13, color: PortalColors.primary,),),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PortalProgressBar(
                    value: percent, color: PortalColors.success, height: 10,),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _money(Formatters.currency(received), 'Paid',
                          PortalColors.primary,),
                    ),
                    Expanded(
                      child: _money(Formatters.currency(outstanding),
                          'Outstanding', PortalColors.accent,),
                    ),
                    Expanded(
                      child: _money(Formatters.currency(quotation), 'Contract',
                          PortalColors.text,),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _money(String value, String label, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: PortalText.body(size: 18, color: color)
                    .copyWith(fontWeight: FontWeight.w700),),
          ),
          const SizedBox(height: 2),
          Text(label, style: PortalText.caption()),
        ],
      );
}

// ---------------------------------------------------------------------------
// Strategic Message
// ---------------------------------------------------------------------------

class _StrategicSection extends StatelessWidget {
  const _StrategicSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PortalColors.neutral,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: PortalColors.primary, width: 3),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote_rounded,
                color: PortalColors.primary, size: 18,),
            SizedBox(width: 10),
            Expanded(child: StrategicMessage()),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About (collapsible)
// ---------------------------------------------------------------------------

class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Text('About us', style: PortalText.heading(size: 16)),
                Icon(
                    _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: PortalColors.textSoft,),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We are not just interior designers.\nWe are dream architects.',
                    style: PortalText.body(size: 14),
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    children: [
                      _Stat('10+', 'Years'),
                      _Stat('500+', 'Homes'),
                      _Stat('Premium', 'Quality'),
                      _Stat('On-Time', 'Delivery'),
                      _Stat('Lifetime', 'Support'),
                    ],
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

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: PortalText.body(size: 18, color: PortalColors.primary)
                .copyWith(fontWeight: FontWeight.w700),),
        Text(label, style: PortalText.caption()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Staggered entrance (100ms intervals)
// ---------------------------------------------------------------------------

class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.order, required this.child});
  final int order;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
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
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 100 * widget.order), () {
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
