import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/core/audio/audio_recorder.dart';
import 'package:hear_speak_together/core/network/api_exception.dart';
import 'package:hear_speak_together/models/practice_result.dart';
import 'package:hear_speak_together/providers/practice_provider.dart';
import 'package:hear_speak_together/repositories/practice_repository.dart';

PracticeResult _result({int score = 82}) {
  return PracticeResult.fromJson({
    'attempt_id': 1,
    'reference': 'elephant',
    'recognized': 'elephant',
    'language': 'en',
    'locale': 'en-US',
    'heard_speech': true,
    'score': score,
    'similarity': score,
    'confidence': score,
    'completeness': 100,
    'errors': [],
    'feedback': 'Good job!',
    'points_awarded': 7,
    'profile': {'id': 1, 'points': 7, 'level': 1, 'streak_days': 1},
    'can_retry': true,
  });
}

/// Never touches a real microphone or the filesystem.
class _FakeRecorder implements AudioRecorderService {
  RecordingFailure? startFailure;
  RecordingFailure? stopFailure;
  bool discarded = false;
  bool cancelled = false;
  int startCount = 0;

  @override
  Future<void> start() async {
    startCount++;
    if (startFailure != null) throw RecordingException(startFailure!);
  }

  @override
  Future<String> stop() async {
    if (stopFailure != null) throw RecordingException(stopFailure!);
    return '/tmp/attempt.wav';
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> discard() async => discarded = true;

  @override
  Future<bool> hasPermission() async => startFailure == null;

  @override
  Future<void> dispose() async {}
}

class _FakeRepository implements PracticeRepository {
  ApiException? error;
  Completer<PracticeResult>? pending;
  int calls = 0;

  @override
  Future<PracticeResult> evaluate({
    required int wordId,
    required int profileId,
    required String audioPath,
  }) {
    calls++;
    if (error != null) return Future.error(error!);
    if (pending != null) return pending!.future;
    return Future.value(_result());
  }

  @override
  Future<QuizOutcome> submitQuizResult({
    required int profileId,
    required int lessonId,
    required String mode,
    required int correctCount,
    required int totalRounds,
  }) async {
    // Not exercised here; the quiz path has its own tests.
    return const QuizOutcome(
      pointsAwarded: 0,
      accuracyPercentage: 0,
      newAchievements: [],
    );
  }

  @override
  Future<void> flushPendingQuizResults() async {}
}

PracticeController _controller(_FakeRecorder recorder, _FakeRepository repo) {
  return PracticeController(recorder: recorder, repository: repo);
}

void main() {
  group('recording lifecycle', () {
    test('starts in the ready stage', () {
      final controller = _controller(_FakeRecorder(), _FakeRepository());

      expect(controller.state.stage, PracticeStage.ready);
      expect(controller.state.isBusy, isFalse);
    });

    test('moves to listening when recording starts', () async {
      final controller = _controller(_FakeRecorder(), _FakeRepository());

      await controller.startRecording();

      expect(controller.state.stage, PracticeStage.listening);
      expect(controller.state.isBusy, isTrue);
    });

    test(
      'a denied microphone is reported as such, not as a generic error',
      () async {
        final recorder =
            _FakeRecorder()..startFailure = RecordingFailure.permissionDenied;
        final controller = _controller(recorder, _FakeRepository());

        await controller.startRecording();

        expect(controller.state.stage, PracticeStage.error);
        expect(controller.state.permissionDenied, isTrue);
        // Carried as an enum so the widget can translate it; a sentence here
        // would be stuck in one language.
        expect(
          controller.state.recordingFailure,
          RecordingFailure.permissionDenied,
        );
      },
    );

    test('a too-short clip explains what to do differently', () async {
      final recorder = _FakeRecorder()..stopFailure = RecordingFailure.tooShort;
      final repo = _FakeRepository();
      final controller = _controller(recorder, repo);

      await controller.startRecording();
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);

      expect(controller.state.stage, PracticeStage.error);
      expect(controller.state.recordingFailure, RecordingFailure.tooShort);
      // Nothing was uploaded, so nothing was billed.
      expect(repo.calls, 0);
    });

    test('cancelling returns to ready', () async {
      final recorder = _FakeRecorder();
      final controller = _controller(recorder, _FakeRepository());

      await controller.startRecording();
      await controller.cancelRecording();

      expect(controller.state.stage, PracticeStage.ready);
      expect(recorder.cancelled, isTrue);
    });
  });

  group('evaluation', () {
    test('shows processing while the assessment is in flight', () async {
      final repo = _FakeRepository()..pending = Completer<PracticeResult>();
      final controller = _controller(_FakeRecorder(), repo);

      await controller.startRecording();
      final future = controller.stopAndEvaluate(wordId: 1, profileId: 1);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.stage, PracticeStage.processing);

      repo.pending!.complete(_result());
      await future;

      expect(controller.state.stage, PracticeStage.result);
    });

    test('a successful assessment carries the score through', () async {
      final controller = _controller(_FakeRecorder(), _FakeRepository());

      await controller.startRecording();
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);

      expect(controller.state.result?.score, 82);
      expect(controller.state.result?.pointsAwarded, 7);
    });

    test('the recording is discarded once uploaded', () async {
      final recorder = _FakeRecorder();
      final controller = _controller(recorder, _FakeRepository());

      await controller.startRecording();
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);

      expect(recorder.discarded, isTrue);
    });

    test('the recording is discarded even when the upload fails', () async {
      final recorder = _FakeRecorder();
      final repo =
          _FakeRepository()
            ..error = const ApiException(
              kind: ApiErrorKind.network,
              message: 'Could not reach the server.',
            );
      final controller = _controller(recorder, repo);

      await controller.startRecording();
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);

      expect(recorder.discarded, isTrue);
      expect(controller.state.stage, PracticeStage.error);
    });

    test('a backend outage surfaces its child-safe message', () async {
      final repo =
          _FakeRepository()
            ..error = const ApiException(
              kind: ApiErrorKind.server,
              statusCode: 503,
              message:
                  'Speech assessment is temporarily unavailable. Please try again.',
            );
      final controller = _controller(_FakeRecorder(), repo);

      await controller.startRecording();
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);

      expect(
        controller.state.errorMessage,
        contains('temporarily unavailable'),
      );
    });

    test('evaluating without recording first does nothing', () async {
      final repo = _FakeRepository();
      final controller = _controller(_FakeRecorder(), repo);

      await controller.stopAndEvaluate(wordId: 1, profileId: 1);

      // Guards against a stray rebuild triggering a paid API call.
      expect(repo.calls, 0);
      expect(controller.state.stage, PracticeStage.ready);
    });

    test('a second stop does not submit twice', () async {
      final repo = _FakeRepository();
      final controller = _controller(_FakeRecorder(), repo);

      await controller.startRecording();
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);

      expect(repo.calls, 1);
    });

    test('reset clears the previous result', () async {
      final controller = _controller(_FakeRecorder(), _FakeRepository());

      await controller.startRecording();
      await controller.stopAndEvaluate(wordId: 1, profileId: 1);
      controller.reset();

      expect(controller.state.stage, PracticeStage.ready);
      expect(controller.state.result, isNull);
    });
  });
}
