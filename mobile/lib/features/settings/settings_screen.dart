import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../routes/app_router.dart';

/// "Tetapan" - where the two languages are set.
///
/// The distinction is made explicit on screen, because they are genuinely
/// different settings: one changes the words the child is taught, the other
/// only changes the menus around them.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(activeProfileProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.navSettings),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Section(
                  title: l10n.settingsInterfaceLanguage,
                  help: l10n.settingsInterfaceLanguageHelp,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'ms', label: Text('Bahasa Melayu')),
                    ],
                    selected: {locale?.languageCode ?? 'en'},
                    showSelectedIcon: false,
                    onSelectionChanged:
                        (selection) => ref
                            .read(localeControllerProvider.notifier)
                            .setLocale(Locale(selection.first)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (profile != null)
                  _Section(
                    title: l10n.settingsPracticeLanguage,
                    help: l10n.settingsPracticeLanguageHelp,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.languageName,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        TextButton(
                          // Changed on the profile itself, since it belongs to
                          // the learner rather than the device.
                          onPressed:
                              () => context.goNamed(AppRoutes.profilesName),
                          child: Text(l10n.homeSwitchProfile),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),

                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.authSignOut),
                ),

                // Debug-build only: a developer needs a way to find the
                // Phase 2 AI validation sandbox without typing the route by
                // hand. Never compiled into a release build.
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton.icon(
                    onPressed:
                        () =>
                            context.goNamed(AppRoutes.pronunciationSandboxName),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Pronunciation Sandbox (dev)'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed:
                        () => context.goNamed(AppRoutes.componentShowcaseName),
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Component Showcase (dev)'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.authSignOutConfirmTitle),
            content: Text(l10n.authSignOutConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.authSignOut),
              ),
            ],
          ),
    );

    if (shouldSignOut ?? false) {
      ref.read(activeProfileProvider.notifier).state = null;
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.help,
    required this.child,
  });

  final String title;
  final String help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(help, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
