import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hear_speak_together/features/parent/design/parent_theme.dart';
import 'package:hear_speak_together/features/school_admin/classrooms/school_admin_classrooms_screen.dart';
import 'package:hear_speak_together/features/school_admin/dashboard/school_admin_dashboard_screen.dart';
import 'package:hear_speak_together/features/school_admin/reports/report_preview_screen.dart';
import 'package:hear_speak_together/features/school_admin/reports/school_admin_reports_screen.dart';
import 'package:hear_speak_together/features/school_admin/school_admin_shell.dart';
import 'package:hear_speak_together/features/school_admin/teachers/school_admin_teachers_screen.dart';
import 'package:hear_speak_together/features/school_admin/widgets/school_admin_skeleton.dart';
import 'package:hear_speak_together/models/school.dart';
import 'package:hear_speak_together/models/school_analytics.dart';
import 'package:hear_speak_together/repositories/classroom_repository.dart';
import 'package:hear_speak_together/repositories/school_analytics_repository.dart';
import 'package:hear_speak_together/repositories/school_repository.dart';
import 'package:hear_speak_together/repositories/teacher_invitation_repository.dart';
import 'package:printing/printing.dart';

/// Fakes matching the project's own convention for testing a
/// `ConsumerWidget` screen against a repository - see
/// `test/connection_screen_test.dart`'s `_FakeHealthRepository`. Each
/// implements every public method of its real repository; methods a
/// given test never exercises just throw if accidentally called.
class _FakeSchoolRepository implements SchoolRepository {
  _FakeSchoolRepository({this.school});

  School? school;

  @override
  Future<School?> fetchMySchool() async => school;

  @override
  Future<School> createSchool({required String name}) =>
      throw UnimplementedError();

  @override
  Future<School> updateSchoolName({required int id, required String name}) =>
      throw UnimplementedError();

  @override
  Future<School> uploadLogo({required int id, required File logoFile}) =>
      throw UnimplementedError();
}

class _FakeSchoolAnalyticsRepository implements SchoolAnalyticsRepository {
  _FakeSchoolAnalyticsRepository({
    this.overview = const SchoolOverview(
      totalStudents: 0,
      totalTeachers: 0,
      totalClassrooms: 0,
      activeStudentsToday: 0,
      weeklyAverageScore: null,
      monthlyAverageScore: null,
    ),
    this.phonemes = const [],
    this.trends = const [],
  });

  final SchoolOverview overview;
  final List<PhonemeAnalytics> phonemes;
  final List<DailyTrend> trends;

  /// Records every `days` value the Reports screen's filter has
  /// requested so far - lets a test assert a chip tap actually changed
  /// what was fetched, not just that the UI redrew.
  final List<int> requestedDays = [];

  @override
  Future<SchoolOverview> fetchOverview() async => overview;

  @override
  Future<List<ClassroomAnalytics>> fetchClassroomAnalytics() async => const [];

  @override
  Future<List<PhonemeAnalytics>> fetchWeakestPhonemes({
    int? classroomId,
  }) async => phonemes;

  @override
  Future<List<DailyTrend>> fetchTrends({
    int days = 7,
    int? classroomId,
  }) async {
    requestedDays.add(days);
    return trends;
  }
}

class _FakeTeacherInvitationRepository implements TeacherInvitationRepository {
  _FakeTeacherInvitationRepository({this.invitations = const []});

  final List<TeacherInvitation> invitations;

  @override
  Future<List<TeacherInvitation>> fetchInvitations() async => invitations;

  @override
  Future<TeacherInvitation> inviteTeacher({required String email}) =>
      throw UnimplementedError();

  @override
  Future<TeacherInvitation> resetInvitation(int id) =>
      throw UnimplementedError();

  @override
  Future<TeacherInvitation> deactivateInvitation(int id) =>
      throw UnimplementedError();
}

class _FakeClassroomRepository implements ClassroomRepository {
  _FakeClassroomRepository({this.classrooms = const []});

  final List<Classroom> classrooms;

  @override
  Future<List<Classroom>> fetchClassrooms({bool? active, String? search}) async =>
      classrooms;

  @override
  Future<ClassroomDetail> fetchClassroomDetail(int id) =>
      throw UnimplementedError();

  @override
  Future<Classroom> createClassroom({required String name}) =>
      throw UnimplementedError();

  @override
  Future<Classroom> renameClassroom({required int id, required String name}) =>
      throw UnimplementedError();

  @override
  Future<void> archiveClassroom(int id) => throw UnimplementedError();

  @override
  Future<List<ClassroomMembership>> assignTeacher({
    required int classroomId,
    required String teacherPublicId,
    required String role,
  }) => throw UnimplementedError();

  @override
  Future<List<ClassroomMembership>> removeTeacher({
    required int classroomId,
    required String teacherPublicId,
  }) => throw UnimplementedError();

  @override
  Future<ClassroomTransferResult> moveStudent({
    required int classroomId,
    required int profileId,
  }) => throw UnimplementedError();
}

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: ParentTheme.light, home: child),
  );
}

void main() {
  group('SchoolAdminDashboardScreen', () {
    testWidgets('shows a skeleton while the school is loading', (
      tester,
    ) async {
      final completer = Completer<School?>();
      await tester.pumpWidget(
        _wrap(const SchoolAdminDashboardScreen(), [
          schoolRepositoryProvider.overrideWithValue(
            _FakeSchoolRepositoryDeferred(completer),
          ),
        ]),
      );
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);

      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the no-school empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminDashboardScreen(), [
          schoolRepositoryProvider.overrideWithValue(
            _FakeSchoolRepository(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Set up your school in Settings"),
        findsOneWidget,
      );
    });

    testWidgets('shows the school name and overview totals once loaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminDashboardScreen(), [
          schoolRepositoryProvider.overrideWithValue(
            _FakeSchoolRepository(
              school: const School(
                id: 1,
                name: 'Sunshine School',
                logo: null,
                adminEmail: 'admin@example.com',
                isActive: true,
              ),
            ),
          ),
          schoolAnalyticsRepositoryProvider.overrideWithValue(
            _FakeSchoolAnalyticsRepository(
              overview: const SchoolOverview(
                totalStudents: 12,
                totalTeachers: 3,
                totalClassrooms: 2,
                activeStudentsToday: 4,
                weeklyAverageScore: 81,
                monthlyAverageScore: 77,
              ),
              phonemes: const [
                PhonemeAnalytics(
                  phoneme: 'th',
                  errorRate: 62,
                  totalOccurrences: 18,
                  affectedStudents: 9,
                ),
              ],
              trends: [
                DailyTrend(date: DateTime.now(), attempts: 5, averageScore: 80),
              ],
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sunshine School'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('81%'), findsOneWidget);
      expect(find.text('/th/'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });
  });

  group('SchoolAdminTeachersScreen', () {
    testWidgets('shows the empty state with no invitations', (tester) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminTeachersScreen(), [
          teacherInvitationRepositoryProvider.overrideWithValue(
            _FakeTeacherInvitationRepository(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No pending invitations'), findsOneWidget);
    });

    testWidgets('lists an invitation email and code', (tester) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminTeachersScreen(), [
          teacherInvitationRepositoryProvider.overrideWithValue(
            _FakeTeacherInvitationRepository(
              invitations: [
                TeacherInvitation(
                  id: 1,
                  email: 'teacher@example.com',
                  invitationCode: 'ABC12345',
                  schoolName: 'Sunshine School',
                  invitedByEmail: 'admin@example.com',
                  expiresAt: DateTime.now().add(const Duration(days: 5)),
                  acceptedAt: null,
                  isActive: true,
                ),
              ],
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('teacher@example.com'), findsOneWidget);
      expect(find.text('ABC12345'), findsOneWidget);
    });
  });

  group('SchoolAdminClassroomsScreen', () {
    testWidgets('shows the empty state with no classrooms', (tester) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminClassroomsScreen(), [
          classroomRepositoryProvider.overrideWithValue(
            _FakeClassroomRepository(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No classrooms yet'), findsOneWidget);
    });

    testWidgets('lists a classroom name and code', (tester) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminClassroomsScreen(), [
          classroomRepositoryProvider.overrideWithValue(
            _FakeClassroomRepository(
              classrooms: const [
                Classroom(
                  id: 1,
                  name: 'Classroom Alpha',
                  classroomCode: 'ABC-294',
                  isActive: true,
                  studentCount: 10,
                ),
              ],
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Classroom Alpha'), findsOneWidget);
      expect(find.text('ABC-294'), findsOneWidget);
      expect(find.text('10 students'), findsOneWidget);
    });
  });

  group('SchoolAdminReportsScreen', () {
    testWidgets('shows the export menu button', (tester) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminReportsScreen(), [
          schoolRepositoryProvider.overrideWithValue(_FakeSchoolRepository()),
          schoolAnalyticsRepositoryProvider.overrideWithValue(
            _FakeSchoolAnalyticsRepository(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Export report'), findsOneWidget);
    });

    testWidgets('shows the no-report-yet empty state with no students', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminReportsScreen(), [
          schoolRepositoryProvider.overrideWithValue(_FakeSchoolRepository()),
          schoolAnalyticsRepositoryProvider.overrideWithValue(
            _FakeSchoolAnalyticsRepository(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No report available yet'), findsOneWidget);
    });

    testWidgets('shows the no-activity empty state when the trend is all zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SchoolAdminReportsScreen(), [
          schoolRepositoryProvider.overrideWithValue(_FakeSchoolRepository()),
          schoolAnalyticsRepositoryProvider.overrideWithValue(
            _FakeSchoolAnalyticsRepository(
              overview: const SchoolOverview(
                totalStudents: 5,
                totalTeachers: 1,
                totalClassrooms: 1,
                activeStudentsToday: 0,
                weeklyAverageScore: null,
                monthlyAverageScore: null,
              ),
              trends: [
                DailyTrend(date: DateTime.now(), attempts: 0, averageScore: 0),
              ],
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      // The Trend section sits below the fold in the test surface's
      // default viewport - ListView virtualizes its children, so it
      // isn't built (and can't be found) until scrolled into view.
      final emptyState = find.text('No activity recorded in this period.');
      await tester.scrollUntilVisible(
        emptyState,
        300.0,
        scrollable: find.byType(Scrollable),
      );

      expect(emptyState, findsOneWidget);
    });

    testWidgets(
      'tapping a filter chip re-fetches the trend with a new day count',
      (tester) async {
        final analyticsRepo = _FakeSchoolAnalyticsRepository(
          overview: const SchoolOverview(
            totalStudents: 5,
            totalTeachers: 1,
            totalClassrooms: 1,
            activeStudentsToday: 2,
            weeklyAverageScore: 80,
            monthlyAverageScore: 75,
          ),
          trends: [
            DailyTrend(date: DateTime.now(), attempts: 3, averageScore: 80),
          ],
        );

        await tester.pumpWidget(
          _wrap(const SchoolAdminReportsScreen(), [
            schoolRepositoryProvider.overrideWithValue(
              _FakeSchoolRepository(),
            ),
            schoolAnalyticsRepositoryProvider.overrideWithValue(
              analyticsRepo,
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(analyticsRepo.requestedDays, contains(7));

        final chip = find.widgetWithText(ChoiceChip, 'Last 30 days');
        await tester.scrollUntilVisible(
          chip,
          300.0,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(analyticsRepo.requestedDays, contains(30));
      },
    );
  });

  group('ReportPreviewScreen', () {
    testWidgets('renders the given title and a PdfPreview', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReportPreviewScreen(
            title: 'School Report',
            fileName: 'school_report.pdf',
            bytes: Uint8List.fromList(const [0]),
          ),
          const [],
        ),
      );
      // A single frame only - PdfPreview rasterizes via a platform
      // channel that isn't registered under flutter test, so
      // `pumpAndSettle` would wait forever on its retry loop.
      await tester.pump();

      expect(find.text('School Report'), findsOneWidget);
      expect(find.byType(PdfPreview), findsOneWidget);
    });
  });

  group('SchoolAdminShell navigation', () {
    testWidgets('shows all five destinations and switches between them', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                SchoolAdminShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/dashboard',
                    builder: (context, state) =>
                        const Scaffold(body: Text('Dashboard body')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/teachers',
                    builder: (context, state) =>
                        const Scaffold(body: Text('Teachers body')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/classrooms',
                    builder: (context, state) =>
                        const Scaffold(body: Text('Classrooms body')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/reports',
                    builder: (context, state) =>
                        const Scaffold(body: Text('Reports body')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) =>
                        const Scaffold(body: Text('Settings body')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Teachers'), findsOneWidget);
      expect(find.text('Classrooms'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Dashboard body'), findsOneWidget);

      await tester.tap(find.text('Classrooms'));
      await tester.pumpAndSettle();

      expect(find.text('Classrooms body'), findsOneWidget);
      expect(find.text('Dashboard body'), findsNothing);
    });
  });
}

/// A tiny variant of `_FakeSchoolRepository` whose `fetchMySchool` never
/// resolves until the test completes it - for asserting on the loading
/// (skeleton) state specifically, mirroring
/// `ConnectionScreenTest`'s `Completer`-based loading-state test.
class _FakeSchoolRepositoryDeferred implements SchoolRepository {
  _FakeSchoolRepositoryDeferred(this._completer);

  final Completer<School?> _completer;

  @override
  Future<School?> fetchMySchool() => _completer.future;

  @override
  Future<School> createSchool({required String name}) =>
      throw UnimplementedError();

  @override
  Future<School> updateSchoolName({required int id, required String name}) =>
      throw UnimplementedError();

  @override
  Future<School> uploadLogo({required int id, required File logoFile}) =>
      throw UnimplementedError();
}
