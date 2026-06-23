import 'package:flutter/material.dart';

import '../design/app_gradients.dart';

/// Dependency-free shimmer loading placeholder (animated gradient sweep).
class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({
    super.key,
    this.height = 80,
    this.width = double.infinity,
    this.borderRadius = 16,
    this.count = 1,
  });

  final double height;
  final double width;
  final double borderRadius;
  final int count;

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.count, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == widget.count - 1 ? 0 : 12),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = (_controller.value * 2) - 1; // -1 → 1
              return Container(
                height: widget.height,
                width: widget.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment(dx - 0.3, 0),
                    end: Alignment(dx + 0.3, 0),
                    colors: const [
                      AppGradients.surfaceCard,
                      AppGradients.surfaceElevated,
                      AppGradients.surfaceCard,
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
