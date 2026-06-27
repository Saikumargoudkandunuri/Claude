import 'package:flutter/material.dart';

class CTheme {
  // Brand
  static const primary = Color(0xFF00D1DC);
  static const primaryDark = Color(0xFF00A3AD);
  static const primaryDeep = Color(0xFF006064);

  // Backgrounds
  static const bgWhite = Color(0xFFFFFFFF);
  static const bgSoft = Color(0xFFF7F9FA);
  static const bgCard = Color(0xFFFFFFFF);

  // Text
  static const textDark = Color(0xFF0D1B2A);
  static const textMid = Color(0xFF4A5568);
  static const textLight = Color(0xFF9AA5B1);

  // Semantic
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const inactive = Color(0xFFE2E8F0);

  // Gradients
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D1DC), Color(0xFF006064)],
  );

  // Spacing
  static const double p4 = 4.0;
  static const double p8 = 8.0;
  static const double p12 = 12.0;
  static const double p16 = 16.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p32 = 32.0;

  // Radius
  static const r8 = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));

  // Shadows
  static const cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 1)),
  ];

  static const heroShadow = [
    BoxShadow(color: Color(0x3000D1DC), blurRadius: 32, offset: Offset(0, 8)),
  ];
}
