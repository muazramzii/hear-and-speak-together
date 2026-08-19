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

  /// Records a finished Listen or Quiz session so its points persist.
  ///
  /// Rounds are scored on the device - the correct answer is known there - so
  /// only the tally is sent. The server bounds what it will accept.
  Future<QuizOutcome> submitQuizResult({
    required int profileId,
    required int lessonId,
    required String mode,
    required int correctCount,
    required int totalRounds,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/practice/quiz-result/',
        data: {
          'profile_id': profileId,
          'lesson_id': lessonId,
          'mode': mode,
          'correct_count': correctCount,
          'total_rounds': totalRounds,
        },
      );
      return QuizOutcome.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// What the backend recorded for a finished quiz or listen session.
class QuizOutcome {
  const QuizOutcome({
    required this.pointsAwarded,
    required this.accuracyPercentage,
    required this.newAchievements,
  });

  final int pointsAwarded;
  final int accuracyPercentage;

  /// Badges unlocked by this session, so the app can celebrate immediately.
  final List<String> newAchievements;

  factory QuizOutcome.fromJson(Map<String, dynamic> json) {
    return QuizOutcome(
      pointsAwarded: json['points_awarded'] as int? ?? 0,
      accuracyPercentage: json['accuracy_percentage'] as int? ?? 0,
      newAchievements:
          ((json['new_achievements'] as List?) ?? const [])
              .map((item) => (item as Map)['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList(),
    );
  }
}

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  return PracticeRepository(ref.watch(dioProvider));
});
