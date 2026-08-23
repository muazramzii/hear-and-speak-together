import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../design_system/design_system.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../routes/app_router.dart';

/// The learner's home: a hero greeting with the mascot, streak progress, and
/// the four learning modes - visually first, per the Phase 3 brief, rather
/// than a settings-style list of links.
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

    final lessons = ref.watch(lessonsForLanguageProvider(profile.languageCode));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroGreetingCard(
                    name: profile.name,
                    points: profile.points,
                    streakDays: profile.streakDays,
                    greeting: l10n.homeGreeting(profile.name),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Only parents and teachers can monitor learners, so the
                  // entry point only exists for them.
                  if (ref.watch(currentUserProvider)?.role.supervisesStudents ??
                      false) ...[
                    const _SupervisorCard(),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  lessons.when(
                    loading:
                        () => const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    error:
                        (error, _) => _ErrorCard(
                          message:
                              error is ApiException
                                  ? error.message
                                  : l10n.errorGeneric,
                          onRetry:
                              () => ref.invalidate(
                                lessonsForLanguageProvider(
                                  profile.languageCode,
                                ),
                              ),
                        ),
                    data:
                        (items) =>
                            items.isEmpty
                                ? const _EmptyLessons()
                                : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AppPrimaryButton(
                                      label: l10n.homeContinueLearning,
                                      icon: Icons.map_rounded,
                                      onPressed:
                                          () => context.pushNamed(
                                            AppRoutes.learnLessonsName,
                                            queryParameters: {
                                              'lang': profile.languageCode,
                                            },
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    _ModeGrid(
                                      languageCode: profile.languageCode,
                                    ),
                                  ],
                                ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed:
                            () => context.goNamed(AppRoutes.profilesName),
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

/// The hero card: mascot, greeting, points, and a streak bar. Replaces the
/// old plain `_StreakCard` - and, along the way, wires the streak copy
/// through `l10n` properly. The previous version had matching ARB entries
/// (`homeKeepGoing`, `homeReadyToStart`, `homeStartStreak`) that were never
/// actually used; the English literals it printed instead meant a Malay
/// learner saw English text on this one card, silently.
class _HeroGreetingCard extends StatelessWidget {
  const _HeroGreetingCard({
    required this.name,
    required this.points,
    required this.streakDays,
    required this.greeting,
  });

  final String name;
  final int points;
  final int streakDays;
  final String greeting;

  /// A streak "fills up" toward the next 7-day milestone - purely a visual
  /// device for the XP bar, not a value the backend tracks.
  double get _streakFraction => (streakDays % 7) / 7;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasStreak = streakDays > 0;

    return AppGradientCard(
      gradient: AppGradients.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTypography.celebration.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      hasStreak ? l10n.homeKeepGoing : l10n.homeReadyToStart,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Mascot(
                mood: hasStreak ? MascotMood.happy : MascotMood.idle,
                size: 72,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  hasStreak
                      ? l10n.homeStreakDays(streakDays)
                      : l10n.homeStartStreak,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$points',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (hasStreak) ...[
            const SizedBox(height: AppSpacing.sm),
            XpBar(
              value: _streakFraction == 0 ? 1.0 : _streakFraction,
              color: Colors.white,
              trackColor: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupervisorCard extends StatelessWidget {
  const _SupervisorCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      color: AppColors.blueSoft,
      onTap: () => context.pushNamed(AppRoutes.studentsName),
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
          gradient: AppGradients.warm,
          onTap: () => _pickLesson(context, null),
        ),
        _ModeCard(
          title: l10n.modeListen,
          subtitle: l10n.modeListenSubtitle,
          icon: Icons.headphones_rounded,
          gradient: AppGradients.sky,
          onTap: () => _pickLesson(context, 'listen'),
        ),
        _ModeCard(
          title: l10n.modeSpeak,
          subtitle: l10n.modeSpeakSubtitle,
          icon: Icons.mic_rounded,
          gradient: AppGradients.success,
          onTap: () => _pickLesson(context, 'speak'),
        ),
        _ModeCard(
          title: l10n.modeQuiz,
          subtitle: l10n.modeQuizSubtitle,
          icon: Icons.help_outline_rounded,
          gradient: AppGradients.primary,
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
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              color: AppA11y.textColorFor(gradient.colors.last),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyLessons extends StatelessWidget {
  const _EmptyLessons();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        context.l10n.errorNoLessons,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
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
    return AppCard(
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: context.l10n.actionTryAgain,
            onPressed: onRetry,
            expand: false,
          ),
        ],
      ),
    );
  }
}
