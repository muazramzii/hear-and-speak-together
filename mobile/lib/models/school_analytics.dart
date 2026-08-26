/// Read shapes for `GET /api/schools/analytics/*` (Phase 6 Task 7). Every
/// figure here is already computed server-side (deterministic aggregation
/// over real attempts) - these classes only parse the response, they
/// never calculate anything themselves.
library;

class SchoolOverview {
  const SchoolOverview({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalClassrooms,
    required this.activeStudentsToday,
    required this.weeklyAverageScore,
    required this.monthlyAverageScore,
  });

  final int totalStudents;
  final int totalTeachers;
  final int totalClassrooms;
  final int activeStudentsToday;

  /// Null when there is no scored attempt in that window at all - a
  /// school that hasn't practised yet has no average, not a misleading
  /// zero.
  final int? weeklyAverageScore;
  final int? monthlyAverageScore;

  factory SchoolOverview.fromJson(Map<String, dynamic> json) {
    return SchoolOverview(
      totalStudents: json['total_students'] as int? ?? 0,
      totalTeachers: json['total_teachers'] as int? ?? 0,
      totalClassrooms: json['total_classrooms'] as int? ?? 0,
      activeStudentsToday: json['active_students_today'] as int? ?? 0,
      weeklyAverageScore: json['weekly_average_score'] as int?,
      monthlyAverageScore: json['monthly_average_score'] as int?,
    );
  }
}

class ClassroomAnalytics {
  const ClassroomAnalytics({
    required this.classroomId,
    required this.classroomName,
    required this.teacherCount,
    required this.studentCount,
    required this.averagePronunciationScore,
    required this.completionRate,
  });

  final int classroomId;
  final String classroomName;
  final int teacherCount;
  final int studentCount;
  final int averagePronunciationScore;
  final double completionRate;

  factory ClassroomAnalytics.fromJson(Map<String, dynamic> json) {
    return ClassroomAnalytics(
      classroomId: json['classroom_id'] as int,
      classroomName: json['classroom_name'] as String? ?? '',
      teacherCount: json['teacher_count'] as int? ?? 0,
      studentCount: json['student_count'] as int? ?? 0,
      averagePronunciationScore:
          json['average_pronunciation_score'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PhonemeAnalytics {
  const PhonemeAnalytics({
    required this.phoneme,
    required this.errorRate,
    required this.totalOccurrences,
    required this.affectedStudents,
  });

  final String phoneme;
  final int errorRate;
  final int totalOccurrences;
  final int affectedStudents;

  factory PhonemeAnalytics.fromJson(Map<String, dynamic> json) {
    return PhonemeAnalytics(
      phoneme: json['phoneme'] as String? ?? '',
      errorRate: json['error_rate'] as int? ?? 0,
      totalOccurrences: json['total_occurrences'] as int? ?? 0,
      affectedStudents: json['affected_students'] as int? ?? 0,
    );
  }
}

class DailyTrend {
  const DailyTrend({
    required this.date,
    required this.attempts,
    required this.averageScore,
  });

  final DateTime date;
  final int attempts;
  final int averageScore;

  factory DailyTrend.fromJson(Map<String, dynamic> json) {
    return DailyTrend(
      date: DateTime.parse(json['date'] as String),
      attempts: json['attempts'] as int? ?? 0,
      averageScore: json['average_score'] as int? ?? 0,
    );
  }
}
