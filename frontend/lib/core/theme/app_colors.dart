import 'package:flutter/material.dart';

/// Brand palette. Light, clean, professional — no dark backgrounds.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00D1DC);
  static const Color primaryDark = Color(0xFF00A7B0);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8FAFC); // secondary background
  static const Color border = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  /// Stage chip colors keyed by stage value.
  static const Map<String, Color> stageColors = {
    'discussion': Color(0xFF94A3B8),
    '3d_design': Color(0xFF8B5CF6),
    'drawing': Color(0xFF6366F1),
    'material_purchase': Color(0xFF0EA5E9),
    'cutting': Color(0xFF06B6D4),
    'making': Color(0xFF00D1DC),
    'lamination': Color(0xFF14B8A6),
    'painting': Color(0xFFF59E0B),
    'packing': Color(0xFFEAB308),
    'transport': Color(0xFFF97316),
    'installation': Color(0xFF3B82F6),
    'checking': Color(0xFFA855F7),
    'completed': Color(0xFF16A34A),
  };
}
