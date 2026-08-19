import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/models/content.dart';
import 'package:hear_speak_together/models/learner_profile.dart';

void main() {
  group('LanguageCapabilities', () {
    test('english exposes prosody among its metrics', () {
      final capabilities = LanguageCapabilities.fromJson(const {
        'pronunciation_assessment': true,
        'prosody': true,
        'phoneme_names': true,
        'syllable_scores': true,
        'available_metrics': [
          'accuracy',
          'fluency',
          'completeness',
          'pronunciation',
          'prosody',
        ],
      });

      expect(capabilities.prosody, isTrue);
      expect(capabilities.supports('prosody'), isTrue);
    });

    test('malay reports no prosody, so the UI must not offer it', () {
      final capabilities = LanguageCapabilities.fromJson(const {
        'pronunciation_assessment': true,
        'prosody': false,
        'phoneme_names': false,
        'syllable_scores': false,
        'available_metrics': [
          'accuracy',
          'fluency',
          'completeness',
          'pronunciation',
        ],
      });

      expect(capabilities.prosody, isFalse);
      expect(capabilities.supports('prosody'), isFalse);
      expect(capabilities.supports('accuracy'), isTrue);
    });

    test('a missing capability block defaults to nothing supported', () {
      final capabilities = LanguageCapabilities.fromJson(const {});

      expect(capabilities.prosody, isFalse);
      expect(capabilities.availableMetrics, isEmpty);
    });
  });

  group('LanguageInfo', () {
    test('parses the locale and capability block together', () {
      final language = LanguageInfo.fromJson(const {
        'id': 2,
        'code': 'ms',
        'name': 'Bahasa Melayu',
        'locale': 'ms-MY',
        'tts_voice': 'ms-MY-YasminNeural',
        'capabilities': {
          'pronunciation_assessment': true,
          'prosody': false,
          'phoneme_names': false,
          'syllable_scores': false,
          'available_metrics': ['accuracy', 'fluency'],
        },
      });

      expect(language.locale, 'ms-MY');
      expect(language.ttsVoice, 'ms-MY-YasminNeural');
      expect(language.capabilities.prosody, isFalse);
    });
  });

  group('QuizRound', () {
    final round = QuizRound.fromJson(const {
      'word': {'id': 7, 'text': 'kucing', 'image_url': ''},
      'options': [
        {'id': 9, 'text': 'anjing', 'image_url': ''},
        {'id': 7, 'text': 'kucing', 'image_url': ''},
        {'id': 11, 'text': 'gajah', 'image_url': ''},
        {'id': 12, 'text': 'singa', 'image_url': ''},
      ],
      'correct_option_id': 7,
    });

    test('recognises the correct option', () {
      expect(round.isCorrect(7), isTrue);
      expect(round.isCorrect(9), isFalse);
    });

    test('includes the answer among the options', () {
      expect(round.options.map((o) => o.id), contains(round.correctOptionId));
    });
  });

  group('LearnerProfile', () {
    test('parses level and streak', () {
      final profile = LearnerProfile.fromJson(const {
        'id': 1,
        'name': 'Ali',
        'avatar': 'BOY_1',
        'language_code': 'ms',
        'language_name': 'Bahasa Melayu',
        'level': 3,
        'points': 230,
        'points_into_level': 30,
        'points_to_next_level': 70,
        'streak_days': 7,
      });

      expect(profile.level, 3);
      expect(profile.streakDays, 7);
      expect(profile.avatar, ProfileAvatar.boy1);
    });

    test('level progress is the fraction through the current level', () {
      final profile = LearnerProfile.fromJson(const {
        'id': 1,
        'name': 'Ali',
        'points_into_level': 30,
        'points_to_next_level': 70,
      });

      expect(profile.levelProgress, closeTo(0.3, 0.001));
    });

    test('a brand new profile does not divide by zero', () {
      final profile = LearnerProfile.fromJson(const {
        'id': 1,
        'name': 'Ali',
        'points_into_level': 0,
        'points_to_next_level': 0,
      });

      expect(profile.levelProgress, 0);
    });

    test('an unknown avatar falls back rather than throwing', () {
      final profile = LearnerProfile.fromJson(const {
        'id': 1,
        'name': 'Ali',
        'avatar': 'ROBOT',
      });

      expect(profile.avatar, ProfileAvatar.boy1);
    });
  });
}
