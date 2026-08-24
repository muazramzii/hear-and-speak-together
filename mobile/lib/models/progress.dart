/// Headline numbers for the progress screen.
class ProgressSummary {
  const ProgressSummary({
    required this.averageScore,
    required this.practiceSessions,
    required this.wordsPractised,
    required this.wordsLearned,
    required this.lessonsStarted,
    required this.lessonsCompleted,
    required this.points,
    required this.level,
    required this.streakDays,
  });

  /// Null when nothing scoreable has been attempted yet - shown as a dash,
  /// never as 0%, which would read as "scored nothing".
  final int? averageScore;
  final int practiceSessions;
  final int wordsPractised;
  final int wordsLearned;
  final int lessonsStarted;
  final int lessonsCompleted;
  final int points;
  final int level;
  final int streakDays;

  bool get hasPractised => practiceSessions > 0;

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      averageScore: (json['average_score'] as num?)?.round(),
      practiceSessions: json['practice_sessions'] as int? ?? 0,
      wordsPractised: json['words_practised'] as int? ?? 0,
      wordsLearned: json['words_learned'] as int? ?? 0,
      lessonsStarted: json['lessons_started'] as int? ?? 0,
      lessonsCompleted: json['lessons_completed'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}

/// A word the learner keeps getting wrong.
class WeakWord {
  const WeakWord({
    required this.wordId,
    required this.text,
    required this.lessonId,
    required this.averageScore,
    required this.attempts,
  });

  final int wordId;
  final String text;
  final int lessonId;
  final int averageScore;
  final int attempts;

  factory WeakWord.fromJson(Map<String, dynamic> json) {
    return WeakWord(
      wordId: json['word_id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      lessonId: json['lesson_id'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.round() ?? 0,
      attempts: json['attempts'] as int? ?? 0,
    );
  }
}

class CategoryPerformance {
  const CategoryPerformance({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.averageScore,
    required this.attempts,
    required this.isWeak,
  });

  final int categoryId;
  final String name;
  final String icon;
  final int averageScore;
  final int attempts;
  final bool isWeak;

  factory CategoryPerformance.fromJson(Map<String, dynamic> json) {
    return CategoryPerformance(
      categoryId: json['category_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      averageScore: (json['average_score'] as num?)?.round() ?? 0,
      attempts: json['attempts'] as int? ?? 0,
      isWeak: json['is_weak'] as bool? ?? false,
    );
  }
}

class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.title,
    required this.category,
    required this.completedWords,
    required this.totalWords,
    required this.completionPercentage,
    required this.averageScore,
  });

  final int lessonId;
  final String title;
  final String category;
  final int completedWords;
  final int totalWords;
  final int completionPercentage;
  final int? averageScore;

  double get fraction => completionPercentage / 100;

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      lessonId: json['lesson_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      completedWords: json['completed_words'] as int? ?? 0,
      totalWords: json['total_words'] as int? ?? 0,
      completionPercentage: json['completion_percentage'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.round(),
    );
  }
}

/// One badge, earned or still locked. Locked ones are shown deliberately -
/// seeing what is still ahead is the point of a rewards screen.
class AchievementBadge {
  const AchievementBadge({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.points,
    required this.earned,
  });

  final String code;
  final String name;
  final String description;
  final String icon;
  final int points;
  final bool earned;

  factory AchievementBadge.fromJson(Map<String, dynamic> json) {
    return AchievementBadge(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🏅',
      points: json['points'] as int? ?? 0,
      earned: json['earned'] as bool? ?? false,
    );
  }
}

/// One day's average score, for the improvement line chart.
class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.averageScore,
    required this.attempts,
  });

  final DateTime date;
  final int averageScore;
  final int attempts;

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: DateTime.parse(json['date'] as String),
      averageScore: (json['average_score'] as num?)?.round() ?? 0,
      attempts: json['attempts'] as int? ?? 0,
    );
  }
}

/// A short attempt summary, for a chronological activity feed.
class RecentAttempt {
  const RecentAttempt({
    required this.id,
    required this.word,
    required this.score,
    required this.createdAt,
  });

  final int id;
  final String word;

  /// Null when the attempt produced no measurable score.
  final int? score;
  final DateTime createdAt;

  factory RecentAttempt.fromJson(Map<String, dynamic> json) {
    return RecentAttempt(
      id: json['id'] as int? ?? 0,
      word: json['word'] as String? ?? '',
      score: (json['score'] as num?)?.round(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// One sound's error rate - the flagship analytics feature. `frequency` is a
/// genuine substitution rate (errors ÷ how often the sound was attempted),
/// not a share of all errors, so it says "how often does this sound go
/// wrong", not "how loud is this sound among all mistakes".
class PhonemeStat {
  const PhonemeStat({
    required this.phoneme,
    required this.frequency,
    required this.occurrences,
    required this.sampleSize,
    required this.examples,
  });

  final String phoneme;
  final int frequency;
  final int occurrences;
  final int sampleSize;
  final List<String> examples;

  factory PhonemeStat.fromJson(Map<String, dynamic> json) {
    return PhonemeStat(
      phoneme: json['phoneme'] as String? ?? '',
      frequency: json['frequency'] as int? ?? 0,
      occurrences: json['occurrences'] as int? ?? 0,
      sampleSize: json['sample_size'] as int? ?? 0,
      examples:
          (json['examples'] as List? ?? const [])
              .map((item) => item as String)
              .toList(),
    );
  }
}

/// Strong and weak sounds together, as the phoneme breakdown is always
/// returned as a pair.
class PhonemeBreakdown {
  const PhonemeBreakdown({required this.weak, required this.strong});

  final List<PhonemeStat> weak;
  final List<PhonemeStat> strong;

  static const empty = PhonemeBreakdown(weak: [], strong: []);

  factory PhonemeBreakdown.fromJson(Map<String, dynamic> json) {
    List<PhonemeStat> parse(String key) {
      return (json[key] as List? ?? const [])
          .map(
            (item) =>
                PhonemeStat.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    }

    return PhonemeBreakdown(weak: parse('weak'), strong: parse('strong'));
  }
}

/// One week's headline numbers, for comparing this week against last.
class WeeklyWindow {
  const WeeklyWindow({
    required this.averageScore,
    required this.attempts,
    required this.wordsCompleted,
  });

  final int? averageScore;
  final int attempts;
  final int wordsCompleted;

  factory WeeklyWindow.fromJson(Map<String, dynamic> json) {
    return WeeklyWindow(
      averageScore: (json['average_score'] as num?)?.round(),
      attempts: json['attempts'] as int? ?? 0,
      wordsCompleted: json['words_completed'] as int? ?? 0,
    );
  }
}

/// This week vs last week - never phrased as a regression by the data
/// itself; a negative change is a fact for the screen to render calmly, not
/// a verdict.
class WeeklyComparison {
  const WeeklyComparison({
    required this.thisWeek,
    required this.lastWeek,
    required this.scoreChange,
    required this.attemptsChange,
    required this.wordsCompletedChange,
    required this.streakDays,
  });

  final WeeklyWindow thisWeek;
  final WeeklyWindow lastWeek;
  final int? scoreChange;
  final int? attemptsChange;
  final int? wordsCompletedChange;
  final int streakDays;

  factory WeeklyComparison.fromJson(Map<String, dynamic> json) {
    return WeeklyComparison(
      thisWeek: WeeklyWindow.fromJson(
        (json['this_week'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      lastWeek: WeeklyWindow.fromJson(
        (json['last_week'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      scoreChange: (json['score_change'] as num?)?.round(),
      attemptsChange: (json['attempts_change'] as num?)?.round(),
      wordsCompletedChange: (json['words_completed_change'] as num?)?.round(),
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}

/// What to practise next, and why. The payload shape depends on [type];
/// only the fields that type actually carries are non-null/non-empty.
class Recommendation {
  const Recommendation({
    required this.type,
    required this.reason,
    this.words = const [],
    this.categories = const [],
    this.daysSincePractice,
  });

  final String type;
  final String reason;
  final List<WeakWord> words;
  final List<CategoryPerformance> categories;
  final int? daysSincePractice;

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      type: json['type'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      words:
          (json['words'] as List? ?? const [])
              .map(
                (item) =>
                    WeakWord.fromJson((item as Map).cast<String, dynamic>()),
              )
              .toList(),
      categories:
          (json['categories'] as List? ?? const [])
              .map(
                (item) => CategoryPerformance.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      daysSincePractice: json['days_since_practice'] as int?,
    );
  }
}

/// Everything the progress screen needs, in one response.
class ProgressReport {
  const ProgressReport({
    required this.summary,
    required this.lessons,
    required this.categories,
    required this.weakWords,
    required this.recentAttempts,
    required this.trend,
    required this.phonemes,
    required this.weeklyComparison,
    required this.recommendations,
  });

  final ProgressSummary summary;
  final List<LessonProgress> lessons;
  final List<CategoryPerformance> categories;
  final List<WeakWord> weakWords;
  final List<RecentAttempt> recentAttempts;
  final List<TrendPoint> trend;
  final PhonemeBreakdown phonemes;
  final WeeklyComparison? weeklyComparison;
  final List<Recommendation> recommendations;

  factory ProgressReport.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) {
      return (json[key] as List? ?? const [])
          .map((item) => build((item as Map).cast<String, dynamic>()))
          .toList();
    }

    return ProgressReport(
      summary: ProgressSummary.fromJson(
        (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      lessons: parse('lessons', LessonProgress.fromJson),
      categories: parse('categories', CategoryPerformance.fromJson),
      weakWords: parse('weak_words', WeakWord.fromJson),
      recentAttempts: parse('recent_attempts', RecentAttempt.fromJson),
      trend: parse('trend', TrendPoint.fromJson),
      phonemes:
          json['phonemes'] == null
              ? PhonemeBreakdown.empty
              : PhonemeBreakdown.fromJson(
                (json['phonemes'] as Map).cast<String, dynamic>(),
              ),
      weeklyComparison:
          json['weekly_comparison'] == null
              ? null
              : WeeklyComparison.fromJson(
                (json['weekly_comparison'] as Map).cast<String, dynamic>(),
              ),
      recommendations: parse('recommendations', Recommendation.fromJson),
    );
  }
}
