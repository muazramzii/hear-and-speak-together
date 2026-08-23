import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Nunito throughout - rounded letterforms are friendlier and, for early
/// readers, easier to tell apart than a geometric sans. This is the app's
/// only typeface; every text style anywhere is built from it.
///
/// `AppTypography` exposes the six-level hierarchy the design system is
/// specified around (Display, H1, H2, H3, Body, Caption) for direct use in
/// new widgets. `buildTextTheme` below produces the full Material
/// `TextTheme` (11 slots) that `ThemeData` needs and every screen written
/// before this refactor already reads via `Theme.of(context).textTheme` -
/// its values are unchanged from before this refactor, so relocating it
/// here changes zero pixels.
class AppTypography {
  const AppTypography._();

  /// A hero number - the pronunciation score, a big XP total. Only ever one
  /// of these on screen at a time.
  static TextStyle get display => GoogleFonts.nunito(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  /// == the Material `headlineLarge` slot below.
  static TextStyle get h1 => GoogleFonts.nunito(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// == the Material `headlineMedium` slot below.
  static TextStyle get h2 => GoogleFonts.nunito(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// == the Material `titleLarge` slot below.
  static TextStyle get h3 => GoogleFonts.nunito(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// == the Material `bodyLarge` slot below.
  static TextStyle get body => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// A small supporting line - a hint, a timestamp, a helper label under a
  /// field. Distinct from the Material `labelSmall` slot (12px, used for
  /// dense chip/tag text) - this is for a short sentence, not a tag.
  static TextStyle get caption => GoogleFonts.nunito(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// One step down from [display] - a secondary figure next to the hero
  /// number.
  static TextStyle get statNumber => GoogleFonts.nunito(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// A short, celebratory line under a hero number - "Amazing job!".
  static TextStyle get celebration => GoogleFonts.nunito(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// The mascot's speech-bubble line - warm, slightly smaller than body
  /// text. Carries no colour of its own; pair it with whatever is legible
  /// on the bubble's fill (see `AppA11y.textColorFor`).
  static TextStyle get mascotSpeech =>
      GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700);

  /// The full Material `TextTheme` for `ThemeData`. Unchanged from the
  /// pre-refactor `AppTheme._textTheme` - every screen already reads these
  /// slots via `Theme.of(context).textTheme`.
  static TextTheme buildTextTheme(TextTheme base) {
    return GoogleFonts.nunitoTextTheme(base).copyWith(
      headlineLarge: h1,
      headlineMedium: h2,
      titleLarge: h3,
      titleMedium: GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: body,
      bodyMedium: GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
