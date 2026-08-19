import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/core/network/api_exception.dart';
import 'package:hear_speak_together/models/content.dart';
import 'package:hear_speak_together/providers/choice_session_provider.dart';
import 'package:hear_speak_together/repositories/content_repository.dart';

Word _word(int id, String text) => Word(
  id: id,
  text: text,
  meaning: '',
  exampleSentence: '',
  imageUrl: '',
  audioUrl: '',
);

class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository({this.wordCount = 4});

  final int wordCount;
  ApiException? lessonError;
  ApiException? roundError;
  int roundCalls = 0;

  @override
  Future<Lesson> fetchLesson(int id) async {
    if (lessonError != null) throw lessonError!;
    return Lesson(
      id: id,
      title: 'Animals',
      description: '',
      difficulty: 'BEGINNER',
      imageUrl: '',
      wordCount: wordCount,
      words: [
        for (var i = 0; i < wordCount; i++) _word(i + 1, 'word$i'),
      ],
    );
  }

  @override
  Future<QuizRound> fetchQuizRound(int wordId) async {
    roundCalls++;
    if (roundError != null) throw roundError!;
    return QuizRound(
      word: _word(wordId, 'word$wordId'),
      options: [
        _word(wordId, 'word$wordId'),
        _word(900, 'wrong1'),
        _word(901, 'wrong2'),
        _word(902, 'wrong3'),
      ],
      correctOptionId: wordId,
    );
  }

  @override
  Future<List<Category>> fetchCategories({String? languageCode}) async => [];

  @override
  Future<List<LanguageInfo>> fetchLanguages() async => [];

  @override
  Future<List<Lesson>> fetchLessons({
    String? languageCode,
    int? categoryId,
  }) async => [];
}

ChoiceSessionController _controller(
  _FakeContentRepository repo, {
  int rounds = 10,
}) {
  return ChoiceSessionController(
    repository: repo,
    lessonId: 1,
    requestedRounds: rounds,
    random: Random(42), // deterministic shuffle
  );
}

void main() {
  group('session setup', () {
    test('loads the first round and sizes the session to the lesson', () async {
      final controller = _controller(_FakeContentRepository(wordCount: 4));
      await pumpEventQueue();

      expect(controller.state.stage, ChoiceStage.question);
      expect(controller.state.totalRounds, 4);
      expect(controller.state.roundNumber, 1);
      expect(controller.state.round, isNotNull);
    });

    test('caps the session at the requested number of rounds', () async {
      final controller = _controller(
        _FakeContentRepository(wordCount: 20),
        rounds: 5,
      );
      await pumpEventQueue();

      expect(controller.state.totalRounds, 5);
    });

    test('a lesson too small for a real question reports an error', () async {
      // One word means no wrong option, so there is no question to ask.
      final controller = _controller(_FakeContentRepository(wordCount: 1));
      await pumpEventQueue();

      expect(controller.state.stage, ChoiceStage.error);
      expect(controller.state.errorCode, ChoiceError.notEnoughWords);
    });

    test('a failed lesson fetch surfaces the message', () async {
      final repo = _FakeContentRepository()
        ..lessonError = const ApiException(
          kind: ApiErrorKind.network,
          message: 'Could not reach the server.',
        );
      final controller = _controller(repo);
      await pumpEventQueue();

      expect(controller.state.stage, ChoiceStage.error);
      expect(controller.state.errorMessage, 'Could not reach the server.');
    });
  });

  group('answering', () {
    test('a correct answer is scored', () async {
      final controller = _controller(_FakeContentRepository());
      await pumpEventQueue();

      controller.answer(controller.state.round!.correctOptionId);

      expect(controller.state.stage, ChoiceStage.answered);
      expect(controller.state.lastAnswerCorrect, isTrue);
      expect(controller.state.correctCount, 1);
    });

    test('a wrong answer is recorded without scoring', () async {
      final controller = _controller(_FakeContentRepository());
      await pumpEventQueue();

      controller.answer(900);

      expect(controller.state.lastAnswerCorrect, isFalse);
      expect(controller.state.correctCount, 0);
      expect(controller.state.hasAnswered, isTrue);
    });

    test('a double tap cannot score the same round twice', () async {
      final controller = _controller(_FakeContentRepository());
      await pumpEventQueue();
      final correct = controller.state.round!.correctOptionId;

      controller.answer(correct);
      controller.answer(correct);

      expect(controller.state.correctCount, 1);
    });

    test('answering before the round loads does nothing', () {
      final controller = _controller(_FakeContentRepository());

      controller.answer(1);

      expect(controller.state.correctCount, 0);
      expect(controller.state.hasAnswered, isFalse);
    });
  });

  group('progression', () {
    test('next advances and clears the previous selection', () async {
      final controller = _controller(_FakeContentRepository(wordCount: 4));
      await pumpEventQueue();

      controller.answer(controller.state.round!.correctOptionId);
      await controller.next();

      expect(controller.state.roundNumber, 2);
      expect(controller.state.hasAnswered, isFalse);
      expect(controller.state.stage, ChoiceStage.question);
    });

    test('next does nothing until the round is answered', () async {
      final repo = _FakeContentRepository();
      final controller = _controller(repo);
      await pumpEventQueue();
      final callsBefore = repo.roundCalls;

      await controller.next();

      expect(repo.roundCalls, callsBefore);
      expect(controller.state.roundNumber, 1);
    });

    test('the session finishes after the last round', () async {
      final controller = _controller(
        _FakeContentRepository(wordCount: 2),
        rounds: 2,
      );
      await pumpEventQueue();

      controller.answer(controller.state.round!.correctOptionId);
      await controller.next();
      controller.answer(controller.state.round!.correctOptionId);
      await controller.next();

      expect(controller.state.stage, ChoiceStage.finished);
      expect(controller.state.correctCount, 2);
      expect(controller.pointsEarned, 20);
    });

    test('progress tracks position through the session', () async {
      final controller = _controller(
        _FakeContentRepository(wordCount: 4),
        rounds: 4,
      );
      await pumpEventQueue();

      expect(controller.state.progress, closeTo(0.25, 0.001));
      expect(controller.state.isLastRound, isFalse);

      controller.answer(1);
      await controller.next();

      expect(controller.state.progress, closeTo(0.5, 0.001));
    });

    test('isLastRound is true on the final question', () async {
      final controller = _controller(
        _FakeContentRepository(wordCount: 2),
        rounds: 2,
      );
      await pumpEventQueue();
      controller.answer(1);
      await controller.next();

      expect(controller.state.isLastRound, isTrue);
    });
  });
}
