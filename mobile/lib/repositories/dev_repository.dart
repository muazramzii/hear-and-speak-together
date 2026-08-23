import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/pronunciation_debug_result.dart';

/// The Phase 2 developer-only pronunciation sandbox.
///
/// Every method here calls `/api/dev/...`, which the backend gates on
/// `is_staff` - a signed-in learner account gets a 403, same as anyone else
/// who is not a developer. This repository is never referenced from any
/// child-facing screen.
class DevRepository {
  const DevRepository(this._dio);

  final Dio _dio;

  Future<PronunciationDebugResult> debugEvaluate({
    required String reference,
    required String language,
    required String audioPath,
  }) async {
    try {
      final form = FormData.fromMap({
        'reference': reference,
        'language': language,
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'attempt.wav',
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/dev/pronunciation-debug/',
        data: form,
      );

      return PronunciationDebugResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// The Phase 2 validation dataset - correct and intentionally
  /// mispronounced words per language - so the sandbox can offer it as a
  /// picker instead of retyping the same words every run.
  Future<Map<String, dynamic>> fetchTestWords() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/dev/pronunciation-test-words/',
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final devRepositoryProvider = Provider<DevRepository>((ref) {
  return DevRepository(ref.watch(dioProvider));
});
