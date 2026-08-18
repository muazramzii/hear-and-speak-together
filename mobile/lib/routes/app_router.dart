import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/health/connection_screen.dart';

/// Route names, kept in one place so navigation calls never use raw strings.
class AppRoutes {
  const AppRoutes._();

  static const String connection = '/';
}

/// The app's router.
///
/// Phase 1 has a single route. Auth-aware redirects and the student/parent
/// shells are layered on in later phases.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.connection,
    routes: [
      GoRoute(
        path: AppRoutes.connection,
        name: 'connection',
        builder: (context, state) => const ConnectionScreen(),
      ),
    ],
  );
});
