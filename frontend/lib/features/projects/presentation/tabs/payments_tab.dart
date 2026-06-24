import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../payments/application/payments_controller.dart';

/// Payment screen (BUG-08 redesign): Quotation / Received / Balance summary
/// cards, animated circular progress, partial-payment recording and history.
class PaymentsTab extends ConsumerWidget {
  const PaymentsTab({super.key, required this.projectId});
  final String projectId;

  void _refresh(WidgetRef ref) => ref.invalidate(projectPaymentsProvider(projectId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectPaymentsProvider(projectId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
        onPressed: () => _showAddPayment(context, ref),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => _refresh(ref)),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>;
          final history = (data['history'] as List).cast<Map<String, dynamic>>();
          final quotation = (summary['quotationAmount'] as num?) ?? 0;
          final received = (summary['totalReceived'] as num?) ?? 0;
          final balance = (summary['balanceAmount'] as num?) ?? 0;
          final percent = ((summary['paymentPercentage'] as num?) ?? 0).toDouble();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // 3 summary cards
              Row(
                children: [
                  Expanded(
                    child: _PayCard(
                      label: 'Quotation',
                      amount: quotation,
                      gradient: AppGradients.primary,
                      icon: Icons.request_quote,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PayCard(
                      label: 'Received',
                      amount: received,
                      gradient: AppGradients.success,
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PayCard(
                      label: 'Balance',
                      amount: balance,
                      gradient: balance > 0 ? AppGradients.warning : AppGradients.success,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Circular progress
              Center(
                child: CircularPercentIndicator(
                  radius: 70,
                  lineWidth: 12,
                  animation: true,
                  animationDuration: 700,
                  percent: (percent / 100).clamp(0.0, 1.0),
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: AppColors.surfaceAlt,
                  linearGradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF10B981)],
                  ),
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GradientText(
                        '${percent.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const Text('Paid',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'Add Payment',
                      icon: Icons.add,
                      onPressed: () => _showAddPayment(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Quotation'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _editContract(context, ref, quotation),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

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
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceAlt,
                        child: Icon(Icons.payments_outlined,
                            color: AppColors.success, size: 18),
                      ),
                      title: Text(Formatters.currency(h['amount'] as num?),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${Formatters.roleLabel(h['kind'] as String?)} · '
                        '${Formatters.date(h['paidOn'])}'
                        '${h['method'] != null ? ' · ${h['method']}' : ''}'
                        '${h['referenceNumber'] != null ? ' · #${h['referenceNumber']}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') {
                            _showAddPayment(context, ref, existing: h);
                          } else if (v == 'delete') {
                            _deleteHistory(context, ref, h['id'] as String);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editContract(BuildContext context, WidgetRef ref, num current) async {
    final controller = TextEditingController(text: current.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Contract Value'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final value = num.tryParse(controller.text) ?? 0;
    await ref.read(paymentsRepositoryProvider).updateQuotation(projectId, value);
    _refresh(ref);
  }

  Future<void> _deleteHistory(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text('This payment entry will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(paymentsRepositoryProvider).deleteHistory(id);
    _refresh(ref);
  }

  /// Add a received payment, or edit an existing entry.
  void _showAddPayment(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final amount = TextEditingController(text: isEdit ? '${existing['amount']}' : '');
    final reference = TextEditingController(
        text: isEdit ? (existing['referenceNumber']?.toString() ?? '') : '');
    final note = TextEditingController();
    String kind = isEdit ? (existing['kind']?.toString() ?? 'advance') : 'advance';
    String mode = isEdit ? (existing['method']?.toString() ?? 'cash') : 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit Payment' : 'Record Received Payment',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                  value: mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => mode = v ?? 'cash'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(labelText: 'Reference (optional)'),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Note (optional)'),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  expand: true,
                  label: isEdit ? 'Save Changes' : 'Add Payment',
                  onPressed: () async {
                    final value = num.tryParse(amount.text) ?? 0;
                    if (value <= 0) return;
                    try {
                      if (isEdit) {
                        await ref.read(paymentsRepositoryProvider).updateHistory(
                          existing['id'] as String,
                          {
                            'kind': kind,
                            'amount': value,
                            'method': mode,
                            if (reference.text.isNotEmpty) 'referenceNumber': reference.text,
                          },
                        );
                      } else {
                        await ref.read(paymentsRepositoryProvider).addReceived(
                          projectId,
                          {
                            'kind': kind,
                            'amount': value,
                            'paymentMode': mode,
                            if (reference.text.isNotEmpty) 'referenceNumber': reference.text,
                            if (note.text.isNotEmpty) 'note': note.text,
                          },
                        );
                      }
                      _refresh(ref);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(DioClient.toApiException(e).message)),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.label,
    required this.amount,
    required this.gradient,
    required this.icon,
  });

  final String label;
  final num amount;
  final List<Color> gradient;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.currency(amount),
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
        ],
      ),
    );
  }
}
