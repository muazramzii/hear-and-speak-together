import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/report_filter.dart';
import '../models/school_analytics.dart';

/// Read-only: every figure behind these endpoints (Task 7) is already
/// computed server-side by the same analytics engine Parent/Teacher
/// Mode's own reports use. Nothing here recalculates anything.
class SchoolAnalyticsRepository {
  const SchoolAnalyticsRepository(this._dio);

  final Dio _dio;

  Future<SchoolOverview> fetchOverview() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/schools/analytics/overview/',
      );
      return SchoolOverview.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Already ordered by classroom name by the backend.
  Future<List<ClassroomAnalytics>> fetchClassroomAnalytics() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/schools/analytics/classrooms/',
      );
      return (response.data ?? const [])
          .map(
            (row) => ClassroomAnalytics.fromJson(
              (row as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Top 10 weakest sounds, worst first. School-wide by default; pass
  /// [classroomId] to scope to one classroom's students (Task 9's
  /// classroom report) - the backend already treats that id as
  /// tenant-checked, so there is nothing else to guard here.
  Future<List<PhonemeAnalytics>> fetchWeakestPhonemes({
    int? classroomId,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/schools/analytics/phonemes/',
        queryParameters: {if (classroomId != null) 'classroom_id': classroomId},
      );
      return (response.data ?? const [])
          .map(
            (row) => PhonemeAnalytics.fromJson(
              (row as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// [days] days, oldest first, zero-filled for inactive days. Defaults
  /// to 7; pass [classroomId] to scope to one classroom (Task 9's
  /// classroom report).
  Future<List<DailyTrend>> fetchTrends({int days = 7, int? classroomId}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/schools/analytics/trends/',
        queryParameters: {
          'days': days,
          if (classroomId != null) 'classroom_id': classroomId,
        },
      );
      return (response.data ?? const [])
          .map(
            (row) =>
                DailyTrend.fromJson((row as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final schoolAnalyticsRepositoryProvider = Provider<SchoolAnalyticsRepository>((
  ref,
) {
  return SchoolAnalyticsRepository(ref.watch(dioProvider));
});

final schoolOverviewProvider = FutureProvider.autoDispose<SchoolOverview>((
  ref,
) {
  return ref.watch(schoolAnalyticsRepositoryProvider).fetchOverview();
});

final classroomAnalyticsProvider =
    FutureProvider.autoDispose<List<ClassroomAnalytics>>((ref) {
      return ref
          .watch(schoolAnalyticsRepositoryProvider)
          .fetchClassroomAnalytics();
    });

final weakestPhonemesProvider =
    FutureProvider.autoDispose<List<PhonemeAnalytics>>((ref) {
      return ref
          .watch(schoolAnalyticsRepositoryProvider)
          .fetchWeakestPhonemes();
    });

final dailyTrendsProvider = FutureProvider.autoDispose<List<DailyTrend>>((
  ref,
) {
  return ref.watch(schoolAnalyticsRepositoryProvider).fetchTrends();
});

/// The Reports screen's selected date-range filter (Task 9, Feature 3) -
/// a single source of truth [reportTrendProvider] reacts to. Only the
/// trend endpoint accepts a day count, so this is the only section the
/// filter narrows; overview/classroom/phoneme figures keep their own
/// fixed windows.
final reportDateRangeProvider = StateProvider.autoDispose<ReportDateRange>(
  (ref) => ReportDateRange.last7Days,
);

final reportTrendProvider = FutureProvider.autoDispose<List<DailyTrend>>((
  ref,
) {
  final range = ref.watch(reportDateRangeProvider);
  return ref
      .watch(schoolAnalyticsRepositoryProvider)
      .fetchTrends(days: range.days);
});
