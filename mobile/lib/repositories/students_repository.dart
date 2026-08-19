import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/progress.dart';

/// A learner as seen by a parent or teacher.
class SupervisedStudent {
  const SupervisedStudent({
    required this.id,
    required this.name,
    required this.avatar,
    required this.languageCode,
    required this.level,
    required this.points,
    required this.streakDays,
    required this.summary,
  });

  final int id;
  final String name;
  final String avatar;
  final String languageCode;
  final int level;
  final int points;
  final int streakDays;
  final ProgressSummary summary;

  factory SupervisedStudent.fromJson(Map<String, dynamic> json) {
    return SupervisedStudent(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'BOY_1',
      languageCode: json['language_code'] as String? ?? 'en',
      level: json['level'] as int? ?? 1,
      points: json['points'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      summary: ProgressSummary.fromJson(
        (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class StudentsRepository {
  const StudentsRepository(this._dio);

  final Dio _dio;

  Future<List<SupervisedStudent>> fetchStudents() async {
    try {
      final response = await _dio.get<List<dynamic>>('/students/');
      return (response.data ?? const [])
          .map(
            (item) => SupervisedStudent.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ProgressReport> fetchStudentProgress(int profileId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/students/$profileId/progress/',
      );
      return ProgressReport.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Links this supervisor to a learner using the code their family shared.
  Future<String> linkStudent(String shareCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/students/link/',
        data: {'share_code': shareCode.trim().toUpperCase()},
      );
      final profile = (response.data?['profile'] as Map?)
          ?.cast<String, dynamic>();
      return profile?['name'] as String? ?? '';
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> unlinkStudent(int profileId) async {
    try {
      await _dio.delete('/students/$profileId/link/');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) {
  return StudentsRepository(ref.watch(dioProvider));
});

final studentsProvider = FutureProvider.autoDispose<List<SupervisedStudent>>((
  ref,
) {
  return ref.watch(studentsRepositoryProvider).fetchStudents();
});

final studentProgressProvider = FutureProvider.autoDispose
    .family<ProgressReport, int>((ref, profileId) {
      return ref
          .watch(studentsRepositoryProvider)
          .fetchStudentProgress(profileId);
    });
