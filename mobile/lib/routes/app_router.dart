import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/dev/component_showcase_screen.dart';
import '../features/dev/pronunciation_sandbox_screen.dart';
import '../features/health/connection_screen.dart';
import '../features/home/home_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/lesson/lesson_session_screen.dart';
import '../features/lessons/lesson_list_screen.dart';
import '../features/parent/dashboard/parent_dashboard_screen.dart';
import '../features/parent/parent_shell.dart';
import '../features/parent/profile/parent_profile_screen.dart';
import '../features/parent/progress/attempt_detail_screen.dart';
import '../features/parent/progress/parent_progress_screen.dart';
import '../features/parent/reports/parent_reports_screen.dart';
import '../features/parent/students/parent_students_screen.dart';
import '../features/practice/speak_lesson_screen.dart';
import '../features/profiles/profile_picker_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/quiz/choice_round_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/school_admin/classrooms/school_admin_classroom_detail_screen.dart';
import '../features/school_admin/classrooms/school_admin_classrooms_screen.dart';
import '../features/school_admin/dashboard/school_admin_dashboard_screen.dart';
import '../features/school_admin/reports/school_admin_reports_screen.dart';
import '../features/school_admin/school_admin_shell.dart';
import '../features/school_admin/settings/school_admin_settings_screen.dart';
import '../features/school_admin/teachers/school_admin_teachers_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/students/student_detail_screen.dart';
import '../features/students/students_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/choice_session_provider.dart';
import '../repositories/profile_repository.dart';

/// Route parameters arrive as strings; a malformed one must not crash the app.
int _lessonId(GoRouterState state) {
  return int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 0;
}

String _languageCode(GoRouterState state) {
  return state.uri.queryParameters['lang'] ?? 'en';
}

/// Null means Speak, which has no `ChoiceMode` of its own.
ChoiceMode? _choiceMode(GoRouterState state) {
  return switch (state.pathParameters['mode']) {
    'listen' => ChoiceMode.listen,
    'quiz' => ChoiceMode.quiz,
    _ => null,
  };
}

/// Route paths and names, so navigation never uses raw strings.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profiles = '/profiles';
  static const String connection = '/connection';
  // Phase 2: developer-only AI validation tool, not part of the child-facing
  // flow. Gated server-side on `is_staff`, same as the endpoints it calls.
  static const String pronunciationSandbox = '/dev/pronunciation-sandbox';
  // Phase 3: developer-only design-system review screen. Not part of the
  // child-facing flow and calls no API - purely local widget review.
  static const String componentShowcase = '/dev/component-showcase';

  // Bottom-navigation branches.
  static const String home = '/home';
  static const String progress = '/progress';
  static const String rewards = '/rewards';
  static const String settings = '/settings';

  // Parent/teacher views, pushed from Home.
  static const String students = 'students';
  static const String studentDetail = 'students/:profileId';

  // Lesson pickers, pushed from the home mode grid.
  static const String learnLessons = 'learn-lessons';
  static const String modeLessons = 'lessons/:mode';

  // Lesson-scoped mode screens. Superseded for real navigation by
  // `lessonSession` below (Phase 3 Stage 3), which walks all four modes in
  // one guided sequence - these stay registered but are no longer linked to
  // from anywhere in the app, same tradeoff already accepted for `learn` and
  // `listen`/`quiz` since Home's Stage 2 redesign.
  static const String learn = 'learn/:lessonId';
  static const String listen = 'listen/:lessonId';
  static const String speak = 'speak/:lessonId';
  static const String quiz = 'quiz/:lessonId';

  /// The guided lesson experience: Intro -> Learn -> Listen -> Speak -> Quiz
  /// -> Celebration, as nested state within one route.
  static const String lessonSession = 'lesson/:lessonId';

  // Parent Mode (Phase 4): a completely separate shell from the child-facing
  // routes above, reached automatically by any account whose role
  // supervises students - see the router's `redirect`.
  static const String parentRoot = '/parent';
  static const String parentDashboard = '/parent/dashboard';
  static const String parentStudents = '/parent/students';
  static const String parentProgress = '/parent/progress';
  static const String parentAttemptDetail = 'attempts/:attemptId';
  static const String parentReports = '/parent/reports';
  static const String parentProfile = '/parent/profile';

  // School Admin Mode (Phase 6): a third, separate shell reached by any
  // account with `UserRole.schoolAdmin` - see the router's `redirect`.
  // Mutually exclusive with Parent Mode above: the backend's `Role` enum
  // never lets one account be both.
  static const String schoolAdminRoot = '/school-admin';
  static const String schoolAdminDashboard = '/school-admin/dashboard';
  static const String schoolAdminTeachers = '/school-admin/teachers';
  static const String schoolAdminClassrooms = '/school-admin/classrooms';
  static const String schoolAdminClassroomDetail = ':classroomId';
  static const String schoolAdminReports = '/school-admin/reports';
  static const String schoolAdminSettings = '/school-admin/settings';

  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String profilesName = 'profiles';
  static const String connectionName = 'connection';
  static const String pronunciationSandboxName = 'pronunciation-sandbox';
  static const String componentShowcaseName = 'component-showcase';
  static const String homeName = 'home';
  static const String progressName = 'progress';
  static const String rewardsName = 'rewards';
  static const String settingsName = 'settings';
  static const String studentsName = 'students';
  static const String studentDetailName = 'student-detail';
  static const String learnLessonsName = 'learn-lessons';
  static const String modeLessonsName = 'mode-lessons';
  static const String learnName = 'learn';
  static const String listenName = 'listen';
  static const String speakName = 'speak';
  static const String quizName = 'quiz';
  static const String lessonSessionName = 'lesson-session';

  static const String parentDashboardName = 'parent-dashboard';
  static const String parentStudentsName = 'parent-students';
  static const String parentProgressName = 'parent-progress';
  static const String parentAttemptDetailName = 'parent-attempt-detail';
  static const String parentReportsName = 'parent-reports';
  static const String parentProfileName = 'parent-profile';

  static const String schoolAdminDashboardName = 'school-admin-dashboard';
  static const String schoolAdminTeachersName = 'school-admin-teachers';
  static const String schoolAdminClassroomsName = 'school-admin-classrooms';
  static const String schoolAdminClassroomDetailName =
      'school-admin-classroom-detail';
  static const String schoolAdminReportsName = 'school-admin-reports';
  static const String schoolAdminSettingsName = 'school-admin-settings';
}

/// Bridges a Riverpod [StateNotifier] to go_router's `refreshListenable`, so
/// the router re-evaluates its redirect whenever auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      // Only a change in *status* can alter routing. Ignoring the rest stops
      // every keystroke-driven state change from re-running the redirect.
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });

    // Choosing or clearing the active learner also changes where the app
    // should be.
    _ref.listen(activeProfileProvider, (previous, next) {
      if (previous?.id != next?.id) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.profiles,
        name: AppRoutes.profilesName,
        builder: (context, state) => const ProfilePickerScreen(),
      ),
      // The signed-in shell. Each branch keeps its own stack, so leaving a
      // lesson for the Progress tab and coming back returns to the lesson.
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.homeName,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.students,
                    name: AppRoutes.studentsName,
                    builder: (context, state) => const StudentsScreen(),
                    routes: [
                      GoRoute(
                        path: ':profileId',
                        name: AppRoutes.studentDetailName,
                        builder:
                            (context, state) => StudentDetailScreen(
                              profileId:
                                  int.tryParse(
                                    state.pathParameters['profileId'] ?? '',
                                  ) ??
                                  0,
                            ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: AppRoutes.learnLessons,
                    name: AppRoutes.learnLessonsName,
                    builder:
                        (context, state) => LearnLessonListScreen(
                          languageCode: _languageCode(state),
                        ),
                  ),
                  GoRoute(
                    path: AppRoutes.modeLessons,
                    name: AppRoutes.modeLessonsName,
                    builder:
                        (context, state) => LessonListScreen(
                          mode: _choiceMode(state),
                          languageCode: _languageCode(state),
                        ),
                  ),
                  GoRoute(
                    path: AppRoutes.learn,
                    name: AppRoutes.learnName,
                    builder:
                        (context, state) => LearnScreen(
                          lessonId: _lessonId(state),
                          languageCode: _languageCode(state),
                        ),
                  ),
                  GoRoute(
                    path: AppRoutes.listen,
                    name: AppRoutes.listenName,
                    builder:
                        (context, state) => ChoiceRoundScreen(
                          lessonId: _lessonId(state),
                          mode: ChoiceMode.listen,
                          languageCode: _languageCode(state),
                        ),
                  ),
                  GoRoute(
                    path: AppRoutes.speak,
                    name: AppRoutes.speakName,
                    builder:
                        (context, state) => SpeakLessonScreen(
                          lessonId: _lessonId(state),
                          languageCode: _languageCode(state),
                        ),
                  ),
                  GoRoute(
                    path: AppRoutes.quiz,
                    name: AppRoutes.quizName,
                    builder:
                        (context, state) => ChoiceRoundScreen(
                          lessonId: _lessonId(state),
                          mode: ChoiceMode.quiz,
                          languageCode: _languageCode(state),
                        ),
                  ),
                  GoRoute(
                    path: AppRoutes.lessonSession,
                    name: AppRoutes.lessonSessionName,
                    builder:
                        (context, state) => LessonSessionScreen(
                          lessonId: _lessonId(state),
                          languageCode: _languageCode(state),
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                name: AppRoutes.progressName,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.rewards,
                name: AppRoutes.rewardsName,
                builder: (context, state) => const RewardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.settingsName,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Phase 4: the Parent/Teacher Intelligence Platform - a completely
      // separate shell from the child-facing routes above. An account whose
      // role supervises students lands here automatically (see `redirect`)
      // and never sees the child navigation at all.
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                ParentShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.parentDashboard,
                name: AppRoutes.parentDashboardName,
                builder: (context, state) => const ParentDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.parentStudents,
                name: AppRoutes.parentStudentsName,
                builder: (context, state) => const ParentStudentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.parentProgress,
                name: AppRoutes.parentProgressName,
                builder: (context, state) => const ParentProgressScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.parentAttemptDetail,
                    name: AppRoutes.parentAttemptDetailName,
                    builder:
                        (context, state) => AttemptDetailScreen(
                          attemptId:
                              int.tryParse(
                                state.pathParameters['attemptId'] ?? '',
                              ) ??
                              0,
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.parentReports,
                name: AppRoutes.parentReportsName,
                builder: (context, state) => const ParentReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.parentProfile,
                name: AppRoutes.parentProfileName,
                builder: (context, state) => const ParentProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Phase 6 Task 8: the School Admin workspace - a third, separate
      // shell from both the child-facing routes and Parent Mode above. An
      // account with `UserRole.schoolAdmin` lands here automatically (see
      // `redirect`) and never sees either of the other two navigations.
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                SchoolAdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolAdminDashboard,
                name: AppRoutes.schoolAdminDashboardName,
                builder: (context, state) => const SchoolAdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolAdminTeachers,
                name: AppRoutes.schoolAdminTeachersName,
                builder: (context, state) => const SchoolAdminTeachersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolAdminClassrooms,
                name: AppRoutes.schoolAdminClassroomsName,
                builder: (context, state) => const SchoolAdminClassroomsScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.schoolAdminClassroomDetail,
                    name: AppRoutes.schoolAdminClassroomDetailName,
                    builder:
                        (context, state) => SchoolAdminClassroomDetailScreen(
                          classroomId:
                              int.tryParse(
                                state.pathParameters['classroomId'] ?? '',
                              ) ??
                              0,
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolAdminReports,
                name: AppRoutes.schoolAdminReportsName,
                builder: (context, state) => const SchoolAdminReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolAdminSettings,
                name: AppRoutes.schoolAdminSettingsName,
                builder: (context, state) => const SchoolAdminSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        // A developer aid, not part of the child-facing flow.
        path: AppRoutes.connection,
        name: AppRoutes.connectionName,
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        // Phase 2 AI validation sandbox - a developer aid, gated server-side
        // on `is_staff`. See PronunciationSandboxScreen's docstring.
        path: AppRoutes.pronunciationSandbox,
        name: AppRoutes.pronunciationSandboxName,
        builder: (context, state) => const PronunciationSandboxScreen(),
      ),
      GoRoute(
        // Phase 3 Stage 1 design-system review - a developer aid, calls no
        // API. See ComponentShowcaseScreen's docstring.
        path: AppRoutes.componentShowcase,
        name: AppRoutes.componentShowcaseName,
        builder: (context, state) => const ComponentShowcaseScreen(),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // The diagnostics screen and both dev-only screens are always
      // reachable.
      if (location == AppRoutes.connection ||
          location == AppRoutes.pronunciationSandbox ||
          location == AppRoutes.componentShowcase) {
        return null;
      }

      // Still restoring a stored session - hold on the splash screen rather
      // than flashing the sign-in form at an already-signed-in user.
      if (!auth.isResolved) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final onAuthScreen =
          location == AppRoutes.login || location == AppRoutes.register;

      if (!auth.isAuthenticated) {
        return onAuthScreen ? null : AppRoutes.login;
      }

      final onParentRoute = location.startsWith(AppRoutes.parentRoot);
      final onSchoolAdminRoute = location.startsWith(
        AppRoutes.schoolAdminRoot,
      );
      final supervisesStudents = auth.user?.role.supervisesStudents ?? false;
      final isSchoolAdmin = auth.user?.role.isSchoolAdmin ?? false;

      if (isSchoolAdmin) {
        // The School Admin workspace is its own app experience (Phase 6),
        // exactly like Parent Mode above: keep this account off the auth
        // screens, off the splash, and out of every other shell entirely.
        if (onAuthScreen || !onSchoolAdminRoute) {
          return AppRoutes.schoolAdminDashboard;
        }
        return null;
      }

      // Neither a Parent/Teacher nor a School Admin account should ever
      // end up in the School Admin workspace.
      if (onSchoolAdminRoute) {
        return AppRoutes.profiles;
      }

      if (supervisesStudents) {
        // Parent Mode is a separate app experience (Phase 4): keep a
        // parent/teacher account out of the auth screens, off the splash,
        // and out of the child-facing routes entirely. The one deliberate
        // exception is a lesson handed off from a dashboard recommendation
        // ("Start Practice") - that is a full switch into the practice
        // activity for the family's own shared device, not the child's
        // navigation chrome, so it is allowed through rather than bounced
        // straight back to the dashboard.
        final isLessonHandoff = location.startsWith('/home/lesson/');
        if (!isLessonHandoff && (onAuthScreen || !onParentRoute)) {
          return AppRoutes.parentDashboard;
        }
        return null;
      }

      // A student account should never end up in Parent Mode.
      if (onParentRoute) {
        return AppRoutes.profiles;
      }

      // Signed in: keep them out of the auth screens and off the splash.
      if (onAuthScreen || location == AppRoutes.splash) {
        return AppRoutes.profiles;
      }

      // Signed in but no child chosen yet. On a shared family tablet the
      // learner must be picked before any practice is credited to them.
      final hasActiveProfile = ref.read(activeProfileProvider) != null;
      if (!hasActiveProfile && location != AppRoutes.profiles) {
        return AppRoutes.profiles;
      }

      return null;
    },
  );
});
