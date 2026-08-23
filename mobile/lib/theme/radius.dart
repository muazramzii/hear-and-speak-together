/// Corner radius tokens. Rounded UI is part of the brand identity - nothing
/// in the app should have a hand-typed `BorderRadius.circular(...)` value.
class AppRadius {
  const AppRadius._();

  static const double small = 8;
  static const double medium = 16;
  static const double large = 20;
  static const double xl = 28;
  static const double full = 999;

  // Aliases already threaded through every screen written before this
  // refactor - same values as their `small`/`medium`/.../`full` equivalents
  // above, kept so relocating this file changes zero pixels anywhere in the
  // app. Prefer the named scale above in new code.
  static const double buttonRadius = medium;
  static const double cardRadius = large;
  static const double chipRadius = full;
}
