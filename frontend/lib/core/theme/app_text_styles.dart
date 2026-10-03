import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Two families, one job each:
/// - Plus Jakarta Sans: headings & numbers — friendly, geometric, confident.
/// - Inter: body & UI — the most legible face at 12–16px.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _head(double size, {FontWeight w = FontWeight.w700, Color c = AppColors.textPrimary, double h = 1.2, double ls = -0.2}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

  static TextStyle _body(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textPrimary, double h = 1.5, double ls = 0}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

  // Display
  static TextStyle displayLg = _head(34, w: FontWeight.w800, h: 1.1, ls: -0.8);
  static TextStyle displayMd = _head(28, w: FontWeight.w800, h: 1.15, ls: -0.6);
  static TextStyle displaySm = _head(22, w: FontWeight.w700, h: 1.25, ls: -0.3);

  // Headings
  static TextStyle h1 = _head(21, h: 1.3);
  static TextStyle h2 = _head(17, h: 1.3, ls: -0.1);
  static TextStyle h3 = _head(15, w: FontWeight.w600, h: 1.35, ls: 0);

  // Body
  static TextStyle bodyLg = _body(16);
  static TextStyle bodyMd = _body(14.5);
  static TextStyle bodySm = _body(13, c: AppColors.textSecondary, h: 1.45);

  // UI
  static TextStyle button = _body(15, w: FontWeight.w600, h: 1.0, ls: 0.1);
  static TextStyle label = _body(12.5, w: FontWeight.w600, c: AppColors.textSecondary, ls: 0.1);
  static TextStyle caption = _body(11.5, w: FontWeight.w500, c: AppColors.textMuted);
}
