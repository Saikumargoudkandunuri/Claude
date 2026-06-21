import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../payments/application/payments_controller.dart';

class PaymentsTab extends ConsumerWidget {
  const PaymentsTab({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectPaymentsProvider(projectId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
        onPressed: () => _showAddPayment(context, ref),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(projectPaymentsProvider(projectId)),
        ),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>;
          final history = (data['history'] as List).cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      _summaryRow('Quotation',
                          Formatters.currency(summary['quotationAmount'] as num?)),
                      _summaryRow('Received',
                          Formatters.currency(summary['totalReceived'] as num?),
                          color: AppColors.success),
                      const Divider(),
                      _summaryRow('Balance',
                          Formatters.currency(summary['balanceAmount'] as num?),
                          color: AppColors.danger, bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Payment History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              if (history.isEmpty)
                const Text('No payments recorded',
                    style: TextStyle(color: AppColors.textSecondary))
              else
                for (final h in history)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text(Formatters.currency(h['amount'] as num?)),
                      subtitle: Text(
                        '${Formatters.roleLabel(h['kind'] as String?)} · '
                        '${Formatters.date(h['paidOn'])}'
                        '${h['method'] != null ? ' · ${h['method']}' : ''}',
                      ),
                      trailing: h['referenceNumber'] != null
                          ? Text('#${h['referenceNumber']}',
                              style: const TextStyle(fontSize: 12))
                          : null,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 18 : 15)),
        ],
      ),
    );
  }

  void _showAddPayment(BuildContext context, WidgetRef ref) {
    final amount = TextEditingController();
    final reference = TextEditingController();
    String kind = 'advance';
    String method = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Record Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'advance', child: Text('Advance')),
                  DropdownMenuItem(value: 'second', child: Text('Second')),
                  DropdownMenuItem(value: 'third', child: Text('Third')),
                  DropdownMenuItem(value: 'final', child: Text('Final')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => kind = v ?? 'advance'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                ],
                onChanged: (v) => setState(() => method = v ?? 'cash'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reference,
                decoration: const InputDecoration(labelText: 'Reference (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () async {
                  final value = num.tryParse(amount.text) ?? 0;
                  if (value <= 0) return;
                  await ref.read(paymentsRepositoryProvider).addHistory(projectId, {
                    'kind': kind,
                    'amount': value,
                    'method': method,
                    if (reference.text.isNotEmpty)
                      'referenceNumber': reference.text,
                  });
                  ref.invalidate(projectPaymentsProvider(projectId));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
