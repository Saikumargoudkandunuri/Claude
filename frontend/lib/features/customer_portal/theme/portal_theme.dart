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
