import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/learner_profile.dart';

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<List<LearnerProfile>> fetchProfiles() async {
    try {
      final response = await _dio.get<List<dynamic>>('/profiles/');
      return (response.data ?? const [])
          .map(
            (item) =>
                LearnerProfile.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<LearnerProfile> createProfile({
    required String name,
    required ProfileAvatar avatar,
    required String languageCode,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/profiles/',
        data: {
          'name': name.trim(),
          'avatar': avatar.value,
          'practice_language': languageCode,
        },
      );
      return LearnerProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<LearnerProfile> updateProfile({
    required int id,
    String? name,
    ProfileAvatar? avatar,
    String? languageCode,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/profiles/$id/',
        data: {
          if (name != null) 'name': name.trim(),
          if (avatar != null) 'avatar': avatar.value,
          if (languageCode != null) 'practice_language': languageCode,
        },
      );
      return LearnerProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deleteProfile(int id) async {
    try {
      await _dio.delete('/profiles/$id/');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

/// Every learner under the signed-in account.
final profilesProvider = FutureProvider<List<LearnerProfile>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchProfiles();
});

/// The child currently using the app.
///
/// Held in memory only. It is deliberately not persisted: a shared family
/// tablet should return to the picker on relaunch rather than silently
/// crediting one sibling's practice to another.
final activeProfileProvider = StateProvider<LearnerProfile?>((ref) => null);
