import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// How the mascot feels about what's on screen right now. Each state maps
/// to a different tint, icon and idle-motion amplitude, so the same widget
/// carries the "celebrate progress instead of grading" tone through every
/// screen that uses it without needing separate custom art per feeling.
enum MascotState { idle, happy, celebrate, thinking, encourage }

/// The app's mascot, as a **state-driven placeholder, not artwork**. This
/// project has no illustration pipeline and hand-drawn character art is out
/// of scope for what can be produced and verified in Flutter alone - so
/// this widget is built around `MascotState` instead: a tinted circle and
/// one icon from the app's one consistent icon family (Material Symbols,
/// the same family used everywhere else in the app - never emoji here,
/// since a mascot face is UI chrome, not learning content).
///
/// **To swap in real artwork later**: replace the body of `_iconFor` and
/// `_tintFor` below with an `Image.asset`/Lottie/Rive lookup keyed on
/// `state` - nothing else in this widget, or any of its callers, needs to
/// change, since every caller only ever passes a `MascotState` and reads no
/// icon/colour details of its own.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.state = MascotState.idle, this.size = 96});

  final MascotState state;
  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _bobAmount => switch (widget.state) {
    MascotState.idle => 4,
    MascotState.encourage => 6,
    MascotState.happy => 10,
    MascotState.celebrate => 14,
    MascotState.thinking => 3,
  };

  // ---- Placeholder-only from here down; see the class doc for the swap
  // point once real artwork exists. ----

  IconData _iconFor(MascotState state) => switch (state) {
    MascotState.idle => Icons.sentiment_satisfied_alt_rounded,
    MascotState.happy => Icons.sentiment_very_satisfied_rounded,
    MascotState.celebrate => Icons.celebration_rounded,
    MascotState.thinking => Icons.psychology_rounded,
    MascotState.encourage => Icons.favorite_rounded,
  };

  Color _tintFor(MascotState state) => switch (state) {
    MascotState.idle => AppColors.violetSoft,
    MascotState.happy => AppColors.greenSoft,
    MascotState.celebrate => AppColors.amberSoft,
    MascotState.thinking => AppColors.blueSoft,
    MascotState.encourage => AppColors.pinkSoft,
  };

  Color _iconColorFor(MascotState state) => switch (state) {
    MascotState.idle => AppColors.primary,
    MascotState.happy => AppColors.successStrong,
    MascotState.celebrate => AppColors.textOnAccent,
    MascotState.thinking => AppColors.secondaryStrong,
    MascotState.encourage => AppColors.pinkStrong,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mascot: ${widget.state.name}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bob = (_controller.value - 0.5) * 2 * _bobAmount;
          return Transform.translate(offset: Offset(0, bob), child: child);
        },
        child: Container(
          height: widget.size,
          width: widget.size,
          decoration: BoxDecoration(
            color: _tintFor(widget.state),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _iconFor(widget.state),
            color: _iconColorFor(widget.state),
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// A speech bubble for the mascot to talk through - always dark text on a
/// light tint, regardless of which tint is passed in, so a bubble can never
/// end up low-contrast by accident.
class MascotSpeechBubble extends StatelessWidget {
  const MascotSpeechBubble({
    super.key,
    required this.text,
    this.color = AppColors.violetSoft,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Text(
        text,
        style: AppTypography.mascotSpeech.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
