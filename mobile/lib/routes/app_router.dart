import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/health/connection_screen.dart';
import '../features/home/home_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/practice/speak_lesson_screen.dart';
import '../features/profiles/profile_picker_screen.dart';
import '../features/quiz/choice_round_screen.dart';
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

/// Route paths and names, so navigation never uses raw strings.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profiles = '/profiles';
  static const String home = '/home';
  static const String connection = '/connection';

  // Lesson-scoped mode screens, pushed from the home mode grid.
  static const String learn = '/learn/:lessonId';
  static const String listen = '/listen/:lessonId';
  static const String speak = '/speak/:lessonId';
  static const String quiz = '/quiz/:lessonId';

  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String profilesName = 'profiles';
  static const String homeName = 'home';
  static const String connectionName = 'connection';
  static const String learnName = 'learn';
  static const String listenName = 'listen';
  static const String speakName = 'speak';
  static const String quizName = 'quiz';
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
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.learn,
        name: AppRoutes.learnName,
        builder: (context, state) => LearnScreen(
          lessonId: _lessonId(state),
          languageCode: _languageCode(state),
        ),
      ),
      GoRoute(
        path: AppRoutes.listen,
        name: AppRoutes.listenName,
        builder: (context, state) => ChoiceRoundScreen(
          lessonId: _lessonId(state),
          mode: ChoiceMode.listen,
          languageCode: _languageCode(state),
        ),
      ),
      GoRoute(
        path: AppRoutes.speak,
        name: AppRoutes.speakName,
        builder: (context, state) => SpeakLessonScreen(
          lessonId: _lessonId(state),
          languageCode: _languageCode(state),
        ),
      ),
      GoRoute(
        path: AppRoutes.quiz,
        name: AppRoutes.quizName,
        builder: (context, state) => ChoiceRoundScreen(
          lessonId: _lessonId(state),
          mode: ChoiceMode.quiz,
          languageCode: _languageCode(state),
        ),
      ),
      GoRoute(
        // A developer aid, not part of the child-facing flow.
        path: AppRoutes.connection,
        name: AppRoutes.connectionName,
        builder: (context, state) => const ConnectionScreen(),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // The diagnostics screen is always reachable.
      if (location == AppRoutes.connection) return null;

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
