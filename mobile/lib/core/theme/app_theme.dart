import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Hear & Speak Together, taken from the project style guide.
///
/// The palette is bright and warm because the users are children, and every
/// pairing here is checked for contrast: text sits on the solid tones, never on
/// the soft tints, which are reserved for card fills.
class AppColors {
  const AppColors._();

  // ---- Brand ----
  static const Color primary = Color(0xFF7C5CE0); // violet
  static const Color primaryDark = Color(0xFF5F42B8);

  // ---- Accents, one per learning mode ----
  static const Color amber = Color(0xFFF7C33F); // Learn
  static const Color blue = Color(0xFF5B8DEF); // Listen
  static const Color green = Color(0xFF35A85A); // Speak
  static const Color coral = Color(0xFFEF5F5F);
  static const Color pink = Color(0xFFEE5FA7);

  // ---- Semantic ----
  static const Color secondary = amber;
  static const Color success = green;
  static const Color warning = Color(0xFFE8A020);
  static const Color danger = coral;

  // ---- Soft card fills. Never used behind body text. ----
  static const Color amberSoft = Color(0xFFFFF6DA);
  static const Color blueSoft = Color(0xFFE6F0FF);
  static const Color greenSoft = Color(0xFFE8F7EE);
  static const Color violetSoft = Color(0xFFF0E9FF);
  static const Color pinkSoft = Color(0xFFFDE8F2);

  // ---- Neutrals ----
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F7FC);
  static const Color border = Color(0xFFE4E6EF);
  static const Color textPrimary = Color(0xFF1F2233);
  static const Color textSecondary = Color(0xFF7A7F8C);
}

/// Consistent spacing so screens do not drift apart visually.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double cardRadius = 20;
  static const double buttonRadius = 16;
  static const double chipRadius = 999;

  /// Minimum tap target. Children have less precise motor control than
  /// adults, so this sits above the 48dp Material minimum.
  static const double minTapTarget = 56;
}

class AppTheme {
  const AppTheme._();

  /// Nunito throughout - rounded letterforms are friendlier and, for early
  /// readers, easier to tell apart than a geometric sans.
  static TextTheme _textTheme(TextTheme base) {
    return GoogleFonts.nunitoTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.nunito(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
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

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.danger,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme(base.textTheme),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.violetSoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.textSecondary,
          ),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearMinHeight: 8,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}
