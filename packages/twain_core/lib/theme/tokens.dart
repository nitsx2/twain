import 'package:flutter/material.dart';

/// Design tokens for Twain AI. Use these instead of hardcoded values.
class TTokens {
  TTokens._();

  // Primary: slate blue (medical trust)
  static const primary50 = Color(0xFFEEF2FF);
  static const primary100 = Color(0xFFE0E7FF);
  static const primary200 = Color(0xFFC7D2FE);
  static const primary300 = Color(0xFFA5B4FC);
  static const primary400 = Color(0xFF818CF8);
  static const primary500 = Color(0xFF6366F1);
  static const primary600 = Color(0xFF4F46E5);
  static const primary700 = Color(0xFF4338CA);
  static const primary800 = Color(0xFF3730A3);
  static const primary900 = Color(0xFF1E3A8A); // main
  static const primary950 = Color(0xFF172554);

  // AI accent: teal (Twain + Brain)
  static const ai50 = Color(0xFFF0FDFA);
  static const ai100 = Color(0xFFCCFBF1);
  static const ai200 = Color(0xFF99F6E4);
  static const ai300 = Color(0xFF5EEAD4);
  static const ai400 = Color(0xFF2DD4BF);
  static const ai500 = Color(0xFF14B8A6); // main
  static const ai600 = Color(0xFF0D9488);
  static const ai700 = Color(0xFF0F766E);

  // Neutral slate scale
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF8FAFC);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral400 = Color(0xFF94A3B8);
  static const neutral500 = Color(0xFF64748B);
  static const neutral600 = Color(0xFF475569);
  static const neutral700 = Color(0xFF334155);
  static const neutral800 = Color(0xFF1E293B);
  static const neutral900 = Color(0xFF0F172A);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0EA5E9);

  // Spacing (4pt grid)
  static const s0 = 0.0;
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s7 = 28.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s16 = 64.0;
  static const s20 = 80.0;

  // Radii
  static const r2 = 4.0;
  static const r3 = 6.0;
  static const r4 = 8.0;
  static const r5 = 10.0;
  static const r6 = 12.0;
  static const r8 = 16.0;
  static const rFull = 9999.0;

  // Shadows
  static const shadowSm = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const shadowMd = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const shadowLg = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  // Motion
  static const duration150 = Duration(milliseconds: 150);
  static const duration200 = Duration(milliseconds: 200);
  static const curveStd = Curves.easeOut;
  static const curveEmphasized = Curves.easeInOutCubic;
}
