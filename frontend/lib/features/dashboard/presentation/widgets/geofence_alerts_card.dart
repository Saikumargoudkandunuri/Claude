import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';

/// Admin card showing pending geofence alerts with Approve/Call/Decline options.
class GeofenceAlertsCard extends StatefulWidget {
  const GeofenceAlertsCard({super.key});

  @override
  State<GeofenceAlertsCard> createState() => _GeofenceAlertsCardState();
}

class _GeofenceAlertsCardState extends State<GeofenceAlertsCard> {
  final Dio _dio = DioClient.instance.dio;
  List<Map<String, dynamic>> _alerts = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    // Poll every 10 seconds for new alerts
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadAlerts();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    try {
      final res = await _dio.get('/attendance/geofence-alerts');
      if (mounted) {
        setState(() {
          _alerts = (res.data['data'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _resolve(String alertId, String action) async {
    try {
      await _dio.put('/attendance/geofence-alerts/$alertId', data: {
        'action': action,
      });
      await _loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'approve'
                  ? '✅ Approved — worker can continue'
                  : '❌ Declined — worker must return to site',
            ),
            backgroundColor: action == 'approve' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error: ${(e is DioException) ? e.response?.data?['error']?['message'] : 'Failed'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callWorker(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Geofence Alerts (${_alerts.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        ..._alerts.map((alert) => _AlertTile(
              alert: alert,
              onApprove: () => _resolve(alert['id'], 'approve'),
              onDecline: () => _resolve(alert['id'], 'decline'),
              onCall: () => _callWorker(alert['worker_phone'] ?? ''),
            )),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.onApprove,
    required this.onDecline,
    required this.onCall,
  });

  final Map<String, dynamic> alert;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final workerName = alert['worker_name'] ?? 'Worker';
    final projectName = alert['project_name'] ?? 'Site';
    final distance = alert['distance_meters'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.red.shade100,
                child:
                    const Icon(Icons.person_off, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$projectName · ${distance}m away',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDecline,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
