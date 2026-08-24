/// One detected mistake in a spoken attempt - a phoneme-level diff entry
/// from the pronunciation engine, exactly as stored server-side.
class PronunciationErrorEntry {
  const PronunciationErrorEntry({
    required this.type,
    required this.expected,
    required this.detected,
  });

  final String type;
  final String expected;
  final String detected;

  factory PronunciationErrorEntry.fromJson(Map<String, dynamic> json) {
    return PronunciationErrorEntry(
      type: json['type'] as String? ?? '',
      expected: json['expected'] as String? ?? '',
      detected: json['detected'] as String? ?? '',
    );
  }
}

/// A single recording, scored - the professional, full-detail view a parent
/// or teacher sees, as opposed to the child-facing `PracticeResult`.
class Attempt {
  const Attempt({
    required this.id,
    required this.wordId,
    required this.wordText,
    required this.languageCode,
    required this.referenceText,
    required this.recognizedText,
    required this.score,
    required this.similarityScore,
    required this.confidenceScore,
    required this.completenessScore,
    required this.errors,
    required this.feedback,
    required this.pointsAwarded,
    required this.createdAt,
  });

  final int id;
  final int wordId;
  final String wordText;
  final String languageCode;
  final String referenceText;
  final String recognizedText;

  /// Null when the recording produced no measurable score.
  final int? score;
  final double? similarityScore;
  final double? confidenceScore;
  final double? completenessScore;
  final List<PronunciationErrorEntry> errors;
  final String feedback;
  final int pointsAwarded;
  final DateTime createdAt;

  bool get passed => (score ?? 0) >= 75;

  factory Attempt.fromJson(Map<String, dynamic> json) {
    return Attempt(
      id: json['id'] as int? ?? 0,
      wordId: json['word'] as int? ?? 0,
      wordText: json['word_text'] as String? ?? '',
      languageCode: json['language_code'] as String? ?? 'en',
      referenceText: json['reference_text'] as String? ?? '',
      recognizedText: json['recognized_text'] as String? ?? '',
      score: (json['score'] as num?)?.round(),
      similarityScore: (json['similarity_score'] as num?)?.toDouble(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      completenessScore: (json['completeness_score'] as num?)?.toDouble(),
      errors:
          (json['errors'] as List? ?? const [])
              .map(
                (item) => PronunciationErrorEntry.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      feedback: json['feedback'] as String? ?? '',
      pointsAwarded: json['points_awarded'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// One page of a paginated attempt list, mirroring DRF's `PageNumberPagination`
/// envelope (`count`/`next`/`previous`/`results`).
class AttemptPage {
  const AttemptPage({
    required this.count,
    required this.hasNext,
    required this.results,
  });

  final int count;
  final bool hasNext;
  final List<Attempt> results;

  factory AttemptPage.fromJson(Map<String, dynamic> json) {
    return AttemptPage(
      count: json['count'] as int? ?? 0,
      hasNext: json['next'] != null,
      results:
          (json['results'] as List? ?? const [])
              .map(
                (item) =>
                    Attempt.fromJson((item as Map).cast<String, dynamic>()),
              )
              .toList(),
    );
  }
}
