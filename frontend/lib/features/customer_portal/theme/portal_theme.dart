import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium customer-portal design tokens.
///
/// Brand-aligned palette, typography (Playfair Display for headings, Inter
/// for body), and a set of reusable animated widgets. Every customer portal
/// screen imports from here. White theme only — no dark backgrounds.
class PortalColors {
  static const primary = Color(0xFF00D1DC);
  static const primaryDark = Color(0xFF008C86);
  static const accent = Color(0xFFFFB300); // gold
  static const success = Color(0xFF22C55E);
  static const neutral = Color(0xFFF8FAFC);
  static const text = Color(0xFF0F1A2A);
  static const textSoft = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const cardBg = Color(0xFFFFFFFF);
  static const shimmer1 = Color(0xFFF1F5F9);
  static const shimmer2 = Color(0xFFE2E8F0);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}

/// Typography helpers. Headings use Playfair Display, body uses Inter.
class PortalText {
  static TextStyle hero({double size = 32, Color color = PortalColors.text}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  static TextStyle heading({
    double size = 22,
    Color color = PortalColors.text,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      );

  static TextStyle body({double size = 14, Color color = PortalColors.text}) =>
      GoogleFonts.inter(fontSize: size, color: color, height: 1.5);

  static TextStyle label({
    double size = 12,
    Color color = PortalColors.textSoft,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.3,
      );

  static TextStyle number({
    double size = 28,
    Color color = PortalColors.primary,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle caption({
    double size = 11,
    Color color = PortalColors.textSoft,
  }) =>
      GoogleFonts.inter(fontSize: size, color: color, height: 1.4);
}

/// A soft white card with a subtle border and optional tap + gradient.
class PortalCard extends StatelessWidget {
  const PortalCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = 20,
    this.elevation = 0,
    this.onTap,
    this.gradient,
    this.border,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double radius;
  final double elevation;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? PortalColors.cardBg) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: PortalColors.border, width: 0.8),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: PortalColors.primary.withValues(alpha: 0.06),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: PortalColors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Number that animates (counts up) from 0 (or previous value) to [value].
class AnimatedNumber extends StatefulWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _prev = old.value;
      _anim = Tween<double>(begin: _prev, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '${widget.prefix}${_anim.value.toInt()}${widget.suffix}',
        style: widget.style ?? PortalText.number(),
      ),
    );
  }
}

/// A shimmering placeholder block used while content loads.
class PortalShimmer extends StatefulWidget {
  const PortalShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<PortalShimmer> createState() => _PortalShimmerState();
}

class _PortalShimmerState extends State<PortalShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: const [
              PortalColors.shimmer1,
              PortalColors.shimmer2,
              PortalColors.shimmer1,
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated horizontal progress bar (0.0–1.0) with a gradient fill.
class PortalProgressBar extends StatefulWidget {
  const PortalProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 8,
  });

  final double value; // 0.0 to 1.0
  final Color? color;
  final Color? trackColor;
  final double height;

  @override
  State<PortalProgressBar> createState() => _PortalProgressBarState();
}

class _PortalProgressBarState extends State<PortalProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(PortalProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: old.value, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.color ?? PortalColors.primary;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => LayoutBuilder(
        builder: (_, constraints) => Stack(
          children: [
            Container(
              height: widget.height,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: widget.trackColor ?? PortalColors.border,
                borderRadius: BorderRadius.circular(widget.height),
              ),
            ),
            Container(
              height: widget.height,
              width: constraints.maxWidth * _anim.value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fill, fill.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(widget.height),
                boxShadow: [
                  BoxShadow(
                    color: fill.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pulsing "breathing" dot used to mark the current/active item.
class PortalPulseDot extends StatefulWidget {
  const PortalPulseDot({super.key, this.size = 14, this.color});

  final double size;
  final Color? color;

  @override
  State<PortalPulseDot> createState() => _PortalPulseDotState();
}

class _PortalPulseDotState extends State<PortalPulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? PortalColors.primary;
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final t = _ctrl.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Expanding ripple
                Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 + t,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                // Solid core
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A daily-rotating strategic brand message (fades in once).
class StrategicMessage extends StatefulWidget {
  const StrategicMessage({super.key, this.color = PortalColors.textSoft});

  final Color color;

  @override
  State<StrategicMessage> createState() => _StrategicMessageState();
}

class _StrategicMessageState extends State<StrategicMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  int _index = 0;

  static const _messages = [
    'Every detail. Every finish. Every moment.',
    "We don't just build spaces.\nWe build your dreams.",
    'Luxury is built one detail at a time.',
    "Today's work brings you one step closer\nto your dream home.",
    'Your home deserves patience,\nprecision and passion.',
    'Great homes are not completed overnight.\nThey are perfected every single day.',
    'Every brick we place\nis a promise we keep.',
    'Thank you for trusting us\nwith your most important space.',
    "Our craftsmen don't just build furniture.\nThey build family moments.",
  ];

  @override
  void initState() {
    super.initState();
    _index = DateTime.now().day % _messages.length;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Text(
        _messages[_index],
        style: PortalText.body(size: 13, color: widget.color),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ===========================================================================
// GLASSMORPHISM CARDS (white theme)
//
// Translates the dark "glowing gradient card" inspiration into a light
// version: white translucent surfaces, soft teal-tinted glow shadows (no
// neon), rounded depth and floating numbers. Brand accent #00D1DC only,
// with the gold accent reserved for secondary metrics. Glass is achieved
// with a BackdropFilter blur over a ~75% white surface, so a subtle
// background (e.g. ambient colour blobs) shows through.
// ===========================================================================

/// A frosted white stat tile: icon chip + large number + label, with an
/// optional [trailing] accent (small chart / badge). Soft teal glow shadow.
class GlassStatCard extends StatelessWidget {
  const GlassStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor = PortalColors.primary,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, size: 18, color: accentColor),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: PortalText.number(size: 24, color: PortalColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style:
                      PortalText.label(size: 11, color: PortalColors.textSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted white circular-ring progress tile. The ring animates in once on
/// mount, with the percentage floating in the centre.
class GlassRingCard extends StatefulWidget {
  const GlassRingCard({
    super.key,
    required this.percent,
    required this.label,
    this.accentColor = PortalColors.primary,
  });

  final double percent; // 0–100
  final String label;
  final Color accentColor;

  @override
  State<GlassRingCard> createState() => _GlassRingCardState();
}

class _GlassRingCardState extends State<GlassRingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(begin: 0, end: (widget.percent / 100).clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(88, 88),
                        painter: _RingPainter(
                          progress: _anim.value,
                          color: widget.accentColor,
                        ),
                      ),
                      Text(
                        '${widget.percent.toInt()}%',
                        style: PortalText.number(
                          size: 20,
                          color: PortalColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(widget.label, style: PortalText.label(size: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Faint background ring.
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc (sweeps from 12 o'clock).
    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: -1.5708 + 6.2832,
        colors: [color.withValues(alpha: 0.5), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// A frosted white card with a large number and a smooth line (sparkline)
/// trend, with a soft gradient fill below the line. [dataPoints] are
/// normalised 0.0–1.0.
class GlassSparklineCard extends StatelessWidget {
  const GlassSparklineCard({
    super.key,
    required this.label,
    required this.value,
    required this.dataPoints,
    this.accentColor = PortalColors.primary,
  });

  final String label;
  final String value;
  final List<double> dataPoints;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: PortalText.number(size: 22, color: PortalColors.text),
              ),
              const SizedBox(height: 2),
              Text(label, style: PortalText.label(size: 11)),
              const Spacer(),
              SizedBox(
                height: 32,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    points: dataPoints,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].clamp(0.0, 1.0) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    // Soft gradient fill under the line.
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.points != points;
}

/// A frosted white card with a large number and a compact bar chart. The most
/// recent bar is highlighted in the full accent colour. [bars] are normalised
/// 0.0–1.0.
class GlassBarCard extends StatelessWidget {
  const GlassBarCard({
    super.key,
    required this.label,
    required this.value,
    required this.bars,
    this.accentColor = PortalColors.primary,
  });

  final String label;
  final String value;
  final List<double> bars;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: PortalText.number(size: 22, color: PortalColors.text),
              ),
              const SizedBox(height: 2),
              Text(label, style: PortalText.label(size: 11)),
              const Spacer(),
              SizedBox(
                height: 28,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars.asMap().entries.map((e) {
                    final isLast = e.key == bars.length - 1;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        height: 28 * e.value.clamp(0.1, 1.0),
                        decoration: BoxDecoration(
                          color: isLast
                              ? accentColor
                              : accentColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft ambient colour blobs rendered behind glass cards so the blur has
/// something to refract — the light-theme equivalent of the dark reference's
/// "liquid glass" glow. Drop into a [Stack] before the scrollable body.
class PortalGlassBackdrop extends StatelessWidget {
  const PortalGlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: _blob(200, PortalColors.primary.withValues(alpha: 0.06)),
          ),
          Positioned(
            top: 300,
            left: -60,
            child: _blob(180, PortalColors.accent.withValues(alpha: 0.05)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      );
}
