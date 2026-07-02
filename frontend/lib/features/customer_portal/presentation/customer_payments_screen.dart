import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../application/customer_providers.dart';
import '../theme/portal_theme.dart';

/// Customer payment journey — a premium gradient summary card with an
/// animated progress tube and counting numbers, an optional payment timeline
/// (rendered only if the summary includes transactions), and trust
/// indicators. Data fetching preserved.
class CustomerPaymentsScreen extends ConsumerWidget {
  const CustomerPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerPaymentSummaryProvider);

    return Scaffold(
      backgroundColor: PortalColors.neutral,
      appBar: AppBar(
        title: Text('Payments', style: PortalText.heading(size: 20)),
        backgroundColor: PortalColors.cardBg,
        foregroundColor: PortalColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: PortalColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: PortalColors.textSoft,
              ),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                style: PortalText.caption(size: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(customerPaymentSummaryProvider),
                style: FilledButton.styleFrom(
                  backgroundColor: PortalColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final quotation = (data['quotation_amount'] as num?) ??
              (data['total_quoted'] as num?) ??
              0;
          final received = (data['total_received'] as num?) ?? 0;
          final outstanding = (data['outstanding_balance'] as num?) ??
              (data['outstanding'] as num?) ??
              0;

          if (quotation == 0 && received == 0 && outstanding == 0) {
            return const _EmptyState();
          }

          final percent =
              quotation > 0 ? (received / quotation).clamp(0.0, 1.0) : 0.0;

          final txns = (data['payments'] ??
              data['transactions'] ??
              data['recent']) as List<dynamic>?;

          return RefreshIndicator(
            color: PortalColors.primary,
            onRefresh: () async =>
                ref.invalidate(customerPaymentSummaryProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _JourneyCard(
                  quotation: quotation.toDouble(),
                  received: received.toDouble(),
                  outstanding: outstanding.toDouble(),
                  percent: percent,
                ),
                const SizedBox(height: 16),
                _GlassPaymentStats(
                  percent: percent,
                  outstanding: outstanding.toDouble(),
                  quotation: quotation.toDouble(),
                ),
                const SizedBox(height: 20),
                if (txns != null && txns.isNotEmpty) ...[
                  Text('Payment timeline', style: PortalText.heading(size: 16)),
                  const SizedBox(height: 12),
                  ...List.generate(txns.length, (i) {
                    final t = txns[i] as Map<String, dynamic>;
                    return _PaymentEntry(
                      data: t,
                      isLast: i == txns.length - 1,
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                const _TrustRow(),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.quotation,
    required this.received,
    required this.outstanding,
    required this.percent,
  });

  final double quotation;
  final double received;
  final double outstanding;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: PortalColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PortalColors.primary.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Journey',
            style: PortalText.heading(size: 20, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Contract value',
            style: PortalText.label(
              size: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedNumber(
            value: quotation,
            prefix: '₹',
            style: PortalText.number(size: 32, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${(percent * 100).round()}% paid',
              style: PortalText.label(size: 12, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          PortalProgressBar(
            value: percent,
            height: 12,
            color: PortalColors.success,
            trackColor: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _amount('Paid', received, Colors.white),
              ),
              Expanded(
                child: _amount(
                  'Outstanding',
                  outstanding,
                  PortalColors.accent,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amount(
    String label,
    double value,
    Color color, {
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedNumber(
            value: value,
            prefix: '₹',
            style: PortalText.body(size: 20, color: color)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: PortalText.caption(
            size: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _PaymentEntry extends StatelessWidget {
  const _PaymentEntry({required this.data, required this.isLast});
  final Map<String, dynamic> data;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final milestone =
        (data['milestone'] ?? data['title'] ?? data['note'] ?? 'Payment')
            .toString();
    final amount = (data['amount'] as num?) ?? 0;
    final dateRaw =
        (data['date'] ?? data['paid_at'] ?? data['created_at'])?.toString();
    final status = (data['status'] ?? '').toString().toLowerCase();
    final received = status.contains('receiv') ||
        status.contains('paid') ||
        status.contains('complete');

    String date = '';
    if (dateRaw != null) {
      final d = DateTime.tryParse(dateRaw);
      if (d != null) date = DateFormat('d MMM yyyy').format(d.toLocal());
    }

    final color = received ? PortalColors.primary : PortalColors.accent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: received ? PortalColors.primary : PortalColors.border,
                ),
                child: Icon(
                  Icons.currency_rupee,
                  size: 16,
                  color: received ? Colors.white : PortalColors.textSoft,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: PortalColors.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PortalCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestone,
                          style: PortalText.body(size: 14)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (received
                                  ? PortalColors.success
                                  : PortalColors.accent)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          received ? 'Received' : 'Upcoming',
                          style: PortalText.caption(
                            size: 11,
                            color: received
                                ? PortalColors.success
                                : PortalColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(date, style: PortalText.caption(size: 12)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    Formatters.currency(amount),
                    style: PortalText.body(size: 18, color: color)
                        .copyWith(fontWeight: FontWeight.w700),
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

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _trustItem(Icons.lock_outline_rounded, 'Secure'),
          _dot(),
          _trustItem(Icons.description_outlined, 'Transparent'),
          _dot(),
          _trustItem(Icons.verified_outlined, 'Verified'),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PortalColors.textSoft),
          const SizedBox(width: 5),
          Text(label, style: PortalText.caption(size: 12)),
        ],
      );

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('·', style: PortalText.caption(size: 12)),
      );
}

/// White glassmorphism stat row for the payments screen: a paid-progress ring
/// and an outstanding-balance sparkline. Values come from the payment summary
/// already loaded by the screen — no new API calls.
class _GlassPaymentStats extends StatelessWidget {
  const _GlassPaymentStats({
    required this.percent,
    required this.outstanding,
    required this.quotation,
  });

  final double percent; // 0.0–1.0 paid
  final double outstanding;
  final double quotation;

  String _formatCompact(num value) {
    final v = value.toDouble();
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final outFraction =
        quotation > 0 ? (outstanding / quotation).clamp(0.0, 1.0) : 0.0;
    // Declining trend toward the real outstanding fraction (visual only).
    final outstandingTrend = <double>[
      1.0,
      (0.6 + outFraction * 0.4).clamp(0.05, 1.0),
      (0.3 + outFraction * 0.7).clamp(0.05, 1.0),
      outFraction.clamp(0.05, 1.0),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GlassRingCard(
              percent: (percent * 100).clamp(0, 100).toDouble(),
              label: 'Paid',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassSparklineCard(
              label: 'Outstanding',
              value: '₹${_formatCompact(outstanding)}',
              dataPoints: outstandingTrend,
              accentColor: PortalColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 64,
              color: PortalColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No payment information yet',
              style: PortalText.heading(size: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment journey will appear here.',
              style: PortalText.body(size: 13, color: PortalColors.textSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
