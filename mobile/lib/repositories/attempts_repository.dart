import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/attempt.dart';

enum AttemptResultFilter { any, pass, fail }

/// Everything the History tab's filter row can narrow by. Immutable and
/// value-comparable so it works as a Riverpod family key - two filters with
/// the same fields are the same cache entry.
class AttemptFilter {
  const AttemptFilter({
    required this.profileId,
    this.languageCode,
    this.categoryId,
    this.dateFrom,
    this.dateTo,
    this.result = AttemptResultFilter.any,
    this.page = 1,
  });

  final int profileId;
  final String? languageCode;
  final int? categoryId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final AttemptResultFilter result;
  final int page;

  AttemptFilter copyWith({
    String? languageCode,
    bool clearLanguageCode = false,
    int? categoryId,
    bool clearCategoryId = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    AttemptResultFilter? result,
    int? page,
  }) {
    return AttemptFilter(
      profileId: profileId,
      languageCode:
          clearLanguageCode ? null : (languageCode ?? this.languageCode),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      result: result ?? this.result,
      page: page ?? this.page,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AttemptFilter &&
      other.profileId == profileId &&
      other.languageCode == languageCode &&
      other.categoryId == categoryId &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.result == result &&
      other.page == page;

  @override
  int get hashCode => Object.hash(
    profileId,
    languageCode,
    categoryId,
    dateFrom,
    dateTo,
    result,
    page,
  );
}

class AttemptsRepository {
  const AttemptsRepository(this._dio);

  final Dio _dio;

  Future<AttemptPage> fetchAttempts(AttemptFilter filter) async {
    try {
      String isoDate(DateTime date) => date.toIso8601String().split('T').first;

      final response = await _dio.get<Map<String, dynamic>>(
        '/attempts/',
        queryParameters: {
          'profile': filter.profileId,
          'page': filter.page,
          if (filter.languageCode != null) 'language': filter.languageCode,
          if (filter.categoryId != null) 'category': filter.categoryId,
          if (filter.dateFrom != null) 'date_from': isoDate(filter.dateFrom!),
          if (filter.dateTo != null) 'date_to': isoDate(filter.dateTo!),
          if (filter.result != AttemptResultFilter.any)
            'result': filter.result.name,
        },
      );
      return AttemptPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Attempt> fetchAttempt(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/attempts/$id/');
      return Attempt.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final attemptsRepositoryProvider = Provider<AttemptsRepository>((ref) {
  return AttemptsRepository(ref.watch(dioProvider));
});

final attemptsProvider = FutureProvider.autoDispose
    .family<AttemptPage, AttemptFilter>((ref, filter) {
      return ref.watch(attemptsRepositoryProvider).fetchAttempts(filter);
    });

final attemptDetailProvider = FutureProvider.autoDispose.family<Attempt, int>((
  ref,
  id,
) {
  return ref.watch(attemptsRepositoryProvider).fetchAttempt(id);
});
