import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/portal_theme.dart';

/// A celebratory overlay shown once when a project stage is completed.
///
/// Renders gold + teal confetti, a congratulatory card, and auto-dismisses
/// after ~3 seconds. Use [MilestoneCelebrationOverlay.showOnce] to ensure the
/// same milestone never celebrates twice (persisted via shared_preferences).
class MilestoneCelebrationOverlay extends StatefulWidget {
  const MilestoneCelebrationOverlay({
    super.key,
    required this.stageName,
    required this.nextStageName,
    required this.onDismiss,
    this.completedOn,
    this.onViewJourney,
  });

  final String stageName;
  final String nextStageName;
  final String? completedOn;
  final VoidCallback onDismiss;
  final VoidCallback? onViewJourney;

  /// Shows the celebration once per [stageKey]. Returns true if shown.
  static Future<bool> showOnce(
    BuildContext context, {
    required String stageKey,
    required String stageName,
    required String nextStageName,
    String? completedOn,
    VoidCallback? onViewJourney,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'celebrated_$stageKey';
    if (prefs.getBool(key) == true) return false;
    await prefs.setBool(key, true);

    if (!context.mounted) return false;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Milestone',
      barrierColor: Colors.white.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => MilestoneCelebrationOverlay(
        stageName: stageName,
        nextStageName: nextStageName,
        completedOn: completedOn,
        onViewJourney: onViewJourney,
        onDismiss: () => Navigator.of(ctx).maybePop(),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final scale = Tween<double>(begin: 0.85, end: 1.0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack));
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
    return true;
  }

  @override
  State<MilestoneCelebrationOverlay> createState() =>
      _MilestoneCelebrationOverlayState();
}

class _MilestoneCelebrationOverlayState
    extends State<MilestoneCelebrationOverlay> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti =
        ConfettiController(duration: const Duration(milliseconds: 2500));
    _confetti.play();
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetti bursting from top center, downward.
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: math.pi / 2, // downward
            emissionFrequency: 0.05,
            numberOfParticles: 16,
            maxBlastForce: 22,
            minBlastForce: 8,
            gravity: 0.25,
            shouldLoop: false,
            colors: const [
              PortalColors.primary,
              PortalColors.accent,
              PortalColors.primaryDark,
              PortalColors.success,
            ],
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: PortalColors.cardBg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: PortalColors.primary.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    size: 56,
                    color: PortalColors.accent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Milestone Complete!',
                    style: PortalText.heading(
                      size: 24,
                      color: PortalColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.stageName} — Done',
                    style: PortalText.body(size: 16).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.completedOn != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Completed on ${widget.completedOn}',
                      style: PortalText.caption(size: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (widget.nextStageName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Next: ${widget.nextStageName} begins soon',
                      style: PortalText.body(
                        size: 13,
                        color: PortalColors.primary,
                      ).copyWith(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        widget.onDismiss();
                        widget.onViewJourney?.call();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: PortalColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'View your project journey →',
                        style: PortalText.body(size: 14, color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
