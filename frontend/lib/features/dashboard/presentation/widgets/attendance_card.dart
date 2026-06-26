import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/dio_client.dart';

class AttendanceCard extends StatefulWidget {
  const AttendanceCard({super.key, this.projectId});
  final String? projectId;

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  final Dio _dio = DioClient.instance.dio;
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _actionLoading = false;
  Timer? _locationTimer;
  bool _outsideGeofence = false;
  Map<String, dynamic>? _activeAlert;
  int? _distanceFromSite;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await _dio.get('/attendance/me/status');
      if (mounted) {
        setState(() {
          _status = res.data['data'];
          _loading = false;
        });
        // If checked in, start location monitoring
        if (_status?['checked_in'] == true) {
          _startLocationMonitoring();
        }
        // Also check for any pending geofence alert
        _checkPendingAlert();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkPendingAlert() async {
    try {
      final res = await _dio.get('/attendance/me/geofence-alert');
      final alert = res.data['data'];
      if (mounted && alert != null) {
        setState(() {
          _activeAlert = alert;
          _outsideGeofence = true;
        });
      }
    } catch (_) {}
  }

  void _startLocationMonitoring() {
    _locationTimer?.cancel();
    // Report location every 30 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _reportCurrentLocation();
    });
    // Also report immediately
    _reportCurrentLocation();
  }

  Future<Position?> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  Future<void> _reportCurrentLocation() async {
    if (!mounted) return;
    final projectId = widget.projectId ?? _status?['record']?['project_id'];
    if (projectId == null) return;

    final position = await _getPosition();
    if (position == null || !mounted) return;

    try {
      final res = await _dio.post('/attendance/report-location', data: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'projectId': projectId,
      });

      final data = res.data['data'];
      if (mounted) {
        final withinGeofence = data['withinGeofence'] == true;
        setState(() {
          _outsideGeofence = !withinGeofence;
          if (!withinGeofence) {
            _activeAlert = data['alert'];
            _distanceFromSite = data['distanceMeters'];
          } else {
            _activeAlert = null;
            _distanceFromSite = null;
          }
        });

        // Show blocking popup if outside geofence
        if (!withinGeofence && _activeAlert != null) {
          _showGeofenceBlockingDialog();
        }
      }
    } catch (_) {}
  }

  void _showGeofenceBlockingDialog() {
    if (!mounted) return;
    final alertStatus = _activeAlert?['status'];
    // Only show if pending or declined
    if (alertStatus != 'pending' && alertStatus != 'declined') return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GeofenceAlertDialog(
        distance: _distanceFromSite ?? 0,
        status: alertStatus ?? 'pending',
        projectName: _activeAlert?['project_name'] ?? 'Site',
        onRefresh: () async {
          await _checkPendingAlert();
          if (!_outsideGeofence || _activeAlert == null) {
            if (mounted) Navigator.of(context, rootNavigator: true).pop();
          }
        },
      ),
    );
  }

  Future<void> _checkIn() async {
    setState(() => _actionLoading = true);
    try {
      final position = await _getPosition();
      final projectId = widget.projectId;

      await _dio.post('/attendance/check-in', data: {
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
        if (projectId != null) 'projectId': projectId,
      });
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Checked in!'),
            backgroundColor: Color(0xFF00D1DC),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = (e is DioException)
            ? (e.response?.data?['error']?['message'] ?? 'Error')
            : 'Error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _actionLoading = true);
    try {
      final position = await _getPosition();
      await _dio.post('/attendance/check-out', data: {
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
      });
      _locationTimer?.cancel();
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Checked out!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = (e is DioException)
            ? (e.response?.data?['error']?['message'] ?? 'Error')
            : 'Error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final checkedIn = _status?['checked_in'] == true;
    final hoursToday = (_status?['hours_today'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _outsideGeofence
                ? Colors.red.shade50
                : checkedIn
                    ? const Color(0xFF00D1DC).withOpacity(0.08)
                    : Colors.grey.shade50,
            border: Border.all(
              color: _outsideGeofence
                  ? Colors.red
                  : checkedIn
                      ? const Color(0xFF00D1DC)
                      : Colors.grey.shade300,
              width: _outsideGeofence
                  ? 2
                  : checkedIn
                      ? 1.5
                      : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _outsideGeofence
                        ? Icons.warning_rounded
                        : checkedIn
                            ? Icons.location_on_rounded
                            : Icons.location_off_rounded,
                    color: _outsideGeofence
                        ? Colors.red
                        : checkedIn
                            ? const Color(0xFF00D1DC)
                            : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _outsideGeofence
                              ? 'Outside Site Area'
                              : checkedIn
                                  ? 'At Site'
                                  : 'Not Checked In',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _outsideGeofence
                                ? Colors.red
                                : checkedIn
                                    ? const Color(0xFF00D1DC)
                                    : Colors.black87,
                          ),
                        ),
                        Text(
                          _outsideGeofence
                              ? '${_distanceFromSite ?? '?'}m away · Waiting for admin'
                              : checkedIn
                                  ? '${hoursToday.toStringAsFixed(1)}h today'
                                  : 'Tap to check in when you arrive',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!_outsideGeofence)
                    _actionLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FilledButton(
                            onPressed: checkedIn ? _checkOut : _checkIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: checkedIn
                                  ? Colors.grey.shade600
                                  : const Color(0xFF00D1DC),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              checkedIn ? 'Check Out' : 'Check In',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Non-dismissible dialog shown when worker is outside geofence.
class _GeofenceAlertDialog extends StatefulWidget {
  const _GeofenceAlertDialog({
    required this.distance,
    required this.status,
    required this.projectName,
    required this.onRefresh,
  });

  final int distance;
  final String status;
  final String projectName;
  final Future<void> Function() onRefresh;

  @override
  State<_GeofenceAlertDialog> createState() => _GeofenceAlertDialogState();
}

class _GeofenceAlertDialogState extends State<_GeofenceAlertDialog> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Poll every 5 seconds to check if admin approved
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      widget.onRefresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.status == 'pending';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            isPending ? 'You have left the site area' : 'Please return to site',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isPending
                ? 'You are ${widget.distance}m from ${widget.projectName}.\n'
                    'Admin has been notified. Please wait for approval or return to site.'
                : 'Admin declined your leave request.\n'
                    'Return within the site radius to continue.',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 8),
          Text(
            isPending
                ? 'Waiting for admin response...'
                : 'Monitoring your location...',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
