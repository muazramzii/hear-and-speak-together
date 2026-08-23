import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'celebration_burst.dart';
import 'mascot.dart';

/// A full-screen celebration moment - confetti, the mascot in its
/// `celebrate` state, and a short message - meant to be layered over
/// *any* screen via a `Stack`, not tied to one particular route. "Global"
/// in that sense: any screen can drop this in without knowing about the
/// others, not that it is driven by app-wide state (this stage does not
/// introduce any new global/Riverpod state - see the module doc on
/// `CelebrationBurst` for why a plain boolean trigger is enough).
///
/// Renders nothing (`SizedBox.shrink`) while inactive, so it is safe to
/// keep permanently mounted in a screen's widget tree.
class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({super.key, required this.active, this.message});

  final bool active;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: CelebrationBurst(active: active)),
          if (active && message != null)
            Align(
              alignment: const Alignment(0, -0.55),
              child: AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: AppMotion.medium,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Mascot(state: MascotState.celebrate, size: 88),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        boxShadow: AppShadows.medium,
                      ),
                      child: Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: AppTypography.celebration,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
