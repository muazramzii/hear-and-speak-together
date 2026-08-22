/// A structured pronunciation error, e.g. a dropped final sound.
///
/// Produced by the backend's phoneme-alignment step - only ever describes
/// what the alignment actually found, never a guessed or invented mistake.
class PracticeErrorDetail {
  const PracticeErrorDetail({
    required this.type,
    required this.expected,
    required this.detected,
  });

  final String type; // e.g. 'missing_ending', 'wrong_consonant'
  final String? expected;
  final String? detected;

  factory PracticeErrorDetail.fromJson(Map<String, dynamic> json) {
    return PracticeErrorDetail(
      type: json['type'] as String? ?? '',
      expected: json['expected'] as String?,
      detected: json['detected'] as String?,
    );
  }
}

/// The learner's running totals, returned with each attempt so the UI can
/// update points and streak without a second request.
class ProfileTotals {
  const ProfileTotals({
    required this.id,
    required this.points,
    required this.level,
    required this.streakDays,
  });

  final int id;
  final int points;
  final int level;
  final int streakDays;

  factory ProfileTotals.fromJson(Map<String, dynamic> json) {
    return ProfileTotals(
      id: json['id'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}

/// The outcome of one speaking attempt.
///
/// Scored entirely on the server by a self-hosted speech recognition engine
/// and a deterministic pronunciation-scoring algorithm - the app never talks
/// to a speech provider directly and has no notion of which one is used.
class PracticeResult {
  const PracticeResult({
    required this.attemptId,
    required this.referenceText,
    required this.recognizedText,
    required this.languageCode,
    required this.locale,
    required this.heardSpeech,
    required this.score,
    required this.similarity,
    required this.confidence,
    required this.completeness,
    required this.errors,
    required this.feedback,
    required this.pointsAwarded,
    required this.profile,
    required this.canRetry,
  });

  final int attemptId;
  final String referenceText;
  final String recognizedText;
  final String languageCode;
  final String locale;

  /// False when the recording contained nothing recognisable. Not an error -
  /// a very ordinary thing for a child to do.
  final bool heardSpeech;

  /// The single headline number. Null when nothing was heard.
  final int? score;

  /// Phonetic-feature similarity between the reference and spoken word, 0-100.
  final double? similarity;

  /// The recognition engine's own confidence in the transcription, 0-100.
  final double? confidence;

  /// How much of the reference word's sound content was present, 0-100.
  final double? completeness;

  final List<PracticeErrorDetail> errors;
  final String feedback;
  final int pointsAwarded;
  final ProfileTotals profile;
  final bool canRetry;

  bool get isStrong => (score ?? 0) >= 75;

  factory PracticeResult.fromJson(Map<String, dynamic> json) {
    return PracticeResult(
      attemptId: json['attempt_id'] as int? ?? 0,
      referenceText: json['reference'] as String? ?? '',
      recognizedText: json['recognized'] as String? ?? '',
      languageCode: json['language'] as String? ?? 'en',
      locale: json['locale'] as String? ?? '',
      heardSpeech: json['heard_speech'] as bool? ?? false,
      score: (json['score'] as num?)?.round(),
      similarity: (json['similarity'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      completeness: (json['completeness'] as num?)?.toDouble(),
      errors:
          (json['errors'] as List?)
              ?.map(
                (e) => PracticeErrorDetail.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
      feedback: json['feedback'] as String? ?? '',
      pointsAwarded: json['points_awarded'] as int? ?? 0,
      profile: ProfileTotals.fromJson(
        (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      canRetry: json['can_retry'] as bool? ?? true,
    );
  }
}
