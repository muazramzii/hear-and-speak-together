import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/models/attempt.dart';

void main() {
  group('Attempt', () {
    test('parses the full record', () {
      final attempt = Attempt.fromJson(const {
        'id': 5,
        'word': 3,
        'word_text': 'elephant',
        'language_code': 'en',
        'reference_text': 'elephant',
        'recognized_text': 'elepant',
        'score': 82,
        'similarity_score': 78.5,
        'confidence_score': 91.0,
        'completeness_score': 85.0,
        'errors': [
          {'type': 'missing_phoneme', 'expected': 'f', 'detected': ''},
        ],
        'feedback': 'Try saying the ending sound more clearly.',
        'points_awarded': 10,
        'created_at': '2026-08-24T10:00:00Z',
      });

      expect(attempt.wordText, 'elephant');
      expect(attempt.recognizedText, 'elepant');
      expect(attempt.score, 82);
      expect(attempt.passed, isTrue);
      expect(attempt.errors.single.type, 'missing_phoneme');
      expect(attempt.errors.single.expected, 'f');
    });

    test('a below-target score is not a pass', () {
      final attempt = Attempt.fromJson(const {
        'id': 1,
        'score': 40,
        'created_at': '2026-08-24T10:00:00Z',
      });

      expect(attempt.passed, isFalse);
    });

    test('a null score is not a pass', () {
      final attempt = Attempt.fromJson(const {
        'id': 1,
        'created_at': '2026-08-24T10:00:00Z',
      });

      expect(attempt.score, isNull);
      expect(attempt.passed, isFalse);
    });
  });

  group('AttemptPage', () {
    test('parses the DRF pagination envelope', () {
      final page = AttemptPage.fromJson(const {
        'count': 42,
        'next': 'http://example.com/api/attempts/?page=2',
        'previous': null,
        'results': [
          {'id': 1, 'created_at': '2026-08-24T10:00:00Z'},
        ],
      });

      expect(page.count, 42);
      expect(page.hasNext, isTrue);
      expect(page.results, hasLength(1));
    });

    test('a last page has no next link', () {
      final page = AttemptPage.fromJson(const {
        'count': 1,
        'next': null,
        'results': [],
      });

      expect(page.hasNext, isFalse);
      expect(page.results, isEmpty);
    });
  });
}
