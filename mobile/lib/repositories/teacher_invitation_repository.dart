import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/school.dart';

/// Code-based teacher invitations (Task 5) - there is no email delivery
/// anywhere in this system. Every action here just manages the code
/// itself; getting it to the teacher is the admin's own job (read it
/// aloud, copy it into a message, print it).
class TeacherInvitationRepository {
  const TeacherInvitationRepository(this._dio);

  final Dio _dio;

  /// Active, unexpired invitations only - see the backend's own "List
  /// active invitations" contract (Task 5). A teacher who has already
  /// accepted, or whose invitation was revoked, will not appear here.
  Future<List<TeacherInvitation>> fetchInvitations() async {
    try {
      final response = await _dio.get<List<dynamic>>('/schools/invitations/');
      return (response.data ?? const [])
          .map(
            (row) => TeacherInvitation.fromJson(
              (row as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TeacherInvitation> inviteTeacher({required String email}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/schools/invitations/',
        data: {'email': email.trim().toLowerCase()},
      );
      return TeacherInvitation.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Invalidates the current code and issues a new one on the same
  /// invitation - history (who invited this address, and when) survives.
  Future<TeacherInvitation> resetInvitation(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/schools/invitations/$id/reset/',
      );
      return TeacherInvitation.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Soft revoke: the code stops working, the row stays.
  Future<TeacherInvitation> deactivateInvitation(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/schools/invitations/$id/deactivate/',
      );
      return TeacherInvitation.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final teacherInvitationRepositoryProvider =
    Provider<TeacherInvitationRepository>((ref) {
      return TeacherInvitationRepository(ref.watch(dioProvider));
    });

final teacherInvitationsProvider =
    FutureProvider.autoDispose<List<TeacherInvitation>>((ref) {
      return ref
          .watch(teacherInvitationRepositoryProvider)
          .fetchInvitations();
    });
