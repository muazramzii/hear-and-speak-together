/// The fixed character set a child picks from. Mirrors the backend's
/// `Avatar` choices - no photo upload means no camera permission and no
/// personal images stored.
enum ProfileAvatar {
  boy1('BOY_1'),
  boy2('BOY_2'),
  girl1('GIRL_1'),
  girl2('GIRL_2'),
  cat('CAT'),
  elephant('ELEPHANT');

  const ProfileAvatar(this.value);

  final String value;

  static ProfileAvatar fromValue(String? raw) {
    return ProfileAvatar.values.firstWhere(
      (avatar) => avatar.value == raw,
      orElse: () => ProfileAvatar.boy1,
    );
  }
}

/// A learner. Distinct from the account that logs in: one family login can
/// hold several children, each with their own level, points and streak.
class LearnerProfile {
  const LearnerProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.languageCode,
    required this.languageName,
    required this.level,
    required this.points,
    required this.pointsIntoLevel,
    required this.pointsToNextLevel,
    required this.streakDays,
  });

  final int id;
  final String name;
  final ProfileAvatar avatar;

  /// The language this child *practises*, independent of the app's interface
  /// language.
  final String languageCode;
  final String languageName;

  final int level;
  final int points;
  final int pointsIntoLevel;
  final int pointsToNextLevel;
  final int streakDays;

  /// How far through the current level, in 0..1, for the progress bar.
  double get levelProgress {
    final total = pointsIntoLevel + pointsToNextLevel;
    return total == 0 ? 0 : pointsIntoLevel / total;
  }

  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    return LearnerProfile(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      avatar: ProfileAvatar.fromValue(json['avatar'] as String?),
      languageCode: json['language_code'] as String? ?? 'en',
      languageName: json['language_name'] as String? ?? '',
      level: json['level'] as int? ?? 1,
      points: json['points'] as int? ?? 0,
      pointsIntoLevel: json['points_into_level'] as int? ?? 0,
      pointsToNextLevel: json['points_to_next_level'] as int? ?? 100,
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}
