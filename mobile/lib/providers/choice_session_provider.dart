import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/content.dart';
import '../repositories/content_repository.dart';
import '../repositories/practice_repository.dart';
import '../repositories/profile_repository.dart';

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

/// Failures that originate in this layer, where no translation is available.
/// The widget turns these into the interface language.
enum ChoiceError { notEnoughWords }

class ChoiceSessionState {
  const ChoiceSessionState({
    this.stage = ChoiceStage.loading,
    this.round,
    this.roundNumber = 1,
    this.totalRounds = 0,
    this.selectedOptionId,
    this.correctCount = 0,
    this.errorMessage,
    this.errorCode,
    this.pointsAwarded,
    this.newAchievements = const [],
  });

  final ChoiceStage stage;
  final QuizRound? round;
  final int roundNumber;
  final int totalRounds;

  /// Null until the child taps an option.
  final int? selectedOptionId;
  final int correctCount;

  /// Server-side message, already worded.
  final String? errorMessage;

  /// Client-side failure, translated by the widget.
  final ChoiceError? errorCode;

  /// Confirmed by the server once the run is recorded. Null until then, or
  /// if the submission failed.
  final int? pointsAwarded;

  /// Badge names unlocked by this run.
  final List<String> newAchievements;

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
    ChoiceError? errorCode,
    int? pointsAwarded,
    List<String>? newAchievements,
    bool clearSelection = false,
    bool clearError = false,
  }) {
    return ChoiceSessionState(
      stage: stage ?? this.stage,
      round: round ?? this.round,
      roundNumber: roundNumber ?? this.roundNumber,
      totalRounds: totalRounds ?? this.totalRounds,
      selectedOptionId:
          clearSelection ? null : (selectedOptionId ?? this.selectedOptionId),
      correctCount: correctCount ?? this.correctCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      newAchievements: newAchievements ?? this.newAchievements,
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
    PracticeRepository? practiceRepository,
    this.mode = ChoiceMode.quiz,
    this.profileId,
  }) : _repository = repository,
       _practiceRepository = practiceRepository,
       _random = random ?? Random(),
       super(const ChoiceSessionState()) {
    start();
  }

  final ContentRepository _repository;

  /// Null in tests that only exercise round handling.
  final PracticeRepository? _practiceRepository;
  final int lessonId;
  final int requestedRounds;
  final ChoiceMode mode;

  /// Null when no learner is selected; the session then runs without scoring.
  final int? profileId;
  final Random _random;

  List<Word> _queue = const [];

  Future<void> start() async {
    state = const ChoiceSessionState();

    try {
      final lesson = await _repository.fetchLesson(lessonId);
      final words = [...lesson.words]..shuffle(_random);

      if (words.length < 2) {
        // A round needs at least one wrong option to be a real question.
        // Reported as a code, not a sentence: this layer has no
        // `BuildContext` and so cannot look up a translation.
        state = const ChoiceSessionState(
          stage: ChoiceStage.error,
          errorCode: ChoiceError.notEnoughWords,
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
      await _submitResult();
      return;
    }
    await _loadRound(nextIndex);
  }

  /// Persists the tally once, at the end of a run.
  ///
  /// A failure here is swallowed on purpose: the child has finished and is
  /// looking at their score, and an error banner over a trophy would punish
  /// them for a network problem. The points are lost, not the session.
  Future<void> _submitResult() async {
    final repository = _practiceRepository;
    final profile = profileId;
    if (repository == null || profile == null || _submitted) return;

    _submitted = true;

    try {
      final outcome = await repository.submitQuizResult(
        profileId: profile,
        lessonId: lessonId,
        mode: mode == ChoiceMode.listen ? 'LISTEN' : 'QUIZ',
        correctCount: state.correctCount,
        totalRounds: state.totalRounds,
      );
      state = state.copyWith(
        pointsAwarded: outcome.pointsAwarded,
        newAchievements: outcome.newAchievements,
      );
    } on ApiException {
      // Score already shown; nothing useful to tell the child here.
    }
  }

  bool _submitted = false;

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
        practiceRepository: ref.watch(practiceRepositoryProvider),
        lessonId: args.lessonId,
        mode: args.mode,
        profileId: ref.read(activeProfileProvider)?.id,
      );
    });
