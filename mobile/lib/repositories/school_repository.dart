import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/school.dart';

class SchoolRepository {
  const SchoolRepository(this._dio);

  final Dio _dio;

  /// The signed-in admin's own school, or null if they haven't completed
  /// the "create a school" step yet. The list endpoint returns only the
  /// caller's own school (never another tenant's - see Task 4), so there
  /// is at most one row to take.
  Future<School?> fetchMySchool() async {
    try {
      final response = await _dio.get<List<dynamic>>('/schools/');
      final rows = response.data ?? const [];
      if (rows.isEmpty) return null;
      return School.fromJson((rows.first as Map).cast<String, dynamic>());
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<School> createSchool({required String name}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/schools/',
        data: {'name': name.trim()},
      );
      return School.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<School> updateSchoolName({
    required int id,
    required String name,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/schools/$id/',
        data: {'name': name.trim()},
      );
      return School.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Uploads a new logo. Multipart, not JSON - `logo` is an `ImageField`
  /// on the backend, not a URL string the client can just PATCH in.
  Future<School> uploadLogo({required int id, required File logoFile}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/schools/$id/',
        data: FormData.fromMap({
          'logo': await MultipartFile.fromFile(logoFile.path),
        }),
      );
      return School.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SchoolRepository(ref.watch(dioProvider));
});

final mySchoolProvider = FutureProvider.autoDispose<School?>((ref) {
  return ref.watch(schoolRepositoryProvider).fetchMySchool();
});
