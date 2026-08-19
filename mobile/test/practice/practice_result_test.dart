import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/models/practice_result.dart';

Map<String, dynamic> _payload({
  required List<String> availableMetrics,
  double? prosody,
  bool heardSpeech = true,
  int? score = 88,
}) {
  return {
    'attempt_id': 1,
    'reference_text': 'bola',
    'recognized_text': heardSpeech ? 'bola' : '',
    'language': 'ms',
    'locale': 'ms-MY',
    'heard_speech': heardSpeech,
    'score': score,
    'scores': {
      'pronunciation': score,
      'accuracy': 85,
      'fluency': 90,
      'completeness': 100,
      'prosody': prosody,
    },
    'available_metrics': availableMetrics,
    'error_type': null,
    'feedback': 'Bagus!',
    'tips': [
      {'metric': 'accuracy', 'tone': 'positive', 'text': 'Sebutan jelas'},
      {
        'metric': 'fluency',
        'tone': 'suggestion',
        'text': 'Cuba sebut lebih perlahan',
      },
    ],
    'points_awarded': 7,
    'profile': {'id': 1, 'points': 230, 'level': 3, 'streak_days': 7},
    'can_retry': true,
  };
}

void main() {
  group('locale-aware score display', () {
    test('a Malay result never exposes an intonation score', () {
      // Azure does not assess prosody for ms-MY, so the backend sends null and
      // omits it from available_metrics. Showing an intonation row here would
      // be inventing a measurement.
      final result = PracticeResult.fromJson(
        _payload(
          availableMetrics: const [
            'accuracy',
            'fluency',
            'completeness',
            'pronunciation',
          ],
          prosody: null,
        ),
      );

      expect(result.displayableScores.containsKey('prosody'), isFalse);
      expect(result.scores['prosody'], isNull);
    });

    test('an English result does expose intonation', () {
      final result = PracticeResult.fromJson(
        _payload(
          availableMetrics: const [
            'accuracy',
            'fluency',
            'completeness',
            'pronunciation',
            'prosody',
          ],
          prosody: 91,
        ),
      );

      expect(result.displayableScores['prosody'], 91);
    });

    test('a metric advertised but not returned is still not displayed', () {
      // Defensive: if the backend ever lists prosody while sending null, the
      // UI must omit it rather than render an empty or zero row.
      final result = PracticeResult.fromJson(
        _payload(
          availableMetrics: const ['accuracy', 'prosody'],
          prosody: null,
        ),
      );

      expect(result.displayableScores.containsKey('prosody'), isFalse);
      expect(result.displayableScores.containsKey('accuracy'), isTrue);
    });

    test('a returned metric that the locale does not support is ignored', () {
      final result = PracticeResult.fromJson(
        _payload(availableMetrics: const ['accuracy'], prosody: 95),
      );

      expect(result.displayableScores.keys, ['accuracy']);
    });
  });

  group('result parsing', () {
    test('parses tips with their tone', () {
      final result = PracticeResult.fromJson(
        _payload(availableMetrics: const ['accuracy']),
      );

      expect(result.tips, hasLength(2));
      expect(result.tips.first.isPositive, isTrue);
      expect(result.tips.last.isPositive, isFalse);
    });

    test('parses the running profile totals', () {
      final result = PracticeResult.fromJson(
        _payload(availableMetrics: const ['accuracy']),
      );

      expect(result.profile.points, 230);
      expect(result.profile.level, 3);
      expect(result.profile.streakDays, 7);
    });

    test('silence is a result, not an error', () {
      final result = PracticeResult.fromJson(
        _payload(
          availableMetrics: const ['accuracy'],
          heardSpeech: false,
          score: null,
        ),
      );

      expect(result.heardSpeech, isFalse);
      expect(result.score, isNull);
      expect(result.isStrong, isFalse);
    });

    test('isStrong tracks the 75 threshold', () {
      expect(
        PracticeResult.fromJson(
          _payload(availableMetrics: const [], score: 75),
        ).isStrong,
        isTrue,
      );
      expect(
        PracticeResult.fromJson(
          _payload(availableMetrics: const [], score: 74),
        ).isStrong,
        isFalse,
      );
    });
  });
}
