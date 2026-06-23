import 'package:flutter/material.dart';

import '../design/app_gradients.dart';

/// Small colored status pill (active / pending / completed / brief, etc).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.gradient = AppGradients.primary,
  });

  final String label;
  final List<Color> gradient;

  /// Convenience factory that picks a gradient from a status string.
  factory StatusBadge.forStatus(String status) {
    final s = status.toLowerCase();
    List<Color> g;
    if (s.contains('complete') || s.contains('done') || s.contains('received')) {
      g = AppGradients.success;
    } else if (s.contains('pending') || s.contains('progress') || s.contains('assigned')) {
      g = AppGradients.warning;
    } else if (s.contains('reject') || s.contains('overdue') || s.contains('missed')) {
      g = AppGradients.danger;
    } else {
      g = AppGradients.primary;
    }
    return StatusBadge(label: status, gradient: g);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
