import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/health/connection_screen.dart';
import '../features/home/home_screen.dart';
import '../providers/auth_provider.dart';

/// Route paths and names, so navigation never uses raw strings.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String connection = '/connection';

  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String homeName = 'home';
  static const String connectionName = 'connection';
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
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomeScreen(),
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
        return AppRoutes.home;
      }

      return null;
    },
  );
});
