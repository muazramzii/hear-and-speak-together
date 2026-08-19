import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/models/progress.dart';

void main() {
  group('ProgressSummary', () {
    test('a new learner has no average rather than a zero', () {
      // Zero would read as "scored nothing"; null means "nothing measured".
      final summary = ProgressSummary.fromJson(const {
        'average_score': null,
        'practice_sessions': 0,
      });

      expect(summary.averageScore, isNull);
      expect(summary.hasPractised, isFalse);
    });

    test('parses the full summary', () {
      final summary = ProgressSummary.fromJson(const {
        'average_score': 85,
        'practice_sessions': 12,
        'words_practised': 8,
        'words_learned': 6,
        'lessons_started': 2,
        'lessons_completed': 1,
        'points': 230,
        'level': 3,
        'streak_days': 7,
      });

      expect(summary.averageScore, 85);
      expect(summary.wordsLearned, 6);
      expect(summary.streakDays, 7);
      expect(summary.hasPractised, isTrue);
    });

    test('a missing payload does not throw', () {
      final summary = ProgressSummary.fromJson(const {});

      expect(summary.practiceSessions, 0);
      expect(summary.level, 1);
    });
  });

  group('LessonProgress', () {
    test('fraction mirrors the percentage', () {
      final lesson = LessonProgress.fromJson(const {
        'lesson_id': 1,
        'title': 'Animals',
        'completed_words': 2,
        'total_words': 4,
        'completion_percentage': 50,
      });

      expect(lesson.fraction, closeTo(0.5, 0.001));
    });

    test('an unstarted lesson is zero, not a crash', () {
      final lesson = LessonProgress.fromJson(const {'lesson_id': 1});

      expect(lesson.completionPercentage, 0);
      expect(lesson.fraction, 0);
      expect(lesson.averageScore, isNull);
    });
  });

  group('WeakWord', () {
    test('parses the analytics row', () {
      final word = WeakWord.fromJson(const {
        'word_id': 7,
        'text': 'elephant',
        'lesson_id': 2,
        'average_score': 58,
        'attempts': 5,
      });

      expect(word.text, 'elephant');
      expect(word.averageScore, 58);
      expect(word.attempts, 5);
    });
  });

  group('AchievementBadge', () {
    test('locked badges are still parsed, so they can be shown as goals', () {
      final badge = AchievementBadge.fromJson(const {
        'code': 'TEN_WORDS',
        'name': 'Fast Learner',
        'description': 'You have learned 10 words!',
        'icon': '⚡',
        'points': 30,
        'earned': false,
      });

      expect(badge.earned, isFalse);
      expect(badge.icon, '⚡');
    });

    test('falls back to a default icon', () {
      final badge = AchievementBadge.fromJson(const {'code': 'X'});

      expect(badge.icon, '🏅');
    });
  });

  group('ProgressReport', () {
    test('parses every section', () {
      final report = ProgressReport.fromJson(const {
        'summary': {'average_score': 80, 'practice_sessions': 3},
        'lessons': [
          {'lesson_id': 1, 'title': 'Animals', 'completion_percentage': 25},
        ],
        'categories': [
          {'category_id': 1, 'name': 'Animals', 'average_score': 60, 'is_weak': true},
        ],
        'weak_words': [
          {'word_id': 3, 'text': 'gajah', 'average_score': 55, 'attempts': 3},
        ],
      });

      expect(report.summary.averageScore, 80);
      expect(report.lessons, hasLength(1));
      expect(report.categories.first.isWeak, isTrue);
      expect(report.weakWords.first.text, 'gajah');
    });

    test('missing sections become empty lists', () {
      final report = ProgressReport.fromJson(const {});

      expect(report.lessons, isEmpty);
      expect(report.categories, isEmpty);
      expect(report.weakWords, isEmpty);
    });
  });
}
