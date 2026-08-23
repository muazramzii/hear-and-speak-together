import 'package:flutter/material.dart';

/// Durations and curves, so every animation in the app moves at one of a
/// small number of consistent speeds rather than a new magic number per
/// widget. "Do not over-animate" - these exist to make restraint the easy
/// default, not to justify animating everything.
class AppMotion {
  const AppMotion._();

  /// A state change so small it should barely register as an animation -
  /// a button's press-down scale, a chip's selection fill.
  static const Duration instant = Duration(milliseconds: 100);

  /// The default for most UI transitions: a card appearing, a button press,
  /// a page element fading in.
  static const Duration fast = Duration(milliseconds: 180);

  /// Bigger movements - a card expanding, a lesson unlocking, a page
  /// transition.
  static const Duration medium = Duration(milliseconds: 280);

  /// Deliberately slow, attention-holding motion - the mascot's idle
  /// animation, a progress ring filling.
  static const Duration slow = Duration(milliseconds: 450);

  /// The pronunciation result reveal and celebration burst. Slow enough for
  /// a child to actually watch it happen, not just notice it happened.
  static const Duration celebration = Duration(milliseconds: 900);

  /// Default motion for anything that isn't explicitly playful - fills,
  /// fades, size changes, page transitions.
  static const Curve easeOut = Curves.easeOutCubic;

  /// For a transition that needs to feel equally smooth arriving and
  /// leaving - a value that animates back and forth (e.g. a toggle).
  static const Curve easeInOut = Curves.easeInOut;

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
