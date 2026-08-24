import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'parent_colors.dart';

export 'parent_colors.dart';

/// Carries the active [ParentPalette] through `Theme.of(context)`, so every
/// Parent Mode widget reads colours the same way the rest of the app reads
/// `Theme.of(context).textTheme` - no separate InheritedWidget, no global
/// singleton that light/dark mode would have to mutate.
class ParentThemeExtension extends ThemeExtension<ParentThemeExtension> {
  const ParentThemeExtension(this.palette);

  final ParentPalette palette;

  @override
  ParentThemeExtension copyWith({ParentPalette? palette}) {
    return ParentThemeExtension(palette ?? this.palette);
  }

  @override
  ParentThemeExtension lerp(ParentThemeExtension? other, double t) {
    // Palettes are swapped, not animated, between light and dark - a
    // mid-lerp analytics screen would be unreadable.
    return t < 0.5 ? this : (other ?? this);
  }
}

extension ParentThemeContext on BuildContext {
  ParentPalette get parentColors =>
      Theme.of(this).extension<ParentThemeExtension>()?.palette ??
      ParentPalette.light;
}

/// Builds Parent Mode's `ThemeData` - Inter rather than the child app's
/// rounded Nunito, minimal elevation, and no gradient buttons: analytics
/// chrome should recede behind the data, not compete with it.
class ParentTheme {
  const ParentTheme._();

  static ThemeData build(ParentPalette palette) {
    final base = ThemeData(
      useMaterial3: true,
      brightness:
          palette.background.computeLuminance() > 0.5
              ? Brightness.light
              : Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.indigo,
        brightness:
            palette.background.computeLuminance() > 0.5
                ? Brightness.light
                : Brightness.dark,
        primary: palette.indigo,
        surface: palette.surface,
        error: palette.amber,
      ),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 15, color: palette.textPrimary),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13.5,
        color: palette.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: palette.textSecondary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.textPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.indigoSoft,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color:
                states.contains(WidgetState.selected)
                    ? palette.indigo
                    : palette.textSecondary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.indigo,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.indigo,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? palette.indigo
                  : palette.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? palette.indigoSoft
                  : palette.border,
        ),
      ),
      extensions: [ParentThemeExtension(palette)],
    );
  }

  static final light = build(ParentPalette.light);
  static final dark = build(ParentPalette.dark);
}
