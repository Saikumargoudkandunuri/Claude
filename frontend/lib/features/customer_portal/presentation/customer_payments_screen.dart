import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/customer_providers.dart';

/// Customer-facing payment summary screen.
///
/// Shows a circular progress indicator (received / quotation ratio) and
/// summary cards for Quotation Amount, Total Received, and Outstanding Balance.
/// No individual transaction records are displayed.
class CustomerPaymentsScreen extends ConsumerWidget {
  const CustomerPaymentsScreen({super.key});

  static const _brandTeal = Color(0xFF00D1DC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerPaymentSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(customerPaymentSummaryProvider),
        ),
        data: (data) {
          final quotation = (data['quotation_amount'] as num?) ?? 0;
          final received = (data['total_received'] as num?) ?? 0;
          final outstanding = (data['outstanding_balance'] as num?) ?? 0;

          // Empty / zero state
          if (quotation == 0 && received == 0 && outstanding == 0) {
            return const _EmptyState();
          }

          final percent =
              quotation > 0 ? (received / quotation).clamp(0.0, 1.0) : 0.0;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Circular progress indicator
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: percent,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.surfaceAlt,
                          color: _brandTeal,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(percent * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: _brandTeal,
                            ),
                          ),
                          const Text(
                            'Received',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Summary cards
              _SummaryCard(
                icon: Icons.request_quote_outlined,
                label: 'Quotation Amount',
                amount: quotation,
                color: _brandTeal,
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: Icons.check_circle_outline,
                label: 'Total Received',
                amount: received,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Outstanding Balance',
                amount: outstanding,
                color: outstanding > 0 ? AppColors.warning : AppColors.success,
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No payment information available',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single summary row card displaying an icon, label, and formatted amount.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  final IconData icon;
  final String label;
  final num amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.currency(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
