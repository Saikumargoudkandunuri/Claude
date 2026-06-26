import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/weekly_status_api.dart';

class WeeklyStatusHistoryScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  const WeeklyStatusHistoryScreen(
      {super.key, required this.projectId, required this.projectName});

  @override
  State<WeeklyStatusHistoryScreen> createState() =>
      _WeeklyStatusHistoryScreenState();
}

class _WeeklyStatusHistoryScreenState extends State<WeeklyStatusHistoryScreen> {
  final _api = WeeklyStatusApi();
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getStatusHistory(widget.projectId);
      if (mounted)
        setState(() {
          _history = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _color(String status) {
    switch (status) {
      case 'on_track':
        return const Color(0xFF4CAF50);
      case 'normal':
        return const Color(0xFFFFC107);
      case 'slow':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  String _label(String status) {
    switch (status) {
      case 'on_track':
        return '🟢 On Track';
      case 'normal':
        return '🟡 As Usual';
      case 'slow':
        return '🔴 Slow / At Risk';
      default:
        return status;
    }
  }

  String _formatWeekLabel(DateTime weekStart) {
    // Calculate ISO week number
    final dayOfYear = int.parse(DateFormat('D').format(weekStart));
    final weekNum = ((dayOfYear - weekStart.weekday + 10) / 7).floor();

    // Month abbreviation
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return 'Week $weekNum — ${months[weekStart.month]} ${weekStart.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Status History — ${widget.projectName}',
            style: const TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xFF00D1DC),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(
                  child: Text('No status history yet.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final row = _history[i];
                    final weekDate = DateTime.parse(row['week_start']);
                    final color = _color(row['status']);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.07),
                        border: Border.all(color: color.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_label(row['status']),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                          fontSize: 14)),
                                  Text(_formatWeekLabel(weekDate),
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ]),
                            const SizedBox(height: 4),
                            Text(
                                'Set by: ${row['set_by_name']} (${row['set_by_role']})',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            if (row['notes'] != null &&
                                row['notes'].toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(row['notes'],
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black87)),
                            ],
                          ]),
                    );
                  },
                ),
    );
  }
}
