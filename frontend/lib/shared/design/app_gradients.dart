import 'package:flutter/material.dart';

/// Futuristic SaaS gradient design tokens (ICMS v2.0 design system).
class AppGradients {
  AppGradients._();

  // Brand gradients
  static const List<Color> primary = [Color(0xFF6C63FF), Color(0xFF3B82F6)];
  static const List<Color> success = [Color(0xFF10B981), Color(0xFF059669)];
  static const List<Color> warning = [Color(0xFFF59E0B), Color(0xFFEF4444)];
  static const List<Color> danger = [Color(0xFFEF4444), Color(0xFFDC2626)];

  // Surfaces
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceCard = Color(0xFF1E293B);
  static const Color surfaceElevated = Color(0xFF334155);

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  static Color get borderGlow => const Color(0xFF6C63FF).withValues(alpha: 0.35);

  /// Per-site unique color rotation (customer chips).
  static const List<List<Color>> siteColors = [
    [Color(0xFF6C63FF), Color(0xFF3B82F6)], // violet-blue
    [Color(0xFF10B981), Color(0xFF3B82F6)], // emerald-blue
    [Color(0xFFF59E0B), Color(0xFFEF4444)], // amber-red
    [Color(0xFFEC4899), Color(0xFF8B5CF6)], // pink-purple
    [Color(0xFF06B6D4), Color(0xFF3B82F6)], // cyan-blue
    [Color(0xFF84CC16), Color(0xFF10B981)], // lime-emerald
  ];

  /// Deterministic per-site gradient based on an id/seed.
  static List<Color> forSeed(String seed) {
    final idx = seed.hashCode.abs() % siteColors.length;
    return siteColors[idx];
  }
}
