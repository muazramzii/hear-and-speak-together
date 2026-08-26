import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
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

  /// Top 10 weakest sounds school-wide, worst first.
  Future<List<PhonemeAnalytics>> fetchWeakestPhonemes() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/schools/analytics/phonemes/',
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

  /// The last 7 days, oldest first, zero-filled for inactive days.
  Future<List<DailyTrend>> fetchTrends() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/schools/analytics/trends/',
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
