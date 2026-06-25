import 'package:flutter/material.dart';

import '../design/app_gradients.dart';

/// Primary gradient action button with a tap scale-down animation.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.gradient = AppGradients.primary,
    this.expand = false,
    this.busy = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color> gradient;
  final bool expand;
  final bool busy;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _scale = 0.96) : null,
      onTapUp: enabled ? (_) => setState(() => _scale = 1) : null,
      onTapCancel: enabled ? () => setState(() => _scale = 1) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Container(
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: widget.gradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.first.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.busy)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, color: Colors.white, size: 18),
                if (widget.label != null) ...[
                  if (widget.icon != null || widget.busy)
                    const SizedBox(width: 8),
                  Text(
                    widget.label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
