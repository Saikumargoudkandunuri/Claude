import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../application/customer_providers.dart';
import '../theme/customer_theme.dart';

/// Customer-facing payment summary screen.
///
/// Shows a top gradient card with contract value and progress,
/// plus two stat cards for amount paid and outstanding.
class CustomerPaymentsScreen extends ConsumerWidget {
  const CustomerPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerPaymentSummaryProvider);

    return Scaffold(
      backgroundColor: CTheme.bgSoft,
      appBar: AppBar(
        title: const Text(
          'Payments',
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
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CTheme.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: CTheme.textLight),
              const SizedBox(height: CTheme.p12),
              Text(
                e.toString(),
                style: const TextStyle(color: CTheme.textMid, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CTheme.p16),
              ElevatedButton(
                onPressed: () => ref.invalidate(customerPaymentSummaryProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CTheme.primary,
                  foregroundColor: CTheme.bgWhite,
                  shape: RoundedRectangleBorder(borderRadius: CTheme.r12),
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

          // Empty / zero state
          if (quotation == 0 && received == 0 && outstanding == 0) {
            return const _EmptyState();
          }

          final percent =
              quotation > 0 ? (received / quotation).clamp(0.0, 1.0) : 0.0;

          return ListView(
            padding: const EdgeInsets.all(CTheme.p16),
            children: [
              // Top gradient card
              Container(
                padding: const EdgeInsets.all(CTheme.p24),
                decoration: BoxDecoration(
                  gradient: CTheme.heroGradient,
                  borderRadius: CTheme.r16,
                  boxShadow: CTheme.heroShadow,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Contract Value',
                      style: TextStyle(
                        fontSize: 13,
                        color: CTheme.bgWhite,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: CTheme.p8),
                    Text(
                      Formatters.currency(quotation),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: CTheme.bgWhite,
                      ),
                    ),
                    const SizedBox(height: CTheme.p20),
                    // Progress bar
                    ClipRRect(
                      borderRadius: CTheme.r8,
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 8,
                        backgroundColor: CTheme.bgWhite.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          CTheme.bgWhite,
                        ),
                      ),
                    ),
                    const SizedBox(height: CTheme.p8),
                    Text(
                      '${(percent * 100).round()}% paid',
                      style: TextStyle(
                        fontSize: 13,
                        color: CTheme.bgWhite.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CTheme.p16),

              // Two stat cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Amount Paid',
                      value: Formatters.currency(received),
                      color: CTheme.success,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: CTheme.p12),
                  Expanded(
                    child: _StatCard(
                      label: 'Outstanding',
                      value: Formatters.currency(outstanding),
                      color: CTheme.warning,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Empty state shown when no payment information is available.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CTheme.p32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 64,
              color: CTheme.textLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: CTheme.p16),
            const Text(
              'No payment information available',
              style: TextStyle(
                fontSize: 16,
                color: CTheme.textMid,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A stat card showing label, value and colored accent.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CTheme.p16),
      decoration: BoxDecoration(
        color: CTheme.bgWhite,
        borderRadius: CTheme.r16,
        boxShadow: CTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: CTheme.r8,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: CTheme.p12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CTheme.textLight,
            ),
          ),
          const SizedBox(height: CTheme.p4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
