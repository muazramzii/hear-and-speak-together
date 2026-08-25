import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A circular progress ring that animates to its target value rather than
/// snapping to it - used for the pronunciation score reveal, a lesson's
/// completion ring, or anywhere else a "here is a percentage" moment
/// should feel earned rather than instant.
///
/// [value] is 0.0-1.0. The centre content is supplied by the caller
/// ([child]) rather than hardcoded to a percentage label, so the same ring
/// can carry a score, a badge icon, or nothing at all.
class CircularScore extends StatelessWidget {
  const CircularScore({
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
      curve: AppMotion.easeOut,
      builder: (context, animatedValue, _) {
        return SizedBox(
          height: size,
          width: size,
          // Isolates the ring's every-frame repaint to its own layer, so
          // animating it never forces a parent (a card, a list row) to
          // repaint too - see docs/performance.md.
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RingPainter(
                progress: animatedValue,
                color: color,
                trackColor: trackColor,
                strokeWidth: strokeWidth,
              ),
              child: child == null ? null : Center(child: child),
            ),
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
