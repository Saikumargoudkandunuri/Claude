import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class AttendanceCard extends StatefulWidget {
  const AttendanceCard({super.key});

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  final Dio _dio = DioClient.instance.dio;
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await _dio.get('/attendance/me/status');
      if (mounted)
        setState(() {
          _status = res.data['data'];
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkIn() async {
    setState(() => _actionLoading = true);
    try {
      await _dio.post('/attendance/check-in', data: {});
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Checked in!'),
              backgroundColor: Color(0xFF00D1DC)),
        );
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
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _actionLoading = true);
    try {
      await _dio.post('/attendance/check-out', data: {});
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Checked out!'), backgroundColor: Colors.green),
        );
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
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));

    final checkedIn = _status?['checked_in'] == true;
    final hoursToday = (_status?['hours_today'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: checkedIn
            ? const Color(0xFF00D1DC).withOpacity(0.08)
            : Colors.grey.shade50,
        border: Border.all(
          color: checkedIn ? const Color(0xFF00D1DC) : Colors.grey.shade300,
          width: checkedIn ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(
          checkedIn ? Icons.location_on_rounded : Icons.location_off_rounded,
          color: checkedIn ? const Color(0xFF00D1DC) : Colors.grey,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              checkedIn ? 'At Site' : 'Not Checked In',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: checkedIn ? const Color(0xFF00D1DC) : Colors.black87,
              ),
            ),
            Text(
              checkedIn
                  ? '${hoursToday.toStringAsFixed(1)}h today'
                  : 'Tap to check in when you arrive',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        _actionLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton(
                onPressed: checkedIn ? _checkOut : _checkIn,
                style: FilledButton.styleFrom(
                  backgroundColor: checkedIn
                      ? Colors.grey.shade600
                      : const Color(0xFF00D1DC),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(checkedIn ? 'Check Out' : 'Check In',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
      ]),
    );
  }
}
