/// A single feedback observation shown under the score.
///
/// `tone` exists so the meaning survives without colour: a checklist that
/// distinguishes praise from suggestion only by green versus amber is
/// unusable for a colour-blind child.
class PracticeTip {
  const PracticeTip({
    required this.metric,
    required this.tone,
    required this.text,
  });

  final String metric;
  final String tone; // 'positive' | 'suggestion'
  final String text;

  bool get isPositive => tone == 'positive';

  factory PracticeTip.fromJson(Map<String, dynamic> json) {
    return PracticeTip(
      metric: json['metric'] as String? ?? '',
      tone: json['tone'] as String? ?? 'suggestion',
      text: json['text'] as String? ?? '',
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
class PracticeResult {
  const PracticeResult({
    required this.attemptId,
    required this.referenceText,
    required this.recognizedText,
    required this.languageCode,
    required this.locale,
    required this.heardSpeech,
    required this.score,
    required this.scores,
    required this.availableMetrics,
    required this.errorType,
    required this.feedback,
    required this.tips,
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

  /// Raw metric values. A null value means *not measured for this locale* and
  /// must never be rendered as zero.
  final Map<String, double?> scores;

  /// Which metrics this locale can measure at all. Anything absent here must
  /// not be shown, even as "unavailable" - Azure does not assess prosody for
  /// ms-MY, so an intonation row would be meaningless there.
  final List<String> availableMetrics;

  final String? errorType;
  final String feedback;
  final List<PracticeTip> tips;
  final int pointsAwarded;
  final ProfileTotals profile;
  final bool canRetry;

  /// Metrics worth showing in the details panel: supported by the locale
  /// *and* actually returned.
  Map<String, double> get displayableScores {
    final result = <String, double>{};
    for (final metric in availableMetrics) {
      final value = scores[metric];
      if (value != null) result[metric] = value;
    }
    return result;
  }

  bool get isStrong => (score ?? 0) >= 75;

  factory PracticeResult.fromJson(Map<String, dynamic> json) {
    final rawScores = (json['scores'] as Map?)?.cast<String, dynamic>() ?? {};

    return PracticeResult(
      attemptId: json['attempt_id'] as int? ?? 0,
      referenceText: json['reference_text'] as String? ?? '',
      recognizedText: json['recognized_text'] as String? ?? '',
      languageCode: json['language'] as String? ?? 'en',
      locale: json['locale'] as String? ?? '',
      heardSpeech: json['heard_speech'] as bool? ?? false,
      score: (json['score'] as num?)?.round(),
      scores: rawScores.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble()),
      ),
      availableMetrics:
          (json['available_metrics'] as List?)?.cast<String>() ?? const [],
      errorType: json['error_type'] as String?,
      feedback: json['feedback'] as String? ?? '',
      tips:
          (json['tips'] as List?)
              ?.map(
                (t) => PracticeTip.fromJson((t as Map).cast<String, dynamic>()),
              )
              .toList() ??
          const [],
      pointsAwarded: json['points_awarded'] as int? ?? 0,
      profile: ProfileTotals.fromJson(
        (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      canRetry: json['can_retry'] as bool? ?? true,
    );
  }
}
