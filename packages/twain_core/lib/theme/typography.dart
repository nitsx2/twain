import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TTypography {
  TTypography._();

  static TextTheme textTheme(Color onSurface) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 48, height: 1.16, fontWeight: FontWeight.w700,
        color: onSurface, letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 40, height: 1.2, fontWeight: FontWeight.w700,
        color: onSurface, letterSpacing: -0.4,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 32, height: 1.25, fontWeight: FontWeight.w700,
        color: onSurface, letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 28, height: 1.28, fontWeight: FontWeight.w600, color: onSurface,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24, height: 1.3, fontWeight: FontWeight.w600, color: onSurface,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20, height: 1.4, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18, height: 1.45, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14, height: 1.45, fontWeight: FontWeight.w600, color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, height: 1.55, fontWeight: FontWeight.w400, color: onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, height: 1.55, fontWeight: FontWeight.w400, color: onSurface,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, height: 1.5, fontWeight: FontWeight.w400, color: onSurface,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14, height: 1.4, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12, height: 1.4, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, height: 1.4, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: 0.4,
      ),
    );
  }
}
