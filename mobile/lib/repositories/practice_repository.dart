import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../core/offline/pending_quiz_queue.dart';
import '../models/practice_result.dart';

class PracticeRepository {
  const PracticeRepository(this._dio, this._pendingQueue);

  final Dio _dio;
  final PendingQuizQueue _pendingQueue;

  /// Uploads one recording for assessment.
  ///
  /// Recognition and scoring both happen server-side - the app only ever
  /// sends the recording and receives a result. It never talks to a speech
  /// provider directly and holds no speech-related credentials.
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
  ///
  /// A failure that never reached the server (no connection, a timeout) also
  /// queues the tally for a later retry - see `PendingQuizQueue` - but still
  /// throws exactly the `ApiException` it always has. The caller
  /// (`ChoiceSessionController`, unmodified) already treats that failure as
  /// "the score is lost, not the session" and moves on; queueing just means
  /// it usually isn't lost after all, without that caller needing to know.
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
      // No response at all reached the client - a connectivity problem, not
      // a rejection - so it is worth queuing. A 4xx/5xx the server actually
      // answered with is a real outcome and must not be replayed blindly.
      if (error.response == null) {
        await _pendingQueue.enqueue(
          PendingQuizSubmission(
            profileId: profileId,
            lessonId: lessonId,
            mode: mode,
            correctCount: correctCount,
            totalRounds: totalRounds,
          ),
        );
      }
      throw ApiException.fromDio(error);
    }
  }

  /// Replays every queued submission, in order, stopping (and keeping the
  /// rest queued) at the first one that still fails. Called whenever
  /// connectivity is restored - see `SyncCoordinator`.
  Future<void> flushPendingQuizResults() {
    return _pendingQueue.flush(
      (submission) => submitQuizResult(
        profileId: submission.profileId,
        lessonId: submission.lessonId,
        mode: submission.mode,
        correctCount: submission.correctCount,
        totalRounds: submission.totalRounds,
      ),
    );
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
  return PracticeRepository(
    ref.watch(dioProvider),
    ref.watch(pendingQuizQueueProvider),
  );
});
