import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../payments/application/payments_controller.dart';

class PaymentsTab extends ConsumerWidget {
  const PaymentsTab({super.key, required this.projectId});
  final String projectId;

  void _refresh(WidgetRef ref) => ref.invalidate(projectPaymentsProvider(projectId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectPaymentsProvider(projectId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
        onPressed: () => _showPaymentForm(context, ref),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => _refresh(ref),
        ),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>;
          final history = (data['history'] as List).cast<Map<String, dynamic>>();
          final balance = (summary['balanceAmount'] as num?) ?? 0;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Contract Value',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          Text(
                            Formatters.currency(summary['quotationAmount'] as num?),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _editContract(
                                context, ref, summary['quotationAmount'] as num?),
                          ),
                        ],
                      ),
                      _summaryRow('Received',
                          Formatters.currency(summary['totalReceived'] as num?),
                          color: AppColors.success),
                      const Divider(),
                      _summaryRow('Pending Balance', Formatters.currency(balance),
                          color: AppColors.danger, bold: true),
                      if (balance > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _clearBalance(context, ref),
                            icon: const Icon(Icons.done_all),
                            label: const Text('Clear Balance'),
                          ),
                        ),
                      ],
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
                        '${h['method'] != null ? ' · ${h['method']}' : ''}'
                        '${h['referenceNumber'] != null ? ' · #${h['referenceNumber']}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') {
                            _showPaymentForm(context, ref, existing: h);
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

  Future<void> _editContract(BuildContext context, WidgetRef ref, num? current) async {
    final controller = TextEditingController(text: (current ?? 0).toString());
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
    await ref.read(paymentsRepositoryProvider).updateQuotation(projectId, value);
    _refresh(ref);
  }

  Future<void> _clearBalance(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear balance?'),
        content: const Text(
            'This records a final payment equal to the remaining balance and marks the project fully paid.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(paymentsRepositoryProvider).clearBalance(projectId);
      _refresh(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    }
  }

  Future<void> _deleteHistory(BuildContext context, WidgetRef ref, String id) async {
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

  /// Add or edit a payment entry.
  void _showPaymentForm(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final amount =
        TextEditingController(text: isEdit ? '${existing['amount']}' : '');
    final reference = TextEditingController(
        text: isEdit ? (existing['referenceNumber']?.toString() ?? '') : '');
    String kind = isEdit ? (existing['kind']?.toString() ?? 'advance') : 'advance';
    String method = isEdit ? (existing['method']?.toString() ?? 'cash') : 'cash';

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
                Text(isEdit ? 'Edit Payment' : 'Record Payment',
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
                  decoration:
                      const InputDecoration(labelText: 'Reference (optional)'),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    final value = num.tryParse(amount.text) ?? 0;
                    if (value <= 0) return;
                    final body = {
                      'kind': kind,
                      'amount': value,
                      'method': method,
                      if (reference.text.isNotEmpty)
                        'referenceNumber': reference.text,
                    };
                    try {
                      if (isEdit) {
                        await ref
                            .read(paymentsRepositoryProvider)
                            .updateHistory(existing['id'] as String, body);
                      } else {
                        await ref
                            .read(paymentsRepositoryProvider)
                            .addHistory(projectId, body);
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
                  child: Text(isEdit ? 'Save Changes' : 'Save Payment'),
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
