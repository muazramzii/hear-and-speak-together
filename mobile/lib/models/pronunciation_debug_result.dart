/// Every raw and normalised value produced by one sandbox run.
///
/// Deliberately a flat mirror of the backend's debug response rather than a
/// UI-shaped model - this screen exists to show a developer exactly what the
/// pipeline produced, so nothing here is summarised or hidden the way
/// [PracticeResult] deliberately is for a child.
class PronunciationDebugWhisper {
  const PronunciationDebugWhisper({
    required this.text,
    required this.confidence,
    required this.language,
  });

  final String text;

  /// 0-1, the raw scale a model confidence is normally expressed in.
  final double? confidence;
  final String language;

  factory PronunciationDebugWhisper.fromJson(Map<String, dynamic> json) {
    return PronunciationDebugWhisper(
      text: json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
      language: json['language'] as String? ?? '',
    );
  }
}

class PronunciationDebugPhoneme {
  const PronunciationDebugPhoneme({
    required this.expected,
    required this.recognized,
    required this.distance,
  });

  /// Space-separated phoneme units, e.g. "b o l a".
  final String expected;
  final String recognized;

  /// Count of non-matching phoneme-alignment operations - a plain edit
  /// distance, distinct from the weighted feature distance `similarity`
  /// is derived from.
  final int distance;

  factory PronunciationDebugPhoneme.fromJson(Map<String, dynamic> json) {
    return PronunciationDebugPhoneme(
      expected: json['expected'] as String? ?? '',
      recognized: json['recognized'] as String? ?? '',
      distance: json['distance'] as int? ?? 0,
    );
  }
}

class PronunciationDebugError {
  const PronunciationDebugError({
    required this.type,
    required this.expected,
    required this.detected,
  });

  final String type;
  final String? expected;
  final String? detected;

  factory PronunciationDebugError.fromJson(Map<String, dynamic> json) {
    return PronunciationDebugError(
      type: json['type'] as String? ?? '',
      expected: json['expected'] as String?,
      detected: json['detected'] as String?,
    );
  }
}

class PronunciationDebugAssessment {
  const PronunciationDebugAssessment({
    required this.similarity,
    required this.confidence,
    required this.completeness,
    required this.finalScore,
    required this.errorType,
    required this.errors,
  });

  final double similarity;
  final double confidence;
  final double completeness;
  final int finalScore;
  final String? errorType;
  final List<PronunciationDebugError> errors;

  factory PronunciationDebugAssessment.fromJson(Map<String, dynamic> json) {
    return PronunciationDebugAssessment(
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      completeness: (json['completeness'] as num?)?.toDouble() ?? 0,
      finalScore: (json['final_score'] as num?)?.round() ?? 0,
      errorType: json['error_type'] as String?,
      errors:
          (json['errors'] as List?)
              ?.map(
                (e) => PronunciationDebugError.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
    );
  }
}

class PronunciationDebugPerformance {
  const PronunciationDebugPerformance({
    required this.recordingDurationSeconds,
    required this.whisperInferenceMs,
    required this.phonemeAnalysisMs,
    required this.totalProcessingMs,
  });

  final double? recordingDurationSeconds;
  final double whisperInferenceMs;
  final double phonemeAnalysisMs;
  final double totalProcessingMs;

  factory PronunciationDebugPerformance.fromJson(Map<String, dynamic> json) {
    return PronunciationDebugPerformance(
      recordingDurationSeconds:
          (json['recording_duration_seconds'] as num?)?.toDouble(),
      whisperInferenceMs:
          (json['whisper_inference_ms'] as num?)?.toDouble() ?? 0,
      phonemeAnalysisMs: (json['phoneme_analysis_ms'] as num?)?.toDouble() ?? 0,
      totalProcessingMs: (json['total_processing_ms'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PronunciationDebugResult {
  const PronunciationDebugResult({
    required this.attemptId,
    required this.reference,
    required this.recognized,
    required this.language,
    required this.heardSpeech,
    required this.whisper,
    required this.performance,
    required this.phoneme,
    required this.assessment,
  });

  final int attemptId;
  final String reference;
  final String recognized;
  final String language;
  final bool heardSpeech;
  final PronunciationDebugWhisper whisper;
  final PronunciationDebugPerformance performance;

  /// Null when nothing was heard - there is no phoneme comparison to show.
  final PronunciationDebugPhoneme? phoneme;
  final PronunciationDebugAssessment? assessment;

  factory PronunciationDebugResult.fromJson(Map<String, dynamic> json) {
    return PronunciationDebugResult(
      attemptId: json['attempt_id'] as int? ?? 0,
      reference: json['reference'] as String? ?? '',
      recognized: json['recognized'] as String? ?? '',
      language: json['language'] as String? ?? '',
      heardSpeech: json['heard_speech'] as bool? ?? false,
      whisper: PronunciationDebugWhisper.fromJson(
        (json['whisper'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      performance: PronunciationDebugPerformance.fromJson(
        (json['performance'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      phoneme:
          json['phoneme'] == null
              ? null
              : PronunciationDebugPhoneme.fromJson(
                (json['phoneme'] as Map).cast<String, dynamic>(),
              ),
      assessment:
          json['assessment'] == null
              ? null
              : PronunciationDebugAssessment.fromJson(
                (json['assessment'] as Map).cast<String, dynamic>(),
              ),
    );
  }
}
