import 'package:flutter/material.dart';

import '../design/app_gradients.dart';

/// A single stage in the tracker.
class TrackerStage {
  const TrackerStage(this.label, {this.dateLabel});
  final String label;
  final String? dateLabel; // estimated completion date, shown under the label
}

/// Amazon-style animated progress tracker: connected nodes joined by a thick
/// rounded tube. Completed segments fill green with a check; the current node
/// pulses and shows percent; future nodes/tubes stay grey.
///
/// Drive it with [progress] (0.0–1.0). Supports vertical (mobile) and
/// horizontal (tablet) layouts. Material 3 + the app gradient palette.
class StageTracker extends StatefulWidget {
  const StageTracker({
    super.key,
    required this.stages,
    required this.progress,
    this.orientation = Axis.vertical,
  });

  final List<TrackerStage> stages;
  final double progress; // 0.0 .. 1.0
  final Axis orientation;

  @override
  State<StageTracker> createState() => _StageTrackerState();
}

class _StageTrackerState extends State<StageTracker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  static const Color _green = Color(0xFF10B981);
  static const Color _greenDark = Color(0xFF059669);
  static const Color _grey = Color(0xFF334155);
  static const Color _greyTrack = Color(0xFF1E293B);

  static const double _node = 38;
  static const double _tube = 7;
  static const double _segment = 46;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int get _n => widget.stages.length;
  double get _clamped => widget.progress.clamp(0.0, 1.0);

  /// Position along the track in node units (0 .. n-1).
  double get _pos => _clamped * (_n - 1);
  int get _activeIndex => _clamped >= 1.0 ? _n - 1 : _pos.floor();
  double get _frac => _clamped >= 1.0 ? 0.0 : (_pos - _activeIndex);

  // Node states
  bool _isDone(int i) => _clamped >= 1.0 ? true : i < _activeIndex;
  bool _isCurrent(int i) => _clamped < 1.0 && i == _activeIndex;

  /// Fill fraction (0..1) of the tube segment AFTER node [i].
  double _fill(int i) {
    if (_clamped >= 1.0) return 1.0;
    if (i < _activeIndex) return 1.0;
    if (i == _activeIndex) return _frac;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return widget.orientation == Axis.horizontal
        ? _buildHorizontal()
        : _buildVertical();
  }

  // ─────────────────────────── Node ───────────────────────────
  Widget _nodeWidget(int i) {
    final done = _isDone(i);
    final current = _isCurrent(i);
    final core = Container(
      width: _node,
      height: _node,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done || current
            ? const LinearGradient(colors: [_green, _greenDark])
            : null,
        color: (done || current) ? null : _grey,
        border: Border.all(
          color: current
              ? _green
              : done
                  ? _greenDark
                  : const Color(0xFF475569),
          width: 2,
        ),
        boxShadow: (done || current)
            ? [BoxShadow(color: _green.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: Icon(
        done
            ? Icons.check_rounded
            : current
                ? Icons.bolt_rounded
                : Icons.circle,
        color: done || current ? Colors.white : const Color(0xFF64748B),
        size: done || current ? 20 : 8,
      ),
    );

    if (!current) return core;

    // Pulsing glow ring for the current node.
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final t = _pulse.value;
        return SizedBox(
          width: _node + 18,
          height: _node + 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: _node + 6 + (12 * t),
                height: _node + 6 + (12 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green.withValues(alpha: 0.25 * (1 - t)),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: core,
    );
  }

  // ─────────────────────────── Vertical ───────────────────────────
  Widget _buildVertical() {
    final rail = _node + 18; // width reserved for the node + glow
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _n; i++) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: rail,
                  child: Column(
                    children: [
                      SizedBox(
                        height: rail,
                        child: Center(child: _nodeWidget(i)),
                      ),
                      if (i < _n - 1)
                        Expanded(child: _verticalTube(i)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _label(i, bottomPad: i < _n - 1 ? 28 : 8)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _verticalTube(int i) {
    final fill = _fill(i);
    return Center(
      child: SizedBox(
        width: _tube,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_tube),
          child: Stack(
            children: [
              Container(color: _greyTrack),
              Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: fill,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    width: _tube,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_green, _greenDark],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Horizontal ───────────────────────────
  Widget _buildHorizontal() {
    final children = <Widget>[];
    for (int i = 0; i < _n; i++) {
      children.add(_horizontalNodeColumn(i));
      if (i < _n - 1) children.add(Expanded(child: _horizontalTube(i)));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _horizontalNodeColumn(int i) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          SizedBox(height: _node + 18, child: Center(child: _nodeWidget(i))),
          const SizedBox(height: 6),
          _label(i, center: true, bottomPad: 0),
        ],
      ),
    );
  }

  Widget _horizontalTube(int i) {
    final fill = _fill(i);
    return Padding(
      padding: EdgeInsets.only(top: (_node + 18) / 2 - _tube / 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_tube),
        child: Stack(
          children: [
            Container(height: _tube, color: _greyTrack),
            FractionallySizedBox(
              widthFactor: fill,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: _tube,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_green, _greenDark]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Label ───────────────────────────
  Widget _label(int i, {bool center = false, double bottomPad = 8}) {
    final done = _isDone(i);
    final current = _isCurrent(i);
    final stage = widget.stages[i];
    final color = done
        ? _green
        : current
            ? AppGradients.textPrimary
            : AppGradients.textSecondary;
    final percent = (widget.progress * 100).round();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad, top: 6),
      child: Column(
        crossAxisAlignment:
            center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            stage.label,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: color,
              fontSize: center ? 11 : 14,
              fontWeight: (done || current) ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (current)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_green, _greenDark]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$percent% complete',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          if (stage.dateLabel != null && !center)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                stage.dateLabel!,
                style: const TextStyle(
                    color: AppGradients.textSecondary, fontSize: 11),
              ),
            ),
          if (stage.dateLabel != null && center)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                stage.dateLabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppGradients.textSecondary, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }
}
