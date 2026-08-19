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

/// Everything the progress screen needs, in one response.
class ProgressReport {
  const ProgressReport({
    required this.summary,
    required this.lessons,
    required this.categories,
    required this.weakWords,
  });

  final ProgressSummary summary;
  final List<LessonProgress> lessons;
  final List<CategoryPerformance> categories;
  final List<WeakWord> weakWords;

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
    );
  }
}
