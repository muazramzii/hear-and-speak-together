import 'radius.dart';

/// The 8pt spacing system. Every gap, padding and margin in the app should
/// come from here - never a magic number typed into a widget.
class AppSpacing {
  const AppSpacing._();

  // The scale in full.
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;

  // T-shirt aliases, already threaded through every screen written before
  // this refactor - kept at their exact original values so relocating this
  // file changes zero pixels anywhere in the app. Prefer the `space*`
  // constants above in new code; these exist purely for continuity.
  static const double xs = space4;
  static const double sm = space8;
  static const double md = space16;
  static const double lg = space24;
  static const double xl = space32;

  /// Minimum tap target. Children have less precise motor control than
  /// adults, so this sits above the 48dp Material minimum.
  static const double minTapTarget = 56;

  // Radius aliases already threaded through every screen written before
  // this refactor as `AppSpacing.cardRadius` etc. Same values as their
  // `AppRadius` equivalents (see radius.dart) - kept here too so relocating
  // the radius scale into its own file did not require touching every call
  // site. Prefer `AppRadius` directly in new code.
  static const double cardRadius = AppRadius.large;
  static const double buttonRadius = AppRadius.medium;
  static const double chipRadius = AppRadius.full;
}
