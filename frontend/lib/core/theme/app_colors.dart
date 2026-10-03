import 'package:flutter/material.dart';

/// Design language: "Lavender on white".
///
/// - PRIMARY (dominant) colour is white: every screen background and card.
///   Whitespace does the structuring; borders are whisper-light.
/// - SECONDARY colour is light purple, used in three deliberate ways:
///     tints  (lavender50/100/200) -> fills for inputs, chips, assistant
///                                    bubbles, selected states
///     accent (lavender400)        -> decorative shapes, progress, icons
///     action (brand / brandDeep)  -> buttons, links, user bubbles
/// - `brand` is a slightly deeper violet than pure "light purple" ON
///   PURPOSE: white text on #B7A5FA is only ~2.3:1 contrast (fails
///   accessibility); on #7157DB it is ~5.1:1 (passes AA).
class AppColors {
  AppColors._();

  static const Color white = Color(0xFFFFFFFF);

  // Lavender scale
  static const Color lavender50 = Color(0xFFF9F7FF);
  static const Color lavender100 = Color(0xFFF1EDFF);
  static const Color lavender200 = Color(0xFFE4DCFF);
  static const Color lavender300 = Color(0xFFD1C4FF);
  static const Color lavender400 = Color(0xFFB7A5FA); // the "light purple"
  static const Color lavender500 = Color(0xFF9C86F2);

  // Action colours (AA contrast with white text)
  static const Color brand = Color(0xFF7157DB);
  static const Color brandDeep = Color(0xFF5A41C4);

  // Surfaces
  static const Color bg = white;
  static const Color surface = white;
  static const Color surfaceAlt = lavender50;
  static const Color border = Color(0xFFECE8F8);
  static const Color divider = Color(0xFFF1EEFA);

  // Text (neutral with a faint violet cast so it harmonises)
  static const Color textPrimary = Color(0xFF1F1B33);
  static const Color textSecondary = Color(0xFF645F7D);
  static const Color textMuted = Color(0xFF7F7A99);

  // Semantic
  static const Color success = Color(0xFF2E9E75);
  static const Color successSoft = Color(0xFFDDF3EA);
  static const Color error = Color(0xFFD14B58);
  static const Color errorSoft = Color(0xFFFBE6E8);
  static const Color info = Color(0xFF4A82C4);
  static const Color infoSoft = Color(0xFFE2EEFA);

  // Question-classifier tags
  static const Color tagFactual = Color(0xFF4A82C4);
  static const Color tagSummarization = Color(0xFF7157DB);
  static const Color tagComparison = Color(0xFFC77D2E);
  static const Color tagRetrieval = Color(0xFF2E9E75);

  // Third-party brand colours (social buttons)
  static const Color google = Color(0xFF4285F4);
  static const Color facebook = Color(0xFF1877F2);
}
