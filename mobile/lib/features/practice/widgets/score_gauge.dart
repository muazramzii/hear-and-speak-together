import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The circular score dial from the design.
///
/// The number is drawn in the centre as text, not just implied by the arc, so
/// the result is readable without interpreting the graphic. The band colour is
/// reinforced by the printed percentage rather than replacing it.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.score, this.size = 180});

  final int score;
  final double size;

  Color get _color {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return AppColors.green;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pronunciation score $score out of 100',
      child: SizedBox(
        height: size,
        width: size,
        child: CustomPaint(
          painter: _GaugePainter(
            progress: (score.clamp(0, 100)) / 100,
            color: _color,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score%',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: _color,
                    fontSize: size * 0.22,
                  ),
                ),
                Text(
                  'Score',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _strokeWidth / 2,
      _strokeWidth / 2,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border;

    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Start at twelve o'clock and sweep clockwise.
    const start = -math.pi / 2;
    canvas.drawArc(rect, start, 2 * math.pi, false, track);
    canvas.drawArc(rect, start, 2 * math.pi * progress, false, value);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
