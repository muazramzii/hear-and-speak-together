import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/school.dart';

/// The result of moving a student into a classroom - the destination and
/// (when they were already enrolled somewhere) the classroom they moved
/// out of, for on-screen confirmation. See the Task 6 architecture
/// correction: no transfer-history record exists yet, only this pointer
/// update and its immediate confirmation.
class ClassroomTransferResult {
  const ClassroomTransferResult({
    required this.previousClassroom,
    required this.classroom,
  });

  final Classroom? previousClassroom;
  final ClassroomDetail classroom;
}

class ClassroomRepository {
  const ClassroomRepository(this._dio);

  final Dio _dio;

  Future<List<Classroom>> fetchClassrooms({bool? active, String? search}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/classrooms/',
        queryParameters: {
          if (active != null) 'active': active,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      return (response.data ?? const [])
          .map(
            (item) => Classroom.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ClassroomDetail> fetchClassroomDetail(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/classrooms/$id/');
      return ClassroomDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Classroom> createClassroom({required String name}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/classrooms/',
        data: {'name': name.trim()},
      );
      return Classroom.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Classroom> renameClassroom({
    required int id,
    required String name,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/classrooms/$id/',
        data: {'name': name.trim()},
      );
      return Classroom.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Soft archive: flips `is_active` false. The classroom, its staff
  /// memberships and its students' history are never deleted.
  Future<void> archiveClassroom(int id) async {
    try {
      await _dio.delete('/classrooms/$id/');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `teacherPublicId` is the account's `public_id` (a UUID) - never the
  /// integer primary key, per the Task 6 architecture correction.
  Future<List<ClassroomMembership>> assignTeacher({
    required int classroomId,
    required String teacherPublicId,
    required String role,
  }) async {
    try {
      final response = await _dio.post<List<dynamic>>(
        '/classrooms/$classroomId/teachers/',
        data: {'teacher': teacherPublicId, 'role': role},
      );
      return (response.data ?? const [])
          .map(
            (row) => ClassroomMembership.fromJson(
              (row as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<ClassroomMembership>> removeTeacher({
    required int classroomId,
    required String teacherPublicId,
  }) async {
    try {
      final response = await _dio.delete<List<dynamic>>(
        '/classrooms/$classroomId/teachers/$teacherPublicId/',
      );
      return (response.data ?? const [])
          .map(
            (row) => ClassroomMembership.fromJson(
              (row as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ClassroomTransferResult> moveStudent({
    required int classroomId,
    required int profileId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/classrooms/$classroomId/students/',
        data: {'profile_id': profileId},
      );
      final data = response.data!;
      return ClassroomTransferResult(
        previousClassroom: data['previous_classroom'] == null
            ? null
            : Classroom.fromJson(
                data['previous_classroom'] as Map<String, dynamic>,
              ),
        classroom: ClassroomDetail.fromJson(
          data['classroom'] as Map<String, dynamic>,
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final classroomRepositoryProvider = Provider<ClassroomRepository>((ref) {
  return ClassroomRepository(ref.watch(dioProvider));
});

/// The active filter/search state driving the classroom list - a single
/// source of truth every widget on the Classrooms screen reads from
/// rather than each keeping its own copy.
class ClassroomListFilter {
  const ClassroomListFilter({this.activeOnly = true, this.search = ''});

  final bool activeOnly;
  final String search;

  ClassroomListFilter copyWith({bool? activeOnly, String? search}) {
    return ClassroomListFilter(
      activeOnly: activeOnly ?? this.activeOnly,
      search: search ?? this.search,
    );
  }
}

final classroomListFilterProvider =
    StateProvider.autoDispose<ClassroomListFilter>(
      (ref) => const ClassroomListFilter(),
    );

final classroomsProvider = FutureProvider.autoDispose<List<Classroom>>((ref) {
  final filter = ref.watch(classroomListFilterProvider);
  return ref
      .watch(classroomRepositoryProvider)
      .fetchClassrooms(
        active: filter.activeOnly ? true : null,
        search: filter.search,
      );
});

final classroomDetailProvider = FutureProvider.autoDispose
    .family<ClassroomDetail, int>((ref, classroomId) {
      return ref
          .watch(classroomRepositoryProvider)
          .fetchClassroomDetail(classroomId);
    });
