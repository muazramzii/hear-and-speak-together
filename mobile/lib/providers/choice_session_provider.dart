import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/content.dart';
import '../repositories/content_repository.dart';

/// The two multiple-choice modes. They share all their logic and differ only
/// in how the prompt is presented, so they share a controller rather than
/// duplicating round handling twice.
enum ChoiceMode {
  /// Hear the word, pick the picture. The word is never shown in text.
  listen,

  /// See and hear the word, pick the picture.
  quiz,
}

enum ChoiceStage { loading, question, answered, finished, error }

class ChoiceSessionState {
  const ChoiceSessionState({
    this.stage = ChoiceStage.loading,
    this.round,
    this.roundNumber = 1,
    this.totalRounds = 0,
    this.selectedOptionId,
    this.correctCount = 0,
    this.errorMessage,
  });

  final ChoiceStage stage;
  final QuizRound? round;
  final int roundNumber;
  final int totalRounds;

  /// Null until the child taps an option.
  final int? selectedOptionId;
  final int correctCount;
  final String? errorMessage;

  bool get hasAnswered => selectedOptionId != null;

  bool get lastAnswerCorrect =>
      round != null &&
      selectedOptionId != null &&
      round!.isCorrect(selectedOptionId!);

  double get progress => totalRounds == 0 ? 0 : roundNumber / totalRounds;

  bool get isLastRound => roundNumber >= totalRounds;

  ChoiceSessionState copyWith({
    ChoiceStage? stage,
    QuizRound? round,
    int? roundNumber,
    int? totalRounds,
    int? selectedOptionId,
    int? correctCount,
    String? errorMessage,
    bool clearSelection = false,
    bool clearError = false,
  }) {
    return ChoiceSessionState(
      stage: stage ?? this.stage,
      round: round ?? this.round,
      roundNumber: roundNumber ?? this.roundNumber,
      totalRounds: totalRounds ?? this.totalRounds,
      selectedOptionId: clearSelection
          ? null
          : (selectedOptionId ?? this.selectedOptionId),
      correctCount: correctCount ?? this.correctCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Runs a fixed-length session of multiple-choice rounds over one lesson.
class ChoiceSessionController extends StateNotifier<ChoiceSessionState> {
  ChoiceSessionController({
    required ContentRepository repository,
    required this.lessonId,
    this.requestedRounds = 10,
    Random? random,
  }) : _repository = repository,
       _random = random ?? Random(),
       super(const ChoiceSessionState()) {
    start();
  }

  final ContentRepository _repository;
  final int lessonId;
  final int requestedRounds;
  final Random _random;

  List<Word> _queue = const [];

  Future<void> start() async {
    state = const ChoiceSessionState();

    try {
      final lesson = await _repository.fetchLesson(lessonId);
      final words = [...lesson.words]..shuffle(_random);

      if (words.length < 2) {
        // A round needs at least one wrong option to be a real question.
        state = const ChoiceSessionState(
          stage: ChoiceStage.error,
          errorMessage: 'This lesson does not have enough words for a quiz yet.',
        );
        return;
      }

      _queue = words.take(requestedRounds).toList();
      state = ChoiceSessionState(
        stage: ChoiceStage.loading,
        totalRounds: _queue.length,
      );
      await _loadRound(0);
    } on ApiException catch (error) {
      state = ChoiceSessionState(
        stage: ChoiceStage.error,
        errorMessage: error.message,
      );
    }
  }

  Future<void> _loadRound(int index) async {
    state = state.copyWith(
      stage: ChoiceStage.loading,
      roundNumber: index + 1,
      clearSelection: true,
      clearError: true,
    );

    try {
      final round = await _repository.fetchQuizRound(_queue[index].id);
      state = state.copyWith(stage: ChoiceStage.question, round: round);
    } on ApiException catch (error) {
      state = state.copyWith(
        stage: ChoiceStage.error,
        errorMessage: error.message,
      );
    }
  }

  /// Records the child's choice. Ignored once answered, so a double tap
  /// cannot score the same round twice.
  void answer(int optionId) {
    if (state.stage != ChoiceStage.question || state.hasAnswered) return;

    final correct = state.round?.isCorrect(optionId) ?? false;
    state = state.copyWith(
      stage: ChoiceStage.answered,
      selectedOptionId: optionId,
      correctCount: state.correctCount + (correct ? 1 : 0),
    );
  }

  Future<void> next() async {
    if (state.stage != ChoiceStage.answered) return;

    final nextIndex = state.roundNumber; // roundNumber is 1-based
    if (nextIndex >= _queue.length) {
      state = state.copyWith(stage: ChoiceStage.finished);
      return;
    }
    await _loadRound(nextIndex);
  }

  /// Stars earned: one per correct answer, matching the "+10" style reward
  /// shown after a correct choice in the design.
  int get pointsEarned => state.correctCount * 10;
}

/// Parameters for a session, so the provider family can key on both.
class ChoiceSessionArgs {
  const ChoiceSessionArgs({required this.lessonId, required this.mode});

  final int lessonId;
  final ChoiceMode mode;

  @override
  bool operator ==(Object other) =>
      other is ChoiceSessionArgs &&
      other.lessonId == lessonId &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(lessonId, mode);
}

final choiceSessionProvider = StateNotifierProvider.autoDispose
    .family<ChoiceSessionController, ChoiceSessionState, ChoiceSessionArgs>((
      ref,
      args,
    ) {
      return ChoiceSessionController(
        repository: ref.watch(contentRepositoryProvider),
        lessonId: args.lessonId,
      );
    });
