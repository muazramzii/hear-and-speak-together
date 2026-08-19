import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_recorder.dart';
import '../core/network/api_exception.dart';
import '../models/practice_result.dart';
import '../repositories/practice_repository.dart';

/// Where a practice attempt is in its lifecycle.
///
/// Every one of these is surfaced to the child as text as well as animation -
/// a speech app must not depend on the user hearing or inferring its state.
enum PracticeStage {
  /// Waiting for the child to tap the microphone.
  ready,

  /// Recording.
  listening,

  /// Uploaded, waiting on assessment.
  processing,

  /// Scored.
  result,

  /// Something went wrong; `errorMessage` explains it.
  error,
}

class PracticeState {
  const PracticeState({
    this.stage = PracticeStage.ready,
    this.result,
    this.errorMessage,
    this.recordingFailure,
    this.permissionDenied = false,
  });

  final PracticeStage stage;
  final PracticeResult? result;

  /// Set for failures whose text originates server-side (already localised by
  /// the backend into the practice language).
  final String? errorMessage;

  /// Set for device-side failures. Carried as an enum rather than a sentence
  /// because this layer has no `BuildContext`, so it cannot look up a
  /// translation - the widget maps it to the interface language.
  final RecordingFailure? recordingFailure;

  /// Tracked separately because it needs a different remedy - opening system
  /// settings, not retrying.
  final bool permissionDenied;

  bool get isBusy =>
      stage == PracticeStage.listening || stage == PracticeStage.processing;

  PracticeState copyWith({
    PracticeStage? stage,
    PracticeResult? result,
    String? errorMessage,
    RecordingFailure? recordingFailure,
    bool? permissionDenied,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return PracticeState(
      stage: stage ?? this.stage,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      recordingFailure: clearError
          ? null
          : (recordingFailure ?? this.recordingFailure),
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

class PracticeController extends StateNotifier<PracticeState> {
  PracticeController({
    required AudioRecorderService recorder,
    required PracticeRepository repository,
  }) : _recorder = recorder,
       _repository = repository,
       super(const PracticeState());

  final AudioRecorderService _recorder;
  final PracticeRepository _repository;

  Future<void> startRecording() async {
    state = const PracticeState(stage: PracticeStage.listening);

    try {
      await _recorder.start();
    } on RecordingException catch (error) {
      state = PracticeState(
        stage: PracticeStage.error,
        recordingFailure: error.failure,
        permissionDenied: error.failure == RecordingFailure.permissionDenied,
      );
    }
  }

  /// Stops recording and submits. Assessment costs money per call, so it
  /// happens exactly once per deliberate stop - never from a rebuild.
  Future<void> stopAndEvaluate({
    required int wordId,
    required int profileId,
  }) async {
    if (state.stage != PracticeStage.listening) return;

    String path;
    try {
      path = await _recorder.stop();
    } on RecordingException catch (error) {
      state = PracticeState(
        stage: PracticeStage.error,
        recordingFailure: error.failure,
        permissionDenied: error.failure == RecordingFailure.permissionDenied,
      );
      return;
    }

    state = const PracticeState(stage: PracticeStage.processing);

    try {
      final result = await _repository.evaluate(
        wordId: wordId,
        profileId: profileId,
        audioPath: path,
      );
      state = PracticeState(stage: PracticeStage.result, result: result);
    } on ApiException catch (error) {
      state = PracticeState(
        stage: PracticeStage.error,
        errorMessage: error.message,
      );
    } finally {
      // The recording has served its purpose either way; do not leave a
      // child's audio sitting in the cache directory.
      await _recorder.discard();
    }
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
    state = const PracticeState();
  }

  /// Back to Ready, keeping nothing from the previous attempt.
  void reset() => state = const PracticeState();
}

final practiceControllerProvider =
    StateNotifierProvider.autoDispose<PracticeController, PracticeState>((ref) {
      return PracticeController(
        recorder: ref.watch(audioRecorderProvider),
        repository: ref.watch(practiceRepositoryProvider),
      );
    });
