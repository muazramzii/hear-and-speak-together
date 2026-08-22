import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/models/practice_result.dart';

Map<String, dynamic> _payload({
  bool heardSpeech = true,
  int? score = 88,
  double? similarity = 90,
  double? confidence = 85,
  double? completeness = 100,
  List<Map<String, dynamic>> errors = const [],
}) {
  return {
    'attempt_id': 1,
    'reference': 'bola',
    'recognized': heardSpeech ? 'bola' : '',
    'language': 'ms',
    'locale': 'ms-MY',
    'heard_speech': heardSpeech,
    'score': score,
    'similarity': similarity,
    'confidence': confidence,
    'completeness': completeness,
    'errors': errors,
    'feedback': 'Bagus!',
    'points_awarded': 7,
    'profile': {'id': 1, 'points': 230, 'level': 3, 'streak_days': 7},
    'can_retry': true,
  };
}

void main() {
  group('result parsing', () {
    test('parses the similarity/confidence/completeness breakdown', () {
      final result = PracticeResult.fromJson(_payload());

      expect(result.similarity, 90);
      expect(result.confidence, 85);
      expect(result.completeness, 100);
    });

    test('parses structured errors', () {
      final result = PracticeResult.fromJson(
        _payload(
          errors: const [
            {'type': 'missing_ending', 'expected': 'h', 'detected': ''},
          ],
        ),
      );

      expect(result.errors, hasLength(1));
      expect(result.errors.first.type, 'missing_ending');
      expect(result.errors.first.expected, 'h');
    });

    test('parses the running profile totals', () {
      final result = PracticeResult.fromJson(_payload());

      expect(result.profile.points, 230);
      expect(result.profile.level, 3);
      expect(result.profile.streakDays, 7);
    });

    test('silence is a result, not an error', () {
      final result = PracticeResult.fromJson(
        _payload(
          heardSpeech: false,
          score: null,
          similarity: null,
          confidence: null,
          completeness: null,
        ),
      );

      expect(result.heardSpeech, isFalse);
      expect(result.score, isNull);
      expect(result.isStrong, isFalse);
    });

    test('isStrong tracks the 75 threshold', () {
      expect(PracticeResult.fromJson(_payload(score: 75)).isStrong, isTrue);
      expect(PracticeResult.fromJson(_payload(score: 74)).isStrong, isFalse);
    });
  });
}
