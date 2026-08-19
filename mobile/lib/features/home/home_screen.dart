import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../routes/app_router.dart';

/// The learner's home: greeting, points, and the four learning modes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(activeProfileProvider);

    if (profile == null) {
      // The router sends the user to the picker; this is just a safe frame.
      return const Scaffold(body: SizedBox.shrink());
    }

    final lessons = ref.watch(
      lessonsForLanguageProvider(profile.languageCode),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.homeGreeting(profile.name)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Chip(
              avatar: const Icon(
                Icons.star_rounded,
                color: AppColors.amber,
                size: 18,
              ),
              label: Text('${profile.points}'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.homeSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _StreakCard(streakDays: profile.streakDays),
                  const SizedBox(height: AppSpacing.lg),

                  // Only parents and teachers can monitor learners, so the
                  // entry point only exists for them.
                  if (ref.watch(currentUserProvider)?.role.supervisesStudents ??
                      false) ...[
                    const _SupervisorCard(),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  lessons.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _ErrorCard(
                      message: error is ApiException
                          ? error.message
                          : l10n.errorGeneric,
                      onRetry: () => ref.invalidate(
                        lessonsForLanguageProvider(profile.languageCode),
                      ),
                    ),
                    data: (items) => items.isEmpty
                        ? const _EmptyLessons()
                        : _ModeGrid(languageCode: profile.languageCode),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  TextButton.icon(
                    onPressed: () => context.goNamed(AppRoutes.profilesName),
                    icon: const Icon(Icons.switch_account_rounded),
                    label: Text(l10n.profileChooseTitle),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmSignOut(context, ref),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l10n.authSignOut),
                  ),
                ],
              ),
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
      builder: (dialogContext) => AlertDialog(
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

class _SupervisorCard extends StatelessWidget {
  const _SupervisorCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: AppColors.blueSoft,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: () => context.pushNamed(AppRoutes.studentsName),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: AppColors.blue, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.supervisorSectionTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.supervisorSectionBody,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          const Text('🐘', style: TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streakDays > 0
                      ? 'Keep up the great work!'
                      : 'Ready to start?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  streakDays > 0
                      ? '🔥 $streakDays day streak'
                      : 'Practise today to start a streak.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The four modes from the design: Learn, Listen, Speak (AI) and Quiz.
class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.languageCode});

  final String languageCode;

  /// Every mode goes through the lesson picker. Jumping straight into the
  /// first lesson made the rest of the content unreachable.
  void _pickLesson(BuildContext context, String? mode) {
    if (mode == null) {
      context.pushNamed(
        AppRoutes.learnLessonsName,
        queryParameters: {'lang': languageCode},
      );
      return;
    }
    context.pushNamed(
      AppRoutes.modeLessonsName,
      pathParameters: {'mode': mode},
      queryParameters: {'lang': languageCode},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.05,
      children: [
        _ModeCard(
          title: l10n.modeLearn,
          subtitle: l10n.modeLearnSubtitle,
          icon: Icons.menu_book_rounded,
          tint: AppColors.amberSoft,
          accent: AppColors.amber,
          onTap: () => _pickLesson(context, null),
        ),
        _ModeCard(
          title: l10n.modeListen,
          subtitle: l10n.modeListenSubtitle,
          icon: Icons.headphones_rounded,
          tint: AppColors.blueSoft,
          accent: AppColors.blue,
          onTap: () => _pickLesson(context, 'listen'),
        ),
        _ModeCard(
          title: l10n.modeSpeak,
          subtitle: l10n.modeSpeakSubtitle,
          icon: Icons.mic_rounded,
          tint: AppColors.greenSoft,
          accent: AppColors.green,
          onTap: () => _pickLesson(context, 'speak'),
        ),
        _ModeCard(
          title: l10n.modeQuiz,
          subtitle: l10n.modeQuizSubtitle,
          icon: Icons.help_outline_rounded,
          tint: AppColors.violetSoft,
          accent: AppColors.primary,
          onTap: () => _pickLesson(context, 'quiz'),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.sm + 4),
                ),
                child: Icon(icon, color: accent),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLessons extends StatelessWidget {
  const _EmptyLessons();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No lessons available for this language yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.actionTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
