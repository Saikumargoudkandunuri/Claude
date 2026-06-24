import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../payments/application/payments_controller.dart';

/// Payment screen: Quotation / Received / Balance summary,
/// circular progress, add payment, and full history with date+time.
class PaymentsTab extends ConsumerWidget {
  const PaymentsTab({super.key, required this.projectId});
  final String projectId;

  void _refresh(WidgetRef ref) =>
      ref.invalidate(projectPaymentsProvider(projectId));

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
        error: (e, _) =>
            ErrorView(message: e.toString(), onRetry: () => _refresh(ref)),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>;
          final history =
              (data['history'] as List).cast<Map<String, dynamic>>();
          final quotation = (summary['quotationAmount'] as num?) ?? 0;
          final received = (summary['totalReceived'] as num?) ?? 0;
          final balance = (summary['balanceAmount'] as num?) ?? 0;
          final percent = quotation > 0
              ? (received / quotation * 100).clamp(0.0, 100.0)
              : 0.0;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _PayCard(
                      label: 'Quotation',
                      amount: quotation,
                      color: AppColors.primary,
                      icon: Icons.request_quote,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PayCard(
                      label: 'Received',
                      amount: received,
                      color: AppColors.success,
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PayCard(
                      label: 'Balance',
                      amount: balance,
                      color:
                          balance > 0 ? AppColors.warning : AppColors.success,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Circular progress
              Center(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: (percent / 100).clamp(0.0, 1.0),
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.surfaceAlt,
                          color: AppColors.primary,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'Paid',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAddPayment(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Payment'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
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

              // Payment History
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Payment History',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${history.length} entries',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No payments recorded yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                for (final h in history)
                  _HistoryTile(
                    entry: h,
                    onEdit: () => _showAddPayment(context, ref, existing: h),
                    onDelete: () =>
                        _deleteHistory(context, ref, h['id'] as String),
                  ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editContract(
      BuildContext context, WidgetRef ref, num current) async {
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final value = num.tryParse(controller.text) ?? 0;
    await ref
        .read(paymentsRepositoryProvider)
        .updateQuotation(projectId, value);
    _refresh(ref);
  }

  Future<void> _deleteHistory(
      BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text('This payment entry will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
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

  void _showAddPayment(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final amount =
        TextEditingController(text: isEdit ? '${existing['amount']}' : '');
    final reference = TextEditingController(
      text: isEdit ? (existing['referenceNumber']?.toString() ?? '') : '',
    );
    final note = TextEditingController();
    String kind =
        isEdit ? (existing['kind']?.toString() ?? 'advance') : 'advance';
    String mode = isEdit ? (existing['method']?.toString() ?? 'cash') : 'cash';
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? 'Edit Payment' : 'Record Payment',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  value: kind,
                  decoration: const InputDecoration(labelText: 'Payment Type'),
                  items: const [
                    DropdownMenuItem(value: 'advance', child: Text('Advance')),
                    DropdownMenuItem(value: 'second', child: Text('Second')),
                    DropdownMenuItem(value: 'third', child: Text('Third')),
                    DropdownMenuItem(value: 'final', child: Text('Final')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setSheetState(() => kind = v ?? 'advance'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(
                        value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setSheetState(() => mode = v ?? 'cash'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                      labelText: 'Reference / Transaction ID (optional)'),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: note,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final value = num.tryParse(amount.text) ?? 0;
                            if (value <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('Enter a valid amount')),
                              );
                              return;
                            }
                            setSheetState(() => busy = true);
                            try {
                              if (isEdit) {
                                await ref
                                    .read(paymentsRepositoryProvider)
                                    .updateHistory(
                                  existing['id'] as String,
                                  {
                                    'kind': kind,
                                    'amount': value,
                                    'method': mode,
                                    if (reference.text.isNotEmpty)
                                      'referenceNumber': reference.text,
                                  },
                                );
                              } else {
                                await ref
                                    .read(paymentsRepositoryProvider)
                                    .addReceived(
                                  projectId,
                                  {
                                    'kind': kind,
                                    'amount': value,
                                    'paymentMode': mode,
                                    if (reference.text.isNotEmpty)
                                      'referenceNumber': reference.text,
                                    if (note.text.isNotEmpty) 'note': note.text,
                                  },
                                );
                              }
                              _refresh(ref);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheetState(() => busy = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          DioClient.toApiException(e).message)),
                                );
                              }
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Save Changes' : 'Add Payment'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual payment history entry with date, time, amount, method.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amount = entry['amount'] as num?;
    final kind = entry['kind']?.toString() ?? 'other';
    final method = entry['method']?.toString();
    final ref = entry['referenceNumber']?.toString();
    final paidOn = entry['paidOn']?.toString();
    final createdAt = entry['createdAt']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_downward,
                  color: AppColors.success, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.currency(amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_kindLabel(kind)}'
                    '${method != null ? ' • $method' : ''}'
                    '${ref != null && ref.isNotEmpty ? ' • #$ref' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paidOn != null
                        ? Formatters.date(paidOn)
                        : (createdAt != null
                            ? Formatters.dateTime(createdAt)
                            : ''),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'advance':
        return 'Advance';
      case 'second':
        return '2nd Payment';
      case 'third':
        return '3rd Payment';
      case 'final':
        return 'Final';
      default:
        return 'Payment';
    }
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final num amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.currency(amount),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
