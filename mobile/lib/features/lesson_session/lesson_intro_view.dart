import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../repositories/content_repository.dart';
import '../../theme/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/word_visual.dart';

/// Screen 1 of the guided lesson flow: a single landing moment before any
/// activity starts, built around the lesson's first word as a hero preview -
/// not the full word list, which Learn covers next.
class LessonIntroView extends ConsumerWidget {
  const LessonIntroView({
    super.key,
    required this.lesson,
    required this.languageCode,
    required this.onStart,
  });

  final Lesson lesson;
  final String languageCode;
  final VoidCallback onStart;

  /// A short, dynamic range rather than a fixed "1-2 min" for every lesson -
  /// about one minute per five words, floored at one minute.
  (int, int) get _estimatedMinutes {
    final min = math.max(1, (lesson.wordCount / 5).ceil());
    return (min, min + 1);
  }

  String _difficultyLabel(BuildContext context) => switch (lesson.difficulty) {
    'INTERMEDIATE' => context.l10n.difficultyIntermediate,
    _ => context.l10n.difficultyBeginner,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final heroWord = lesson.words.first;
    final (minMinutes, maxMinutes) = _estimatedMinutes;

    final categoryName = ref
        .watch(lessonCategoryNamesProvider(languageCode))
        .maybeWhen(data: (map) => map[lesson.id], orElse: () => null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroCard(
                    gradient: AppGradients.primary,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        Container(
                          height: 160,
                          width: 160,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: WordVisual(word: heroWord, size: 96),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          heroWord.text.isEmpty
                              ? heroWord.text
                              : heroWord.text[0].toUpperCase() +
                                  heroWord.text.substring(1),
                          textAlign: TextAlign.center,
                          style: AppTypography.h1.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (categoryName != null)
                        _InfoChip(
                          icon: Icons.category_rounded,
                          label: categoryName,
                        ),
                      _InfoChip(
                        icon: Icons.trending_up_rounded,
                        label: _difficultyLabel(context),
                      ),
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        label: l10n.lessonIntroMinutesRange(
                          minMinutes,
                          maxMinutes,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Mascot(state: MascotState.encourage, size: 72),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: MascotSpeechBubble(
                      text: l10n.lessonIntroLetsLearn(heroWord.text),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppPrimaryButton(
                    label: l10n.lessonIntroStart,
                    icon: Icons.play_arrow_rounded,
                    onPressed: onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.violetSoft,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
