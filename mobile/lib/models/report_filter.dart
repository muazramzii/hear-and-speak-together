/// The date-range filter for School Admin reports (Phase 6 Task 9). This
/// only ever narrows which rows an *existing* endpoint returns - it has no
/// aggregation logic of its own, matching the brief's "only filter existing
/// API data" constraint. Every preset ultimately resolves to a `days` count,
/// because that is the only shape `GET /api/schools/analytics/trends/`
/// understands (`?days=`); "This month" and "Custom range" are expressed as
/// a day count ending today rather than a true calendar window.
library;

enum ReportRangePreset { last7Days, last30Days, thisMonth, custom }

/// The backend bounds `?days=` to 1-90 (see `_SchoolAnalyticsView._days_param`
/// in `apps/schools/views.py`) - this mirrors that limit so a custom range
/// picked further back is clamped client-side rather than failing the
/// request.
const int maxReportRangeDays = 90;

class ReportDateRange {
  const ReportDateRange({required this.preset, this.customStart});

  final ReportRangePreset preset;

  /// Only meaningful when [preset] is `custom` - the range always ends
  /// today, so a single start date is enough to describe it.
  final DateTime? customStart;

  static const last7Days = ReportDateRange(preset: ReportRangePreset.last7Days);
  static const last30Days = ReportDateRange(
    preset: ReportRangePreset.last30Days,
  );
  static const thisMonth = ReportDateRange(preset: ReportRangePreset.thisMonth);

  String get label => switch (preset) {
    ReportRangePreset.last7Days => 'Last 7 days',
    ReportRangePreset.last30Days => 'Last 30 days',
    ReportRangePreset.thisMonth => 'This month',
    ReportRangePreset.custom => 'Custom range',
  };

  /// The `?days=` value to send - today plus this many days back.
  int get days {
    final today = DateTime.now();
    return switch (preset) {
      ReportRangePreset.last7Days => 7,
      ReportRangePreset.last30Days => 30,
      ReportRangePreset.thisMonth => today.day.clamp(1, maxReportRangeDays),
      ReportRangePreset.custom => _customDays(today),
    };
  }

  int _customDays(DateTime today) {
    if (customStart == null) return 7;
    final start = DateTime(
      customStart!.year,
      customStart!.month,
      customStart!.day,
    );
    final end = DateTime(today.year, today.month, today.day);
    final span = end.difference(start).inDays + 1;
    return span.clamp(1, maxReportRangeDays);
  }

  ReportDateRange copyWith({
    ReportRangePreset? preset,
    DateTime? customStart,
  }) {
    return ReportDateRange(
      preset: preset ?? this.preset,
      customStart: preset == ReportRangePreset.custom
          ? (customStart ?? this.customStart)
          : null,
    );
  }
}
