import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';

/// Worker's salary screen — shows salary breakdown and payment history.
class MySalaryScreen extends StatefulWidget {
  const MySalaryScreen({super.key});
  @override
  State<MySalaryScreen> createState() => _MySalaryScreenState();
}

class _MySalaryScreenState extends State<MySalaryScreen>
    with SingleTickerProviderStateMixin {
  final Dio _dio = DioClient.instance.dio;
  late TabController _tabs;
  Map<String, dynamic>? _salary;
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final res = await Future.wait([
        _dio.get('/payroll/salary/my', queryParameters: {'month': month}),
        _dio.get('/payroll/payments/my'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Salary'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'This Month'),
          Tab(text: 'Payment History'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              _SalaryTab(salary: _salary),
              _PaymentsTab(payments: _payments),
            ]),
    );
  }
}

class _SalaryTab extends StatelessWidget {
  const _SalaryTab({required this.salary});
  final Map<String, dynamic>? salary;

  @override
  Widget build(BuildContext context) {
    if (salary == null) {
      return const Center(child: Text('No salary data for this month'));
    }
    final daysPresent = salary!['days_present'] ?? 0;
    final dailyRate = (salary!['daily_rate'] ?? 0).toDouble();
    final gross = (salary!['gross_salary'] ?? 0).toDouble();
    final advances = (salary!['total_advances'] ?? 0).toDouble();
    final bonuses = (salary!['total_bonuses'] ?? 0).toDouble();
    final net = (salary!['net_salary'] ?? 0).toDouble();

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Net salary hero card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF185FA5), Color(0xFF00D1DC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Text('Net Salary',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text('AED ${net.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  '$daysPresent days × AED ${dailyRate.toStringAsFixed(0)}/day',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 20),

          // Breakdown
          _Row(label: 'Days Present', value: '$daysPresent'),
          _Row(
              label: 'Daily Rate',
              value: 'AED ${dailyRate.toStringAsFixed(0)}'),
          const Divider(height: 24),
          _Row(
              label: 'Gross Salary',
              value: 'AED ${gross.toStringAsFixed(0)}',
              bold: true),
          _Row(
              label: 'Advances',
              value: '- AED ${advances.toStringAsFixed(0)}',
              color: Colors.red),
          if (bonuses > 0)
            _Row(
                label: 'Bonuses',
                value: '+ AED ${bonuses.toStringAsFixed(0)}',
                color: Colors.green),
          const Divider(height: 24),
          _Row(
              label: 'Net Payable',
              value: 'AED ${net.toStringAsFixed(0)}',
              bold: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              )),
        ],
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.payments});
  final List<Map<String, dynamic>> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(child: Text('No payment records yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = payments[i];
        final type = p['type']?.toString() ?? 'salary';
        final amount = (p['amount'] ?? 0).toDouble();
        final date = p['paid_at'] ?? p['created_at'] ?? '';
        final note = p['note']?.toString() ?? '';

        IconData icon;
        Color color;
        switch (type) {
          case 'advance':
            icon = Icons.money_off_rounded;
            color = Colors.orange;
            break;
          case 'bonus':
            icon = Icons.card_giftcard_rounded;
            color = Colors.green;
            break;
          default:
            icon = Icons.payments_rounded;
            color = const Color(0xFF185FA5);
        }

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(type[0].toUpperCase() + type.substring(1),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
              date.isNotEmpty
                  ? DateFormat('d MMM yyyy').format(DateTime.parse(date))
                  : '',
              style: const TextStyle(fontSize: 11)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('AED ${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, color: color)),
              if (note.isNotEmpty)
                Text(note,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}
