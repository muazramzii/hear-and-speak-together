import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/practice_result.dart';

class PracticeRepository {
  const PracticeRepository(this._dio);

  final Dio _dio;

  /// Uploads one recording for assessment.
  ///
  /// Azure credentials never leave the server, so the audio goes to Django and
  /// Django talks to Azure. The app never holds a speech key.
  Future<PracticeResult> evaluate({
    required int wordId,
    required int profileId,
    required String audioPath,
  }) async {
    try {
      final form = FormData.fromMap({
        'word_id': wordId,
        'profile_id': profileId,
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'attempt.wav',
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/practice/evaluate/',
        data: form,
      );

      return PracticeResult.fromJson(response.data!);
    } on DioException catch (error) {
      // A 503 here is the backend telling us assessment is unavailable, and
      // its `detail` is already written to be safe for a child.
      final body = error.response?.data;
      if (error.response?.statusCode == 503 && body is Map) {
        throw ApiException(
          kind: ApiErrorKind.server,
          statusCode: 503,
          message:
              body['detail'] as String? ??
              'Speech assessment is temporarily unavailable. Please try again.',
        );
      }
      throw ApiException.fromDio(error);
    }
  }
}

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  return PracticeRepository(ref.watch(dioProvider));
});
