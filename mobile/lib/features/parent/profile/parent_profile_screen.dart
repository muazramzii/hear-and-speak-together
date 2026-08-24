import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../repositories/students_repository.dart';
import '../../../routes/app_router.dart';
import '../design/parent_theme.dart';
import '../parent_preferences.dart';
import '../widgets/parent_widgets.dart';

/// A local-only "notifications enabled" toggle. Kept separate from
/// [parentPreferencesProvider] because it is not persisted anywhere or
/// backed by a real push-notification service - there is none in this
/// project - it exists purely as the UI switch the brief asks for.
final _notificationsEnabledProvider = StateProvider<bool>((ref) => true);

/// Screen 6: parent profile - language, notifications, accessibility,
/// linked children, about, and privacy. Deliberately simple: this is a
/// settings list, not another analytics surface.
class ParentProfileScreen extends ConsumerWidget {
  const ParentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final user = ref.watch(currentUserProvider);
    final preferences = ref.watch(parentPreferencesProvider);
    final locale = ref.watch(localeControllerProvider);
    final notificationsEnabled = ref.watch(_notificationsEnabledProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnalyticsCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: palette.indigoSoft,
                    child: Icon(Icons.person_rounded, color: palette.indigo),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '—',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Language'),
            AnalyticsCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final option in const [null, Locale('en'), Locale('ms')])
                    RadioListTile<Locale?>(
                      value: option,
                      groupValue: locale,
                      onChanged:
                          (value) => ref
                              .read(localeControllerProvider.notifier)
                              .setLocale(value),
                      title: Text(switch (option?.languageCode) {
                        'en' => 'English',
                        'ms' => 'Bahasa Melayu',
                        _ => 'Follow device',
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Notifications'),
            AnalyticsCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                value: notificationsEnabled,
                onChanged:
                    (value) =>
                        ref.read(_notificationsEnabledProvider.notifier).state =
                            value,
                title: const Text('Weekly progress summaries'),
                subtitle: const Text(
                  'A reminder when a report is ready to review.',
                ),
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Accessibility'),
            AnalyticsCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Appearance'),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                      ],
                      selected: {preferences.themeMode},
                      onSelectionChanged:
                          (selection) => ref
                              .read(parentPreferencesProvider.notifier)
                              .setThemeMode(selection.first),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Text size'),
                    subtitle: Slider(
                      value: preferences.textScale,
                      min: 1.0,
                      max: 1.4,
                      divisions: 4,
                      label: '${(preferences.textScale * 100).round()}%',
                      onChanged:
                          (value) => ref
                              .read(parentPreferencesProvider.notifier)
                              .setTextScale(value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Children'),
            AnalyticsCard(
              padding: EdgeInsets.zero,
              child: studentsAsync.when(
                loading:
                    () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                error:
                    (_, _) => const ListTile(
                      title: Text('Could not load linked learners.'),
                    ),
                data:
                    (students) => Column(
                      children: [
                        if (students.isEmpty)
                          const ListTile(title: Text('No learners linked yet.'))
                        else
                          for (final student in students)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: palette.indigoSoft,
                                child: Text(
                                  student.name.isEmpty
                                      ? '?'
                                      : student.name[0].toUpperCase(),
                                  style: TextStyle(color: palette.indigo),
                                ),
                              ),
                              title: Text(student.name),
                              subtitle: Text('Level ${student.level}'),
                            ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.add_rounded),
                          title: const Text('Manage learners'),
                          onTap:
                              () =>
                                  context.goNamed(AppRoutes.parentStudentsName),
                        ),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('About'),
            const AnalyticsCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: Text('Hear & Speak Together'),
                    subtitle: Text('Parent & Teacher Intelligence Platform'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Privacy'),
            AnalyticsCard(
              child: Text(
                'As a parent or teacher, you can see the pronunciation attempts, '
                'scores, and lesson progress of learners who have shared their '
                'code with you. Recordings are not stored unless the family has '
                'enabled it, and a learner can revoke your access at any time '
                'from their own device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 32),

            Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (dialogContext) => AlertDialog(
                          title: const Text('Sign out?'),
                          content: const Text(
                            'You will need to sign in again to view learner progress.',
                          ),
                          actions: [
                            TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                              child: const Text('Sign out'),
                            ),
                          ],
                        ),
                  );
                  if (confirmed ?? false) {
                    await ref.read(authControllerProvider.notifier).logout();
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
