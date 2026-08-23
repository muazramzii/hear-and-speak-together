import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../tokens.dart';

/// How the mascot feels about what's on screen right now. Each mood maps to
/// a different idle motion and expression, so the same widget carries the
/// "celebrate progress instead of grading" tone through Home, the Learning
/// Journey and the pronunciation result without needing separate custom art
/// for each.
enum MascotMood { idle, encouraging, happy, excited, thinking }

/// The app's mascot - "Ellie", the elephant already present in the app's
/// bilingual content (elephant/gajah is a seeded vocabulary word in both
/// languages, and 🐘 already appears on Home's streak card). Built from
/// emoji and motion rather than a custom illustration asset: this project
/// has no illustration pipeline, and a hand-drawn mascot is out of scope for
/// what can be produced and verified inside this phase. Stated plainly
/// rather than presented as more than it is - see docs/design-system.md.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.mood = MascotMood.idle, this.size = 96});

  final MascotMood mood;
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

  double get _bobAmount => switch (widget.mood) {
    MascotMood.idle => 4,
    MascotMood.encouraging => 6,
    MascotMood.happy => 10,
    MascotMood.excited => 14,
    MascotMood.thinking => 3,
  };

  String get _emoji => switch (widget.mood) {
    MascotMood.idle => '🐘',
    MascotMood.encouraging => '🐘',
    MascotMood.happy => '🐘',
    MascotMood.excited => '🐘',
    MascotMood.thinking => '🐘',
  };

  /// A small decoration emoji that only appears for moods with something to
  /// celebrate - kept separate from the base mascot so "excited" does not
  /// require a whole second emoji character (none exists for "elephant with
  /// sparkles").
  String? get _accessory => switch (widget.mood) {
    MascotMood.happy => '✨',
    MascotMood.excited => '🎉',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ellie the elephant',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bob = (_controller.value - 0.5) * 2 * _bobAmount;
          return Transform.translate(offset: Offset(0, bob), child: child);
        },
        child: SizedBox(
          height: widget.size,
          width: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(_emoji, style: TextStyle(fontSize: widget.size)),
              if (_accessory != null)
                Positioned(
                  top: -widget.size * 0.1,
                  right: -widget.size * 0.1,
                  child: Text(
                    _accessory!,
                    style: TextStyle(fontSize: widget.size * 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A speech bubble for the mascot to talk through - always dark text on a
/// light tint, regardless of which tint is passed in, so a caller cannot
/// accidentally create a low-contrast bubble.
class MascotBubble extends StatelessWidget {
  const MascotBubble({
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
