import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/core/offline/pending_quiz_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

PendingQuizSubmission _submission({int lessonId = 1}) {
  return PendingQuizSubmission(
    profileId: 7,
    lessonId: lessonId,
    mode: 'QUIZ',
    correctCount: 4,
    totalRounds: 5,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PendingQuizQueue', () {
    test('starts empty', () async {
      final queue = PendingQuizQueue(SharedPreferences.getInstance());

      expect(await queue.read(), isEmpty);
    });

    test('enqueue then read round-trips every field', () async {
      final queue = PendingQuizQueue(SharedPreferences.getInstance());

      await queue.enqueue(_submission());
      final pending = await queue.read();

      expect(pending, hasLength(1));
      expect(pending.single.profileId, 7);
      expect(pending.single.lessonId, 1);
      expect(pending.single.mode, 'QUIZ');
      expect(pending.single.correctCount, 4);
      expect(pending.single.totalRounds, 5);
    });

    test('flush submits every entry and empties the queue on success', () async {
      final queue = PendingQuizQueue(SharedPreferences.getInstance());
      await queue.enqueue(_submission(lessonId: 1));
      await queue.enqueue(_submission(lessonId: 2));

      final submitted = <int>[];
      await queue.flush((submission) async {
        submitted.add(submission.lessonId);
      });

      expect(submitted, [1, 2]);
      expect(await queue.read(), isEmpty);
    });

    test('a submission that fails stays queued, and later ones are not attempted', () async {
      final queue = PendingQuizQueue(SharedPreferences.getInstance());
      await queue.enqueue(_submission(lessonId: 1));
      await queue.enqueue(_submission(lessonId: 2));
      await queue.enqueue(_submission(lessonId: 3));

      final attempted = <int>[];
      await queue.flush((submission) async {
        attempted.add(submission.lessonId);
        if (submission.lessonId == 2) {
          throw Exception('still offline');
        }
      });

      expect(attempted, [1, 2]);
      final remaining = await queue.read();
      expect(remaining.map((s) => s.lessonId), [2, 3]);
    });

    test('flushing an empty queue calls the submitter zero times', () async {
      final queue = PendingQuizQueue(SharedPreferences.getInstance());
      var calls = 0;

      await queue.flush((submission) async => calls++);

      expect(calls, 0);
    });
  });
}
