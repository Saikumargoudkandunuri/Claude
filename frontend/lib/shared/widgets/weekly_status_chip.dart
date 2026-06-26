import 'package:flutter/material.dart';

class WeeklyStatusChip extends StatelessWidget {
  // status: 'on_track' | 'normal' | 'slow' | null (= not reviewed)
  final String? status;
  final bool compact; // compact=true for list cards, false for detail header

  const WeeklyStatusChip({super.key, this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final config = _config(status);
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: config.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: config.color, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, color: config.color, size: 11),
            const SizedBox(width: 4),
            Text(
              config.label,
              style: TextStyle(
                color: config.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }
    // Full size (for detail header)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: config.color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 16),
          const SizedBox(width: 6),
          Text(
            'This week: ${config.label}',
            style: TextStyle(
              color: config.color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _config(String? status) {
    switch (status) {
      case 'on_track':
        return _StatusConfig(
          label: 'On Track',
          color: const Color(0xFF4CAF50),
          icon: Icons.check_circle_rounded,
        );
      case 'normal':
        return _StatusConfig(
          label: 'As Usual',
          color: const Color(0xFFFFC107),
          icon: Icons.remove_circle_rounded,
        );
      case 'slow':
        return _StatusConfig(
          label: 'Slow / At Risk',
          color: const Color(0xFFF44336),
          icon: Icons.warning_rounded,
        );
      default:
        return _StatusConfig(
          label: 'Not Reviewed',
          color: const Color(0xFF9E9E9E),
          icon: Icons.radio_button_unchecked,
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusConfig(
      {required this.label, required this.color, required this.icon});
}
