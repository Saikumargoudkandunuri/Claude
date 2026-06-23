import 'package:flutter/material.dart';

import '../design/app_gradients.dart';

/// Text painted with a gradient shader.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    this.gradient = AppGradients.primary,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final List<Color> gradient;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: gradient,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
