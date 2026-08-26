import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/school.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/school_repository.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/parent_preferences.dart';
import '../../parent/widgets/parent_widgets.dart';
import '../widgets/school_admin_skeleton.dart';

/// School Admin settings: school profile and logo, dark mode, large
/// text, and about - reusing `parentPreferencesProvider` for the
/// accessibility settings rather than a parallel copy (Parent Mode's
/// dark-mode/text-scale state is not Parent-role-specific, just a
/// persisted app preference).
class SchoolAdminSettingsScreen extends ConsumerWidget {
  const SchoolAdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final schoolAsync = ref.watch(mySchoolProvider);
    final preferences = ref.watch(parentPreferencesProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('School'),
            schoolAsync.when(
              loading: () => const SkeletonBox(height: 140, borderRadius: 16),
              error: (error, _) => _ErrorCard(
                message: error is ApiException ? error.message : '$error',
                onRetry: () => ref.invalidate(mySchoolProvider),
              ),
              data: (school) => _SchoolProfileCard(school: school),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Accessibility'),
            AnalyticsCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Appearance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                      onSelectionChanged: (selection) => ref
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
                      onChanged: (value) => ref
                          .read(parentPreferencesProvider.notifier)
                          .setTextScale(value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Account'),
            AnalyticsCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: palette.indigoSoft,
                    child: Icon(Icons.person_rounded, color: palette.indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '—',
                          style: Theme.of(context).textTheme.titleMedium,
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

            _SectionLabel('About'),
            const AnalyticsCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text('Hear & Speak Together'),
                subtitle: Text('School Admin Workspace · Phase 6'),
              ),
            ),
            const SizedBox(height: 32),

            Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text(
                        'You will need to sign in again to manage your school.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
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

class _SchoolProfileCard extends ConsumerStatefulWidget {
  const _SchoolProfileCard({required this.school});

  final School? school;

  @override
  ConsumerState<_SchoolProfileCard> createState() =>
      _SchoolProfileCardState();
}

class _SchoolProfileCardState extends ConsumerState<_SchoolProfileCard> {
  bool _busy = false;

  Future<void> _createSchool(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Name your school'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'School name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(schoolRepositoryProvider).createSchool(name: name);
      ref.invalidate(mySchoolProvider);
    } on ApiException catch (error) {
      setState(() => _busy = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _renameSchool(BuildContext context, int id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename school'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == currentName) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(schoolRepositoryProvider)
          .updateSchoolName(id: id, name: name);
      ref.invalidate(mySchoolProvider);
    } on ApiException catch (error) {
      setState(() => _busy = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _pickLogo(BuildContext context, int id) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(schoolRepositoryProvider)
          .uploadLogo(id: id, logoFile: File(picked.path));
      ref.invalidate(mySchoolProvider);
    } on ApiException catch (error) {
      setState(() => _busy = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final school = widget.school;

    if (school == null) {
      return AnalyticsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ParentEmptyState(
              icon: Icons.apartment_rounded,
              message: "You haven't created your school yet.",
            ),
            FilledButton(
              onPressed: _busy ? null : () => _createSchool(context),
              child: Text(_busy ? 'Creating…' : 'Create school'),
            ),
          ],
        ),
      );
    }

    return AnalyticsCard(
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Change school logo',
            child: GestureDetector(
              onTap: _busy ? null : () => _pickLogo(context, school.id),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: palette.indigoSoft,
                backgroundImage: school.logo != null
                    ? NetworkImage(school.logo!)
                    : null,
                child: school.logo == null
                    ? Icon(Icons.apartment_rounded, color: palette.indigo)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Tap the logo to change it',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Rename',
            onPressed: _busy
                ? null
                : () => _renameSchool(context, school.id, school.name),
          ),
        ],
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      child: Column(
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
