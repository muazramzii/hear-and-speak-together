import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/parent_theme.dart';
import 'parent_preferences.dart';

/// The Parent/Teacher Intelligence Platform's own shell - Dashboard,
/// Students, Progress, Reports, Profile - entirely separate from the
/// child-facing `AppShell`. Wraps its content in Parent Mode's own theme
/// (light or dark, per [parentPreferencesProvider]) and text scale, so
/// none of the child app's playful styling leaks in and Parent Mode's own
/// accessibility settings apply only here.
class ParentShell extends ConsumerWidget {
  const ParentShell({super.key, required this.navigationShell});

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
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups_rounded),
                    label: 'Students',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights_rounded),
                    label: 'Progress',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.description_outlined),
                    selectedIcon: Icon(Icons.description_rounded),
                    label: 'Reports',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profile',
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
