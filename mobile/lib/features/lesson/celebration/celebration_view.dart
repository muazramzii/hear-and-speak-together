import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../models/content.dart';
import '../../../repositories/content_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_widgets.dart';

/// The final step of the guided lesson flow: what was earned, and where to
/// go next. Points and badges come from the Quiz stage's own submission
/// (see `QuizFinishedCallback`) - nothing here talks to the network itself.
class CelebrationView extends ConsumerWidget {
  const CelebrationView({
    super.key,
    required this.lesson,
    required this.languageCode,
    required this.correct,
    required this.total,
    required this.pointsAwarded,
    required this.newAchievements,
  });

  final Lesson lesson;
  final String languageCode;
  final int correct;
  final int total;
  final int pointsAwarded;
  final List<String> newAchievements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lessonsAsync = ref.watch(lessonsForLanguageProvider(languageCode));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const Center(
                        child: Mascot(state: MascotState.celebrate, size: 120),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.celebrationTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.h1,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.celebrationLessonDone(lesson.title),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      HeroCard(
                        gradient: AppGradients.warm,
                        child: Column(
                          children: [
                            Text(
                              l10n.celebrationXpEarned,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ScoreCountUp(
                              value: pointsAwarded,
                              style: AppTypography.display.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (total > 0) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.choiceScoreLine(correct, total),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],

                      if (newAchievements.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l10n.celebrationNewBadge,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _BadgeRow(names: newAchievements),
                      ],

                      const SizedBox(height: AppSpacing.xl),
                      lessonsAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (lessons) {
                          final index = lessons.indexWhere(
                            (item) => item.id == lesson.id,
                          );
                          final next =
                              (index >= 0 && index + 1 < lessons.length)
                                  ? lessons[index + 1]
                                  : null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (next != null) ...[
                                _NextLessonPreview(lesson: next),
                                const SizedBox(height: AppSpacing.md),
                                AppPrimaryButton(
                                  label: l10n.celebrationNextLesson,
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed:
                                      () => context.pushReplacementNamed(
                                        AppRoutes.lessonSessionName,
                                        pathParameters: {
                                          'lessonId': '${next.id}',
                                        },
                                        queryParameters: {'lang': languageCode},
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ] else ...[
                                Text(
                                  l10n.celebrationAllDone,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              AppOutlineButton(
                                label: l10n.celebrationBackToJourney,
                                onPressed: () => context.pop(),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: CelebrationOverlay(active: true)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < names.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 150),
            curve: AppMotion.bouncy,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    names[i],
                    style: const TextStyle(
                      color: AppColors.textOnAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NextLessonPreview extends StatelessWidget {
  const _NextLessonPreview({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: AppColors.violetSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.celebrationNextLesson,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
                ),
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
