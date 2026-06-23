import 'package:flutter/material.dart';

import '../design/app_gradients.dart';
import 'gradient_text.dart';

/// Visual 13-stage progress bar (NEW-03). Pass the current stage value.
class StageProgressBar extends StatelessWidget {
  const StageProgressBar({
    super.key,
    required this.currentStage,
    this.showLabel = true,
  });

  final String currentStage;
  final bool showLabel;

  static const List<String> stages = [
    'discussion', '3d_design', 'drawing', 'material_purchase', 'cutting',
    'making', 'lamination', 'painting', 'packing', 'transport',
    'installation', 'checking', 'completed',
  ];

  @override
  Widget build(BuildContext context) {
    final idx = stages.indexOf(currentStage);
    final value = idx < 0 ? 0.0 : (idx) / (stages.length - 1);
    final label = _label(currentStage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Container(height: 6, color: AppGradients.surfaceCard),
              FractionallySizedBox(
                widthFactor: value.clamp(0.02, 1.0),
                child: Container(
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF10B981)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          GradientText(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  String _label(String stage) {
    if (stage.isEmpty) return '-';
    return stage
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .replaceAll('3d', '3D');
  }
}
