import 'package:flutter/material.dart';

import '../design/app_gradients.dart';

/// The standard ICMS gradient card container used for every card/panel.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderRadius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;

  static BoxDecoration decoration({double radius = 16}) => BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppGradients.surfaceCard, AppGradients.surfaceDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppGradients.borderGlow, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      margin: margin,
      decoration: decoration(radius: borderRadius),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onTap,
      child: content,
    );
  }
}
