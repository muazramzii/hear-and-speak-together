/// The Phase 6 multi-tenant school hierarchy: School -> Classroom ->
/// ClassroomMembership/Profile. Mirrors `apps.schools` on the backend.
class School {
  const School({
    required this.id,
    required this.name,
    required this.logo,
    required this.adminEmail,
    required this.isActive,
  });

  final int id;
  final String name;

  /// Null until an admin uploads one - shown as a placeholder mark, never
  /// a broken image.
  final String? logo;
  final String adminEmail;
  final bool isActive;

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String?,
      adminEmail: json['admin_email'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// One row of a classroom's staff list. `teacherId` is the account's
/// public UUID - never the backend's integer primary key, per the Phase
/// 6 architecture correction (Task 6).
class ClassroomMembership {
  const ClassroomMembership({
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.role,
  });

  final String teacherId;
  final String teacherName;
  final String teacherEmail;

  /// Raw backend value: LEAD_TEACHER / ASSISTANT / THERAPIST.
  final String role;

  factory ClassroomMembership.fromJson(Map<String, dynamic> json) {
    return ClassroomMembership(
      teacherId: json['teacher'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      teacherEmail: json['teacher_email'] as String? ?? '',
      role: json['role'] as String? ?? 'LEAD_TEACHER',
    );
  }

  String get roleLabel => switch (role) {
    'LEAD_TEACHER' => 'Lead teacher',
    'ASSISTANT' => 'Assistant',
    'THERAPIST' => 'Therapist',
    _ => role,
  };
}

/// List/summary shape - what `GET /api/classrooms/` returns for every
/// row. `staff` is null here (only the detail endpoint includes it) and
/// populated on [ClassroomDetail] instead of being duplicated as an
/// always-present-but-usually-empty field on this class.
class Classroom {
  const Classroom({
    required this.id,
    required this.name,
    required this.classroomCode,
    required this.isActive,
    required this.studentCount,
  });

  final int id;
  final String name;
  final String classroomCode;
  final bool isActive;
  final int studentCount;

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      classroomCode: json['classroom_code'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      studentCount: json['student_count'] as int? ?? 0,
    );
  }
}

/// `GET /api/classrooms/{id}/` - the list shape plus the staff roster.
class ClassroomDetail extends Classroom {
  const ClassroomDetail({
    required super.id,
    required super.name,
    required super.classroomCode,
    required super.isActive,
    required super.studentCount,
    required this.staff,
  });

  final List<ClassroomMembership> staff;

  factory ClassroomDetail.fromJson(Map<String, dynamic> json) {
    return ClassroomDetail(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      classroomCode: json['classroom_code'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      studentCount: json['student_count'] as int? ?? 0,
      staff: (json['staff'] as List<dynamic>? ?? const [])
          .map((row) => ClassroomMembership.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A code-based invitation for a teacher to join the school - see
/// `apps.schools.TeacherInvitation` (Task 5). This system has no email
/// delivery: the code itself, shown and copyable in the app, is the
/// entire mechanism.
class TeacherInvitation {
  const TeacherInvitation({
    required this.id,
    required this.email,
    required this.invitationCode,
    required this.schoolName,
    required this.invitedByEmail,
    required this.expiresAt,
    required this.acceptedAt,
    required this.isActive,
  });

  final int id;
  final String email;
  final String invitationCode;
  final String schoolName;
  final String invitedByEmail;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final bool isActive;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => isActive && acceptedAt == null && !isExpired;

  factory TeacherInvitation.fromJson(Map<String, dynamic> json) {
    return TeacherInvitation(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      invitationCode: json['invitation_code'] as String? ?? '',
      schoolName: json['school_name'] as String? ?? '',
      invitedByEmail: json['invited_by_email'] as String? ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
