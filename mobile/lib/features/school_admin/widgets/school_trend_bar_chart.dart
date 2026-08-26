import 'package:flutter/material.dart';

import '../../../models/school_analytics.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/widgets/parent_widgets.dart';

/// The school-wide 7-day trend: one bar per day, oldest first, zero-height
/// (not omitted) for a day with no attempts at all - `dailyTrendsProvider`
/// already zero-fills every day server-side.
///
/// Not `LineChartCard`: that widget buckets its `TrendPoint`s onto a
/// Monday-Sunday calendar week (`daysFromMonday` relative to *this*
/// week's Monday), which is the right model for Parent Mode's own
/// "this week" chart but silently misplaces data for a genuinely rolling
/// "last 7 days" window whenever today isn't Sunday. Rather than force a
/// calendar-week shape onto rolling-window data (or edit a Parent Mode
/// widget this task has no reason to touch), this is a small, new,
/// same-style widget - no new chart package, just not this one specific
/// reuse.
class SchoolTrendBarChart extends StatelessWidget {
  const SchoolTrendBarChart({super.key, required this.trend});

  /// Oldest first, exactly as `GET /api/schools/analytics/trends/` returns
  /// it.
  final List<DailyTrend> trend;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final maxScore = trend
        .map((day) => day.averageScore)
        .fold(0, (a, b) => a > b ? a : b)
        .clamp(1, 100);

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-Day Trend', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in trend)
                  Expanded(
                    child: Semantics(
                      label:
                          '${_shortDate(day.date)}: ${day.attempts} attempts'
                          '${day.attempts > 0 ? ', average ${day.averageScore}%' : ''}',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              day.attempts > 0 ? '${day.averageScore}' : '—',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            RepaintBoundary(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: day.attempts > 0
                                      ? day.averageScore / maxScore
                                      : 0.04,
                                ),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (context, fraction, _) => Container(
                                  height: 80 * fraction.clamp(0.04, 1.0),
                                  decoration: BoxDecoration(
                                    color: day.attempts > 0
                                        ? palette.indigo
                                        : palette.surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _shortDate(day.date),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime date) => '${date.month}/${date.day}';
}
