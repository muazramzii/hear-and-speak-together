import 'package:flutter/material.dart';

/// The Parent/Teacher Intelligence Platform's own palette - deliberately
/// separate from `theme/colors.dart` (the playful child palette). No purple,
/// no amber-as-brand, no mascot tints: white, slate, indigo, emerald and
/// amber only, matching a professional analytics dashboard rather than a
/// learning game.
///
/// Both a light and dark set are defined here (see [ParentPalette]) rather
/// than as a single fixed `const` class, because Parent Mode supports dark
/// mode as a first-class accessibility requirement, unlike the child app.
class ParentPalette {
  const ParentPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.indigo,
    required this.indigoSoft,
    required this.emerald,
    required this.emeraldSoft,
    required this.amber,
    required this.amberSoft,
    required this.slate,
    required this.slateSoft,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// The one accent colour for primary actions and selection - the
  /// dashboard's equivalent of the child app's brand purple.
  final Color indigo;
  final Color indigoSoft;

  /// Positive movement: score improved, sound mastered.
  final Color emerald;
  final Color emeraldSoft;

  /// Attention, not alarm: a weak sound, a lapsed streak. Never red - a
  /// regression is a fact to note, not a failure to flag.
  final Color amber;
  final Color amberSoft;

  /// Neutral chrome - icons, dividers, secondary chips.
  final Color slate;
  final Color slateSoft;

  static const light = ParentPalette(
    background: Color(0xFFF8FAFC), // slate-50
    surface: Colors.white,
    surfaceAlt: Color(0xFFF1F5F9), // slate-100
    border: Color(0xFFE2E8F0), // slate-200
    textPrimary: Color(0xFF0F172A), // slate-900
    textSecondary: Color(0xFF64748B), // slate-500
    indigo: Color(0xFF4F46E5),
    indigoSoft: Color(0xFFEEF2FF),
    emerald: Color(0xFF059669),
    emeraldSoft: Color(0xFFECFDF5),
    amber: Color(0xFFB45309),
    amberSoft: Color(0xFFFFFBEB),
    slate: Color(0xFF475569),
    slateSoft: Color(0xFFF1F5F9),
  );

  static const dark = ParentPalette(
    background: Color(0xFF0B1120),
    surface: Color(0xFF141B2D),
    surfaceAlt: Color(0xFF1B2436),
    border: Color(0xFF2A3550),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    indigo: Color(0xFF818CF8),
    indigoSoft: Color(0xFF1E2352),
    emerald: Color(0xFF34D399),
    emeraldSoft: Color(0xFF0F2E24),
    amber: Color(0xFFFBBF24),
    amberSoft: Color(0xFF2E2410),
    slate: Color(0xFF94A3B8),
    slateSoft: Color(0xFF1B2436),
  );
}
