import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';

/// Admin's worker payment detail — salary preview, actions, and history.
class WorkerPaymentDetailScreen extends StatefulWidget {
  const WorkerPaymentDetailScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    required this.month,
  });
  final String workerId;
  final String workerName;
  final String month;

  @override
  State<WorkerPaymentDetailScreen> createState() =>
      _WorkerPaymentDetailScreenState();
}

class _WorkerPaymentDetailScreenState extends State<WorkerPaymentDetailScreen> {
  final Dio _dio = DioClient.instance.dio;
  Map<String, dynamic>? _salary;
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _dio.get('/payroll/admin/worker/${widget.workerId}/salary',
            queryParameters: {'month': widget.month}),
        _dio.get('/payroll/admin/worker/${widget.workerId}/payments',
            queryParameters: {'month': widget.month}),
      ]);
      if (mounted) {
        setState(() {
          _salary = res[0].data['data'];
          _payments = ((res[1].data['data'] ?? []) as List)
              .cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAdvance() async {
    final result = await _showAmountDialog('Add Advance', withProof: true);
    if (result == null) return;
    try {
      final formData = FormData.fromMap({
        'worker_id': widget.workerId,
        'amount': result['amount'],
        'note': result['note'] ?? '',
        if (result['proof'] != null)
          'proof': await MultipartFile.fromFile(result['proof'],
              filename: 'proof.jpg'),
      });
      await _dio.post('/payroll/admin/advance', data: formData);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Advance added'), backgroundColor: Colors.green));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addBonus() async {
    final result = await _showAmountDialog('Add Bonus', withProof: false);
    if (result == null) return;
    try {
      await _dio.post('/payroll/admin/bonus', data: {
        'worker_id': widget.workerId,
        'amount': result['amount'],
        'note': result['note'] ?? '',
      });
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Bonus added'), backgroundColor: Colors.green));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _paySalary() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pay Salary'),
        content: Text(
            'Pay AED ${(_salary?['net_salary'] ?? 0).toStringAsFixed(0)} to ${widget.workerName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _dio.post('/payroll/admin/pay-salary', data: {
        'worker_id': widget.workerId,
        'month': widget.month,
      });
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Salary paid'), backgroundColor: Colors.green));
    } catch (e) {
      _showError(e);
    }
  }

  Future<Map<String, dynamic>?> _showAmountDialog(String title,
      {required bool withProof}) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? proofPath;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Amount (AED)', prefixText: 'AED '),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (withProof) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final img = await picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 70);
                  if (img != null) setDialogState(() => proofPath = img.path);
                },
                icon: const Icon(Icons.attach_file, size: 16),
                label: Text(
                    proofPath != null ? 'Proof attached ✓' : 'Attach proof'),
              ),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx, {
                  'amount': amount,
                  'note': noteCtrl.text,
                  if (proofPath != null) 'proof': proofPath,
                });
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = (e is DioException)
        ? (e.response?.data?['error']?['message'] ?? 'Error')
        : 'Error';
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.workerName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Salary preview card
                  _SalaryCard(salary: _salary),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(children: [
                    Expanded(
                        child: _ActionBtn(
                            icon: Icons.money_off_rounded,
                            label: 'Advance',
                            color: Colors.orange,
                            onTap: _addAdvance)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _ActionBtn(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Bonus',
                            color: Colors.green,
                            onTap: _addBonus)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _ActionBtn(
                            icon: Icons.payments_rounded,
                            label: 'Pay Salary',
                            color: const Color(0xFF185FA5),
                            onTap: _paySalary)),
                  ]),
                  const SizedBox(height: 24),

                  // Payment history
                  const Text('Payment History',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (_payments.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No payments this month',
                          style: TextStyle(color: Colors.grey)),
                    ))
                  else
                    ..._payments.map((p) => _PaymentTile(payment: p)),
                ],
              ),
            ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({required this.salary});
  final Map<String, dynamic>? salary;

  @override
  Widget build(BuildContext context) {
    if (salary == null) return const SizedBox.shrink();
    final days = salary!['days_present'] ?? 0;
    final rate = (salary!['daily_rate'] ?? 0).toDouble();
    final gross = (salary!['gross_salary'] ?? 0).toDouble();
    final advances = (salary!['total_advances'] ?? 0).toDouble();
    final bonuses = (salary!['total_bonuses'] ?? 0).toDouble();
    final net = (salary!['net_salary'] ?? 0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Salary Preview',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Text('AED ${net.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF185FA5))),
          ]),
          const Divider(height: 20),
          _InfoRow('Days Present', '$days'),
          _InfoRow('Daily Rate', 'AED ${rate.toStringAsFixed(0)}'),
          _InfoRow('Gross', 'AED ${gross.toStringAsFixed(0)}'),
          _InfoRow('Advances', '- AED ${advances.toStringAsFixed(0)}'),
          if (bonuses > 0)
            _InfoRow('Bonuses', '+ AED ${bonuses.toStringAsFixed(0)}'),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final type = payment['type']?.toString() ?? 'salary';
    final amount = (payment['amount'] ?? 0).toDouble();
    final date = payment['paid_at'] ?? payment['created_at'] ?? '';
    final note = payment['note']?.toString() ?? '';

    Color color;
    IconData icon;
    switch (type) {
      case 'advance':
        color = Colors.orange;
        icon = Icons.money_off_rounded;
        break;
      case 'bonus':
        color = Colors.green;
        icon = Icons.card_giftcard_rounded;
        break;
      default:
        color = const Color(0xFF185FA5);
        icon = Icons.payments_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text('${type[0].toUpperCase()}${type.substring(1)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (date.isNotEmpty)
            Text(DateFormat('d MMM yyyy').format(DateTime.parse(date)),
                style: const TextStyle(fontSize: 11)),
          if (note.isNotEmpty)
            Text(note,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        trailing: Text('AED ${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      ),
    );
  }
}
