import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import 'worker_payment_detail_screen.dart';

/// Admin payroll overview — month selector + worker attendance/salary list.
class AdminPayrollScreen extends StatefulWidget {
  const AdminPayrollScreen({super.key});
  @override
  State<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends State<AdminPayrollScreen> {
  final Dio _dio = DioClient.instance.dio;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _workers = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _monthParam => DateFormat('yyyy-MM').format(_month);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/payroll/admin/overview',
          queryParameters: {'month': _monthParam});
      if (mounted) {
        final data = res.data['data'] as Map<String, dynamic>;
        setState(() {
          _workers =
              ((data['workers'] ?? []) as List).cast<Map<String, dynamic>>();
          _summary = data['summary'] as Map<String, dynamic>? ?? {};
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year < now.year || _month.month < now.month) {
      setState(() => _month = DateTime(_month.year, _month.month + 1));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Payroll')),
      body: Column(children: [
        // Month selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
            Expanded(
              child: Text(DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
          ]),
        ),

        // Summary row
        if (!_loading && _summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _SummaryChip(
                  label: 'Workers',
                  value: '${_summary['total_workers'] ?? _workers.length}'),
              _SummaryChip(
                  label: 'Total Payable',
                  value: 'AED ${_summary['total_payable'] ?? 0}'),
              _SummaryChip(
                  label: 'Advances',
                  value: 'AED ${_summary['total_advances'] ?? 0}'),
            ]),
          ),

        // Worker list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _workers.isEmpty
                  ? const Center(child: Text('No payroll data'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _workers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _WorkerTile(
                          worker: _workers[i],
                          month: _monthParam,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkerPaymentDetailScreen(
                                  workerId: _workers[i]['id']?.toString() ?? '',
                                  workerName:
                                      _workers[i]['full_name']?.toString() ??
                                          '',
                                  month: _monthParam,
                                ),
                              )),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF185FA5).withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _WorkerTile extends StatelessWidget {
  const _WorkerTile(
      {required this.worker, required this.month, required this.onTap});
  final Map<String, dynamic> worker;
  final String month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = worker['full_name']?.toString() ?? '';
    final daysPresent = worker['days_present'] ?? 0;
    final totalAdvances = (worker['total_advances'] ?? 0).toDouble();
    final netSalary = (worker['net_salary'] ?? 0).toDouble();
    final paid = worker['is_paid'] == true;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF185FA5).withOpacity(0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF185FA5))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                    '$daysPresent days  •  Adv: AED ${totalAdvances.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('AED ${netSalary.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: paid
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(paid ? 'Paid' : 'Pending',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: paid ? Colors.green : Colors.orange)),
              ),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}
