import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A responsive grid that lays children into columns sized to the available
/// width. Uses Wrap so it never throws RenderFlex overflow on small phones.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = (width / minItemWidth).floor();
        if (columns < 1) columns = 1;
        if (columns > maxColumns) columns = maxColumns;
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (width - totalSpacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
