import 'package:flutter/material.dart';

import '../../../models/progress.dart';
import '../design/parent_theme.dart';
import 'analytics_card.dart';

/// The weekly improvement chart: average pronunciation score, Monday
/// through Sunday. Days with no practice are gaps in the line, not zeros -
/// consuming `TrendPoint`s straight from `LearningAnalyticsService`, never
/// fabricated.
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.trend,
    required this.weekdayLabels,
  });

  final String title;
  final List<TrendPoint> trend;

  /// Mon..Sun, already localised by the caller.
  final List<String> weekdayLabels;

  /// One slot per weekday (Monday = index 0), null where nothing was
  /// practised that day.
  List<int?> get _weekSlots {
    final slots = List<int?>.filled(7, null);
    final now = DateTime.now();
    final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));

    for (final point in trend) {
      final daysFromMonday =
          point.date
              .difference(
                DateTime(
                  mondayThisWeek.year,
                  mondayThisWeek.month,
                  mondayThisWeek.day,
                ),
              )
              .inDays;
      if (daysFromMonday >= 0 && daysFromMonday < 7) {
        slots[daysFromMonday] = point.averageScore;
      }
    }
    return slots;
  }

  String get _accessibleSummary {
    if (trend.isEmpty) {
      return 'No practice recorded this week.';
    }
    final parts = [
      for (var i = 0; i < 7; i++)
        if (_weekSlots[i] != null) '${weekdayLabels[i]} ${_weekSlots[i]}%',
    ];
    return 'Weekly pronunciation trend: ${parts.join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Semantics(
            label: _accessibleSummary,
            child: ExcludeSemantics(
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        painter: _LineChartPainter(
                          slots: _weekSlots,
                          progress: progress,
                          lineColor: palette.indigo,
                          gridColor: palette.border,
                          dotFillColor: palette.surface,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in weekdayLabels)
                Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.slots,
    required this.progress,
    required this.lineColor,
    required this.gridColor,
    required this.dotFillColor,
  });

  final List<int?> slots;
  final double progress;
  final Color lineColor;
  final Color gridColor;
  final Color dotFillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;

    // Horizontal reference lines at 0/50/100%.
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - fraction);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final stepX = size.width / (slots.length - 1);
    Offset offsetFor(int index, int value) {
      final x = stepX * index;
      final y = size.height * (1 - (value / 100).clamp(0.0, 1.0));
      return Offset(x, y);
    }

    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    // Draw each contiguous run of practised days as its own path segment,
    // so a gap day breaks the line rather than being interpolated across.
    var runStart = -1;
    for (var i = 0; i <= slots.length; i++) {
      final hasValue = i < slots.length && slots[i] != null;
      if (hasValue && runStart == -1) {
        runStart = i;
      } else if (!hasValue && runStart != -1) {
        _paintRun(canvas, runStart, i - 1, offsetFor, linePaint, progress);
        runStart = -1;
      }
    }

    final dotPaint = Paint()..color = lineColor;
    final dotFill = Paint()..color = dotFillColor;
    for (var i = 0; i < slots.length; i++) {
      final value = slots[i];
      if (value == null) continue;
      final center = offsetFor(i, value);
      if ((center.dx / size.width) > progress) continue;
      canvas.drawCircle(center, 5, dotFill);
      canvas.drawCircle(center, 5, dotPaint..style = PaintingStyle.stroke);
    }
  }

  void _paintRun(
    Canvas canvas,
    int start,
    int end,
    Offset Function(int, int) offsetFor,
    Paint paint,
    double progress,
  ) {
    if (start == end) return;
    final path = Path();
    for (var i = start; i <= end; i++) {
      final point = offsetFor(i, slots[i]!);
      if (i == start) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final metrics = path.computeMetrics().toList();
    final clipped = Path();
    for (final metric in metrics) {
      clipped.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }
    canvas.drawPath(clipped, paint);
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.slots != slots;
}
