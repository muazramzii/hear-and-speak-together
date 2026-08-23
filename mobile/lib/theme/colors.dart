import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Semantic colour tokens for Hear & Speak Together.
///
/// Every colour a widget needs has a name here - nothing should be
/// hardcoded as a raw `Color(0x...)` inside a screen. The palette's mood is
/// deliberately restrained: soft purple (primary), sky blue (secondary) and
/// warm yellow (accent), not a rainbow of equally-loud accents. Text always
/// sits on the solid tones, never on the soft tints, which exist for card
/// fills only.
class AppColors {
  const AppColors._();

  // ---- Brand / semantic (the three-colour mood: purple, blue, yellow) ----
  static const Color primary = Color(0xFF7C5CE0); // soft purple
  static const Color primaryDark = Color(0xFF5F42B8);
  static const Color secondary = Color(0xFF5B8DEF); // sky blue
  static const Color secondaryDark = Color(0xFF3270EB);
  static const Color accent = Color(0xFFF7C33F); // warm yellow

  // ---- Content-mode accents. A wider set than the brand's three colours
  // above, used only to tell the four learning modes (and similar content
  // groupings, e.g. achievement categories) apart visually - not part of
  // the core brand mood, and never used for a plain UI action or status.
  static const Color amber = accent;
  static const Color blue = secondary;
  static const Color green = Color(0xFF35A85A);
  static const Color coral = Color(0xFFEF5F5F);
  static const Color pink = Color(0xFFEE5FA7);

  // ---- Status ----
  static const Color success = green;
  static const Color warning = Color(0xFFE8A020);
  static const Color error = coral;

  // ---- Soft card fills. Never used behind body text. ----
  static const Color amberSoft = Color(0xFFFFF6DA);
  static const Color blueSoft = Color(0xFFE6F0FF);
  static const Color greenSoft = Color(0xFFE8F7EE);
  static const Color violetSoft = Color(0xFFF0E9FF);
  static const Color pinkSoft = Color(0xFFFDE8F2);

  // ---- "Strong" accents: darkened in HSL space (hue/saturation held fixed)
  // until white text on top clears WCAG AA for normal-size text (4.5:1).
  // The plain accents above only clear the *large-text* threshold (3:1) with
  // white on top - fine for icons or an 18pt+ headline, not for a button
  // label or chip text at body size. Use these instead wherever white text
  // sits on the fill at normal sizes. (Accent/amber and warning are
  // deliberately excluded - see `textOnAccent` below.)
  static const Color greenStrong = Color(0xFF2B8748);
  static const Color successStrong = greenStrong;
  static const Color coralStrong = Color(0xFFE91F1F);
  static const Color errorStrong = coralStrong;
  static const Color pinkStrong = Color(0xFFE2187E);
  static const Color blueStrong = Color(0xFF3270EB);
  static const Color secondaryStrong = blueStrong;

  // ---- Neutrals ----
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F7FC);

  /// A second surface tone for layering one card on top of another (or on
  /// top of the background) without a border - a light violet tint, distinct
  /// from both `surface` (pure white) and `background`.
  static const Color surfaceVariant = Color(0xFFF3F1FA);

  static const Color border = Color(0xFFE4E6EF);
  static const Color textPrimary = Color(0xFF1F2233);

  // Darkened from an original 0xFF7A7F8C, which measured 3.76:1 on
  // `background` and 4.01:1 on `surface` - short of WCAG AA's 4.5:1 for
  // normal-size text despite looking fine at a glance. This value clears
  // 4.5:1 against both. See docs/design-system.md.
  static const Color textSecondary = Color(0xFF6D727F);

  /// Accent/amber and its darker `warning` twin cannot be darkened enough to
  /// carry white text (4.5:1) without turning muddy brown and losing the
  /// colour entirely - unlike green/coral/pink/blue above, where a "strong"
  /// variant stays recognisably the same hue. Dark text is the only correct
  /// choice on either, always - measured at 9.6:1 and 7.1:1 respectively,
  /// comfortably clearing AA. There is no "strong" accent to darken instead;
  /// use `textPrimary` directly.
  static const Color textOnAccent = textPrimary;
}

/// WCAG contrast, computed rather than eyeballed, so a new colour pairing
/// can be checked the same way the palette itself was (see
/// `docs/design-system.md` for the worked numbers behind `textSecondary`,
/// `greenStrong`, etc.).
class AppA11y {
  const AppA11y._();

  static const double minimumBodyContrast = 4.5; // WCAG AA, normal text
  static const double minimumLargeTextContrast =
      3.0; // WCAG AA, 18pt+/14pt+bold
  static const double minimumUiContrast = 3.0; // WCAG 1.4.11, icons/controls

  static double _linearChannel(double c) {
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// WCAG relative luminance, 0 (black) to 1 (white).
  static double relativeLuminance(Color color) {
    final r = _linearChannel(color.r);
    final g = _linearChannel(color.g);
    final b = _linearChannel(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// The WCAG contrast ratio between two colours, from 1 (identical) to 21
  /// (black on white).
  static double contrastRatio(Color a, Color b) {
    final lighter = math.max(relativeLuminance(a), relativeLuminance(b));
    final darker = math.min(relativeLuminance(a), relativeLuminance(b));
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Picks whichever of white or `AppColors.textPrimary` clears
  /// [minimumBodyContrast] against `background` - and if both do, the one
  /// that clears it by more, so the choice is never arbitrary. Meant for
  /// components that render on a caller-supplied colour (a category's icon
  /// tint, an achievement's accent) and cannot know ahead of time whether
  /// that colour is light or dark.
  static Color textColorFor(Color background) {
    final withWhite = contrastRatio(Colors.white, background);
    final withDark = contrastRatio(AppColors.textPrimary, background);
    return withWhite >= withDark ? Colors.white : AppColors.textPrimary;
  }
}
