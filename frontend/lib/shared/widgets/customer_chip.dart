import 'package:flutter/material.dart';

import '../design/app_gradients.dart';

/// Customer name shown as the PRIMARY identifier with a per-site unique
/// gradient (DESIGN SYSTEM: customer name highlight rule).
class CustomerChip extends StatelessWidget {
  const CustomerChip({
    super.key,
    required this.customerName,
    required this.seed,
    this.fontSize = 18,
  });

  /// Customer display name.
  final String customerName;

  /// Unique seed per site (e.g. project id) → deterministic color.
  final String seed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppGradients.forSeed(seed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors.map((c) => c.withValues(alpha: 0.18)).toList(),
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.first.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: fontSize * 0.85, color: colors.first),
          const SizedBox(width: 6),
          Flexible(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (b) => LinearGradient(colors: colors).createShader(
                Rect.fromLTWH(0, 0, b.width, b.height),
              ),
              child: Text(
                customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
