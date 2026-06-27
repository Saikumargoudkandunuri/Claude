import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class WorkerAttendanceCalendarScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  const WorkerAttendanceCalendarScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  State<WorkerAttendanceCalendarScreen> createState() =>
      _WorkerAttendanceCalendarScreenState();
}

class _WorkerAttendanceCalendarScreenState
    extends State<WorkerAttendanceCalendarScreen> {
  final Dio _dio = DioClient.instance.dio;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, Map<String, dynamic>> _attendanceMap = {};
  bool _loading = true;
  int _daysPresent = 0, _daysAbsent = 0, _daysWorkshop = 0;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    try {
      final monthStr =
          '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
      final res = await _dio.get(
        '/payroll/attendance/month',
        queryParameters: {'month': monthStr, 'user_id': widget.workerId},
      );
      final records = (res.data['data'] as List?) ?? [];
      final map = <String, Map<String, dynamic>>{};
      int present = 0, absent = 0, workshop = 0;
      for (final r in records) {
        final dateStr = r['date'].toString().split('T')[0];
        map[dateStr] = r as Map<String, dynamic>;
        final mode = r['work_mode'] as String;
        if (mode == 'absent') {
          absent++;
        } else if (mode == 'workshop') {
          workshop++;
          present++;
        } else {
          present++;
        }
      }
      if (mounted) {
        setState(() {
          _attendanceMap = map;
          _daysPresent = present;
          _daysAbsent = absent;
          _daysWorkshop = workshop;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _loadMonth();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year == now.year && _month.month == now.month) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _loadMonth();
  }

  void _onDayTap(DateTime day) {
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailSheet(
        workerId: widget.workerId,
        date: dateStr,
        attendance: _attendanceMap[dateStr],
        dio: _dio,
        onAdminMark: (mode, notes) async {
          try {
            await _dio.post('/payroll/attendance/admin-mark', data: {
              'target_user_id': widget.workerId,
              'date': dateStr,
              'work_mode': mode,
              'notes': notes,
            });
            _loadMonth();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attendance marked'),
                  backgroundColor: Color(0xFF00D1DC),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_extractError(e)),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isCurrentMonth =
        _month.year == today.year && _month.month == today.month;
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.workerName} — Attendance',
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: const Color(0xFF00D1DC),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Month navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _prevMonth,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: const Color(0xFF00D1DC),
                      ),
                      Text(
                        '${_monthName(_month.month)} ${_month.year}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: isCurrentMonth ? null : _nextMonth,
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: isCurrentMonth
                            ? Colors.grey.shade300
                            : const Color(0xFF00D1DC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Summary chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _summaryChip(
                          '$_daysPresent Present', const Color(0xFF00D1DC)),
                      const SizedBox(width: 8),
                      _summaryChip(
                          '$_daysWorkshop Workshop', const Color(0xFF185FA5)),
                      const SizedBox(width: 8),
                      _summaryChip('$_daysAbsent Absent', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Day headers
                  Row(
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                        .map(
                          (d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  // Calendar grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: startOffset + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < startOffset) {
                        return const SizedBox.shrink();
                      }
                      final dayNum = index - startOffset + 1;
                      final date = DateTime(_month.year, _month.month, dayNum);
                      final dateStr =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final record = _attendanceMap[dateStr];
                      final mode = record?['work_mode'] as String?;
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
                      final isFuture = date.isAfter(today);

                      Color fillColor = Colors.transparent;
                      Color textColor = Colors.black87;
                      Color borderColor = Colors.grey.shade200;

                      if (!isFuture && mode != null) {
                        switch (mode) {
                          case 'at_site':
                            fillColor =
                                const Color(0xFF00D1DC).withOpacity(0.18);
                            textColor = const Color(0xFF0F6E56);
                            borderColor = const Color(0xFF00D1DC);
                          case 'workshop':
                            fillColor =
                                const Color(0xFF185FA5).withOpacity(0.12);
                            textColor = const Color(0xFF185FA5);
                            borderColor = const Color(0xFF185FA5);
                          case 'absent':
                            fillColor = Colors.red.withOpacity(0.12);
                            textColor = Colors.red.shade700;
                            borderColor = Colors.red;
                          case 'leave':
                            fillColor = Colors.orange.withOpacity(0.12);
                            textColor = Colors.orange.shade800;
                            borderColor = Colors.orange;
                        }
                      } else if (!isFuture && mode == null) {
                        fillColor = Colors.grey.shade100;
                        textColor = Colors.grey.shade400;
                      }

                      return GestureDetector(
                        onTap: isFuture ? null : () => _onDayTap(date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: fillColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isToday
                                  ? const Color(0xFF00D1DC)
                                  : borderColor,
                              width: isToday ? 2 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color:
                                    isFuture ? Colors.grey.shade300 : textColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap any date to see details or mark attendance',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _monthName(int m) {
    const names = [
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
      'Dec',
    ];
    return names[m];
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? 'Error';
    }
    return 'Error';
  }
}

// Day detail bottom sheet
class _DayDetailSheet extends StatefulWidget {
  final String workerId;
  final String date;
  final Map<String, dynamic>? attendance;
  final Dio dio;
  final Function(String mode, String? notes) onAdminMark;

  const _DayDetailSheet({
    required this.workerId,
    required this.date,
    required this.attendance,
    required this.dio,
    required this.onAdminMark,
  });

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.dio.get(
        '/payroll/attendance/day/${widget.date}',
        queryParameters: {'user_id': widget.workerId},
      );
      if (mounted) {
        setState(() {
          _detail = res.data['data'];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMarkSheet() {
    String selectedMode = 'at_site';
    final notesCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mark Attendance',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 12),
              ...['at_site', 'workshop', 'leave', 'absent'].map((mode) {
                final labels = {
                  'at_site': 'At Site',
                  'workshop': 'Workshop',
                  'leave': 'Leave',
                  'absent': 'Absent',
                };
                final colors = {
                  'at_site': const Color(0xFF00D1DC),
                  'workshop': const Color(0xFF185FA5),
                  'leave': Colors.orange,
                  'absent': Colors.red,
                };
                return RadioListTile<String>(
                  value: mode,
                  groupValue: selectedMode,
                  title: Text(
                    labels[mode]!,
                    style: TextStyle(
                      color: colors[mode],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  activeColor: colors[mode],
                  onChanged: (v) => setS(() => selectedMode = v!),
                );
              }),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    widget.onAdminMark(
                      selectedMode,
                      notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1DC),
                  ),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final att = _detail?['attendance'] as Map<String, dynamic>?;
    final mode = att?['work_mode'] as String?;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                widget.date,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (mode != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _modeColor(mode).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _modeColor(mode)),
                  ),
                  child: Text(
                    _modeLabel(mode),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _modeColor(mode),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (att != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  if (att['project_name'] != null)
                    _row('Project', att['project_name'].toString()),
                  _row('Check in', _fmtTime(att['check_in_time'])),
                  _row('Check out', _fmtTime(att['check_out_time'])),
                  if (att['hours_worked'] != null)
                    _row('Hours', '${att['hours_worked']}h'),
                  if (att['notes'] != null &&
                      att['notes'].toString().isNotEmpty)
                    _row('Notes', att['notes'].toString()),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'No attendance record for this day',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showMarkSheet,
                icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                label: const Text('Mark attendance for this day'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00D1DC),
                  side: const BorderSide(color: Color(0xFF00D1DC)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _modeColor(String? mode) {
    switch (mode) {
      case 'at_site':
        return const Color(0xFF00D1DC);
      case 'workshop':
        return const Color(0xFF185FA5);
      case 'absent':
        return Colors.red;
      case 'leave':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _modeLabel(String? mode) {
    switch (mode) {
      case 'at_site':
        return 'At Site';
      case 'workshop':
        return 'Workshop';
      case 'absent':
        return 'Absent';
      case 'leave':
        return 'On Leave';
      default:
        return 'Not Recorded';
    }
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '—';
    final t = DateTime.tryParse(iso.toString())?.toLocal();
    if (t == null) return '—';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
