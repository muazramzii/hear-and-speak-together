import 'package:flutter/material.dart';

import 'colors.dart';

/// Elevation, expressed as soft shadow presets rather than Material's
/// `elevation` integer - a child's UI should read as gently lifted off the
/// page, never as a stack of hard-edged floating panels. Every shadow here
/// is a low-opacity, large-blur, small-offset tint of `textPrimary` (never
/// pure black, which reads harsher than intended at low opacity).
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> none = [];

  /// A resting card - just enough lift to separate it from the background.
  static final List<BoxShadow> small = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// The default for an interactive card or a raised button.
  static final List<BoxShadow> medium = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// A hero surface - the one or two most prominent elements on a screen
  /// (see `HeroCard`, the Speaking Practice mic button).
  static final List<BoxShadow> large = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  /// A coloured glow instead of a neutral shadow - for a surface whose own
  /// fill colour should bleed softly into the shadow (a gradient button or
  /// card). Pass the surface's own dominant colour.
  static List<BoxShadow> glow(Color color, {double alpha = 0.35}) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
