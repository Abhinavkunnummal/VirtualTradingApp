import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle get displayLg => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.96,
        color: AppColors.onSurface,
      );

  static TextStyle get displaySm => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        letterSpacing: -0.48,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        letterSpacing: -0.3,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineSm => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        letterSpacing: -0.16,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        letterSpacing: -0.075,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        letterSpacing: 0,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get labelMd => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.12,
        color: AppColors.onSurface,
      );

  static TextStyle get labelSm => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.44,
        color: AppColors.outline,
      );

  // Tabular figures for rapid real-time financial telemetry scanning
  static TextStyle get numericHeadline => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 32 / 26,
        letterSpacing: -0.5,
        color: AppColors.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get numericTicker => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 26 / 20,
        letterSpacing: -0.4,
        color: AppColors.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get numericSubhead => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
        letterSpacing: -0.2,
        color: AppColors.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get numericTable => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 18 / 13,
        letterSpacing: 0,
        color: AppColors.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get numericSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 15 / 11,
        letterSpacing: 0.2,
        color: AppColors.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
