import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../tokens.dart';

/// A circular progress ring that animates to its target value rather than
/// snapping to it - used for the pronunciation score reveal and any other
/// "here is a percentage" moment the redesign wants to feel earned rather
/// than instant.
///
/// [value] is 0.0-1.0. The centre content is supplied by the caller
/// ([child]) rather than hardcoded to a percentage label, so the same ring
/// can carry a score, a word count, or nothing at all.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 180,
    this.strokeWidth = 14,
    this.color = AppColors.primary,
    this.trackColor = AppColors.border,
    this.child,
    this.duration = AppMotion.celebration,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: AppMotion.standard,
      builder: (context, animatedValue, _) {
        return SizedBox(
          height: size,
          width: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: animatedValue,
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
            child: child == null ? null : Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final track =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = trackColor;

    final fill =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color;

    const start = -math.pi / 2;
    canvas.drawArc(rect, start, 2 * math.pi, false, track);
    canvas.drawArc(rect, start, 2 * math.pi * progress, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// A pill-shaped linear bar for streaks, XP, and lesson completion - rounded
/// ends everywhere (never a hard-cornered progress bar), and the same
/// animate-to-value behaviour as [ProgressRing].
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.value,
    this.height = 14,
    this.color = AppColors.amber,
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
      curve: AppMotion.standard,
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
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                Container(
                  height: height,
                  width: constraints.maxWidth * animatedValue,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
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
