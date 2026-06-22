import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class BarChartItem {
  const BarChartItem(this.label, this.value, {this.color});
  final String label;
  final num value;
  final Color? color;
}

/// A dependency-free horizontal bar chart. Responsive and overflow-safe.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.items});
  final List<BarChartItem> items;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<num>(0, (m, e) => e.value > m ? e.value : m);
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.value / safeMax,
                      minHeight: 14,
                      backgroundColor: AppColors.surfaceAlt,
                      color: item.color ?? AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${item.value}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
