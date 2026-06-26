import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class WorkerAttendanceCard extends StatefulWidget {
  const WorkerAttendanceCard({super.key});
  @override
  State<WorkerAttendanceCard> createState() => _WorkerAttendanceCardState();
}

class _WorkerAttendanceCardState extends State<WorkerAttendanceCard> {
  final Dio _dio = DioClient.instance.dio;
  Map<String, dynamic>? _today;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/payroll/attendance/today');
      if (mounted)
        setState(() {
          _today = res.data['data'];
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAttendance(String mode, {String? projectId}) async {
    setState(() => _busy = true);
    try {
      await _dio.post('/payroll/attendance/mark', data: {
        'work_mode': mode,
        if (projectId != null) 'project_id': projectId,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('✅ Marked: ${mode == 'at_site' ? 'At Site' : 'Workshop'}'),
            backgroundColor: const Color(0xFF00D1DC)));
      }
    } catch (e) {
      if (mounted) {
        final msg = (e is DioException)
            ? (e.response?.data?['error']?['message'] ?? 'Error')
            : 'Error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _busy = true);
    try {
      final res = await _dio.post('/payroll/attendance/checkout');
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ${res.data['message'] ?? 'Checked out'}'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        final msg = (e is DioException)
            ? (e.response?.data?['error']?['message'] ?? 'Error')
            : 'Error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));

    final mode = _today?['work_mode'] as String?;
    final hasCheckedIn = mode != null;
    final hasCheckedOut = _today?['check_out_time'] != null;

    Color modeColor = Colors.grey;
    String modeLabel = 'Not marked';
    if (mode == 'at_site') {
      modeColor = const Color(0xFF00D1DC);
      modeLabel = 'At Site';
    }
    if (mode == 'workshop') {
      modeColor = const Color(0xFF185FA5);
      modeLabel = 'Workshop';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasCheckedIn ? modeColor.withOpacity(0.06) : Colors.grey.shade50,
        border: Border.all(
            color: hasCheckedIn ? modeColor : Colors.grey.shade300, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              hasCheckedIn
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: modeColor,
              size: 18),
          const SizedBox(width: 8),
          const Text("Today's Attendance",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: modeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16)),
            child: Text(modeLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: modeColor)),
          ),
        ]),
        if (_today?['check_in_time'] != null) ...[
          const SizedBox(height: 4),
          Text(
              hasCheckedOut
                  ? '${_today!['hours_worked']}h worked today'
                  : 'Checked in',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
        const SizedBox(height: 12),
        if (_busy)
          const Center(
              child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2)))
        else if (!hasCheckedIn)
          Row(children: [
            Expanded(
                child: FilledButton.icon(
              onPressed: () => _markAttendance('at_site'),
              icon: const Icon(Icons.location_on_rounded, size: 16),
              label: const Text('At Site', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1DC),
                  foregroundColor: Colors.white),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
              onPressed: () => _markAttendance('workshop'),
              icon: const Icon(Icons.handyman_rounded, size: 16),
              label: const Text('Workshop', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF185FA5)),
            )),
          ])
        else if (!hasCheckedOut)
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _checkOut,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Check Out'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700),
              ))
        else
          Row(children: [
            Icon(Icons.verified_rounded,
                size: 14, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text('Done for today',
                style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
          ]),
      ]),
    );
  }
}
