/// Phase 3 design tokens: radius, motion, typography, gradients and
/// accessibility helpers.
///
/// Colour and spacing tokens (`AppColors`, `AppSpacing`) stay in
/// `core/theme/app_theme.dart`, where every existing screen already imports
/// them from - moving them would mean touching every file in the app for no
/// visual benefit. Everything new for the Phase 3 redesign lives here
/// instead, built on top of those existing tokens. See
/// `docs/design-system.md` for the full reference.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

/// Corner radii. `AppSpacing.cardRadius` / `buttonRadius` / `chipRadius`
/// still exist and are equal to `lg` / `md` / `pill` below - kept so
/// pre-Phase-3 screens keep compiling unchanged. New code should use
/// `AppRadius` directly for the extra steps (`xs`, `sm`, `xl`) it adds.
class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16; // == AppSpacing.buttonRadius
  static const double lg = 20; // == AppSpacing.cardRadius
  static const double xl = 28;
  static const double pill = 999; // == AppSpacing.chipRadius
}

/// Durations and curves, so every animation in the redesign moves at one of
/// a small number of consistent speeds rather than a new magic number per
/// widget.
class AppMotion {
  const AppMotion._();

  /// A state change so small it should barely register as an animation -
  /// a button's press-down scale, a chip's selection fill.
  static const Duration instant = Duration(milliseconds: 100);

  /// The default for most UI transitions: a card appearing, a page element
  /// fading in.
  static const Duration fast = Duration(milliseconds: 180);

  /// Bigger movements - a card expanding, a route transition.
  static const Duration normal = Duration(milliseconds: 280);

  /// Deliberately slow, attention-holding motion - the mascot's idle
  /// animation, a progress ring filling.
  static const Duration slow = Duration(milliseconds: 450);

  /// The pronunciation result reveal and celebration burst. Slow enough for
  /// a child to actually watch it happen, not just notice it happened.
  static const Duration celebration = Duration(milliseconds: 900);

  /// Default motion for anything that isn't explicitly playful - fills,
  /// fades, size changes.
  static const Curve standard = Curves.easeOutCubic;

  /// A little overshoot - buttons, cards, anything that should feel like it
  /// has weight when it lands.
  static const Curve emphasized = Curves.easeOutBack;

  /// Deliberately springy - reserved for celebration moments (the result
  /// score reveal, a badge unlocking), not general-purpose UI, so it stays
  /// meaningful when it appears.
  static const Curve bouncy = Curves.elasticOut;

  /// Idle, ambient motion - the mascot's breathing/bobbing loop.
  static const Curve gentle = Curves.easeInOut;
}

/// Named text styles beyond what `Theme.of(context).textTheme` already
/// covers (see `AppTheme._textTheme` in `app_theme.dart`) - specifically the
/// large, attention-holding numerals the redesign needs for a streak count,
/// an XP total, or a pronunciation score, which the existing scale has
/// nothing bigger than `headlineLarge` (32px) for.
class AppTypography {
  const AppTypography._();

  /// A hero number - the score on the result screen, a big XP total.
  static TextStyle get display => GoogleFonts.nunito(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  /// One step down from `display` - still a "look at this number" size, but
  /// for a secondary figure sitting next to the hero number.
  static TextStyle get statNumber => GoogleFonts.nunito(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// A short, celebratory line under the hero number - "Amazing job!".
  static TextStyle get celebration => GoogleFonts.nunito(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// A mascot's speech-bubble line - warm, slightly smaller than body text,
  /// always paired with `AppColors.textPrimary` regardless of the bubble's
  /// fill colour (see `AppA11y.textColorFor`).
  static TextStyle get mascotSpeech => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
}

/// Gradient fills for the "premium" hero surfaces - the Home greeting card,
/// the primary CTA button, the Speaking Practice mic button. Plain flat
/// colour is used everywhere else; a gradient on every surface would cheapen
/// the effect these are meant to have.
class AppGradients {
  const AppGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDark],
  );

  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4CC373), AppColors.greenStrong],
  );

  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.amber, Color(0xFFF29A3E)],
  );

  static const LinearGradient sky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7FB0FF), AppColors.blue],
  );
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
  ///
  /// If neither choice actually clears AA, this still returns the better of
  /// the two rather than throwing - silently guessing wrong is preferable to
  /// crashing a child's result screen, but a caller relying on this for a
  /// *new* colour should check `contrastRatio` itself rather than trust this
  /// blindly in that case.
  static Color textColorFor(Color background) {
    final withWhite = contrastRatio(Colors.white, background);
    final withDark = contrastRatio(AppColors.textPrimary, background);
    return withWhite >= withDark ? Colors.white : AppColors.textPrimary;
  }
}
