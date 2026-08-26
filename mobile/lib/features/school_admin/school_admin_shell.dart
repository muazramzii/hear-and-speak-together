import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../parent/design/parent_theme.dart';
import '../parent/parent_preferences.dart';

/// The School Admin workspace's own shell - Dashboard, Teachers,
/// Classrooms, Reports, Settings - reached by any account with
/// `UserRole.schoolAdmin` (see the router's `redirect`), and entirely
/// separate from the child-facing `AppShell`.
///
/// Deliberately reuses Parent Mode's theme and accessibility preferences
/// (`ParentTheme`/`parentPreferencesProvider`) rather than a parallel
/// copy: dark mode, text scale, the indigo/emerald palette, and the
/// Material 3 card language are exactly what a "professional dashboard"
/// distinct from Child Mode already looks like in this app, and a School
/// Admin is not a different persona from a Parent/Teacher in any way
/// that would call for its own design system - only for its own
/// navigation and screens.
class SchoolAdminShell extends ConsumerWidget {
  const SchoolAdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(parentPreferencesProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    final isDark = switch (preferences.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    return Theme(
      data: isDark ? ParentTheme.dark : ParentTheme.light,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(preferences.textScale)),
        child: Builder(
          builder: (context) {
            final palette = context.parentColors;

            return Scaffold(
              backgroundColor: palette.background,
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected:
                    (index) => navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school_rounded),
                    label: 'Teachers',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.meeting_room_outlined),
                    selectedIcon: Icon(Icons.meeting_room_rounded),
                    label: 'Classrooms',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.description_outlined),
                    selectedIcon: Icon(Icons.description_rounded),
                    label: 'Reports',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
