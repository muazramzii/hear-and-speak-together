import 'mascot.dart';

/// Maps app situations onto a [MascotState], in one place, so every screen
/// picks the mascot's mood the same way instead of each screen inventing
/// its own thresholds. `Mascot` itself stays a dumb, stateless-per-frame
/// renderer of whatever `MascotState` it is given (see mascot.dart); this
/// is the "system" that decides which state that should be.
class MascotEmotion {
  const MascotEmotion._();

  /// For a pronunciation score, 0-100. `null` means nothing was heard.
  /// Never returns a discouraged-looking state - the lowest band still gets
  /// `encourage`, matching the backend's own deterministic feedback bands,
  /// which are worded encouragingly at every level (see
  /// `docs/pronunciation-engine.md`). "Celebrate progress, don't grade" only
  /// holds if the mascot's face doesn't quietly grade it instead.
  static MascotState forScore(int? score) {
    if (score == null) return MascotState.thinking;
    if (score >= 90) return MascotState.celebrate;
    if (score >= 75) return MascotState.happy;
    return MascotState.encourage;
  }

  /// For a learner's current streak, in days.
  static MascotState forStreak(int streakDays) {
    if (streakDays <= 0) return MascotState.encourage;
    if (streakDays >= 7) return MascotState.celebrate;
    return MascotState.happy;
  }

  /// For a moment where the app is actively working (recognising speech,
  /// loading content) and has nothing to show yet.
  static const MascotState busy = MascotState.thinking;
}
