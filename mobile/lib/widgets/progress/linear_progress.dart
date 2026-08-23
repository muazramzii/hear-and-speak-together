import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A pill-shaped linear bar - rounded ends everywhere (never a
/// hard-cornered progress bar), animating to its target value the same way
/// `CircularScore` does. The base every other linear indicator in the app
/// (`XpProgress`, `DailyGoalProgress`, the pronunciation-result metric
/// breakdown) is built from.
class LinearProgressBar extends StatelessWidget {
  const LinearProgressBar({
    super.key,
    required this.value,
    this.height = 14,
    this.color = AppColors.primary,
    this.trackColor = AppColors.border,
    this.duration = AppMotion.slow,
  });

  final double value;
  final double height;
  final Color color;
  final Color trackColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: AppMotion.easeOut,
      builder: (context, animatedValue, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: height,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                Container(
                  height: height,
                  width: constraints.maxWidth * animatedValue,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
