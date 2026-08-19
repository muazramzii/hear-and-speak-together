import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/progress.dart';

class ProgressRepository {
  const ProgressRepository(this._dio);

  final Dio _dio;

  Future<ProgressReport> fetchProgress({int? profileId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/progress/',
        queryParameters: {if (profileId != null) 'profile': profileId},
      );
      return ProgressReport.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<AchievementBadge>> fetchAchievements({int? profileId}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/achievements/',
        queryParameters: {if (profileId != null) 'profile': profileId},
      );
      return (response.data ?? const [])
          .map(
            (item) =>
                AchievementBadge.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(dioProvider));
});

/// Keyed on the profile so switching child re-fetches rather than showing the
/// previous sibling's figures.
final progressReportProvider = FutureProvider.autoDispose
    .family<ProgressReport, int>((ref, profileId) {
      return ref
          .watch(progressRepositoryProvider)
          .fetchProgress(profileId: profileId);
    });

final achievementsProvider = FutureProvider.autoDispose
    .family<List<AchievementBadge>, int>((ref, profileId) {
      return ref
          .watch(progressRepositoryProvider)
          .fetchAchievements(profileId: profileId);
    });
