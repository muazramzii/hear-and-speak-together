/// Who the account belongs to. Mirrors the backend's `Role` choices.
enum UserRole {
  student('STUDENT'),
  parent('PARENT'),
  teacher('TEACHER');

  const UserRole(this.value);

  final String value;

  static UserRole fromValue(String? raw) {
    return UserRole.values.firstWhere(
      (role) => role.value == raw,
      orElse: () => UserRole.student,
    );
  }

  /// Parents and teachers share the monitoring shell.
  bool get supervisesStudents => this == UserRole.parent || this == UserRole.teacher;
}

/// The languages the app teaches. Mirrors the backend's `LanguageCode`.
enum AppLanguage {
  english('en', 'English'),
  malay('ms', 'Bahasa Melayu');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(String? raw) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == raw,
      orElse: () => AppLanguage.english,
    );
  }
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.preferredLanguage,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final AppLanguage preferredLanguage;

  /// The part of the name a greeting should use: "Hi, Amir!"
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromValue(json['role'] as String?),
      preferredLanguage: AppLanguage.fromCode(
        json['preferred_language'] as String?,
      ),
    );
  }

  User copyWith({String? name, AppLanguage? preferredLanguage}) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}
