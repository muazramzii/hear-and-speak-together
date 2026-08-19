import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../providers/choice_session_provider.dart';
import '../../repositories/content_repository.dart';
import '../../routes/app_router.dart';

/// Picks which lesson a mode runs on.
///
/// Before this existed every mode opened the first lesson, so the rest of the
/// seeded content was unreachable.
class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({
    super.key,
    required this.mode,
    required this.languageCode,
  });

  /// Which mode the chosen lesson opens in. Null means Speak.
  final ChoiceMode? mode;
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lessons = ref.watch(lessonsForLanguageProvider(languageCode));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lessonsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: lessons.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => _ErrorState(
                    message:
                        error is ApiException
                            ? error.message
                            : l10n.errorGeneric,
                    onRetry:
                        () => ref.invalidate(
                          lessonsForLanguageProvider(languageCode),
                        ),
                  ),
              data:
                  (items) =>
                      items.isEmpty
                          ? Center(child: Text(l10n.errorNoLessons))
                          : ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              Text(
                                l10n.lessonsChoose,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              for (final lesson in items)
                                _LessonTile(
                                  lesson: lesson,
                                  onTap: () => _open(context, lesson),
                                ),
                            ],
                          ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Lesson lesson) {
    final name = switch (mode) {
      ChoiceMode.listen => AppRoutes.listenName,
      ChoiceMode.quiz => AppRoutes.quizName,
      null => AppRoutes.speakName,
    };

    context.pushNamed(
      name,
      pathParameters: {'lessonId': '${lesson.id}'},
      queryParameters: {'lang': languageCode},
    );
  }
}

/// Learn mode reuses the same picker but opens the Learn route.
class LearnLessonListScreen extends ConsumerWidget {
  const LearnLessonListScreen({super.key, required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lessons = ref.watch(lessonsForLanguageProvider(languageCode));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lessonsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: lessons.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => _ErrorState(
                    message:
                        error is ApiException
                            ? error.message
                            : l10n.errorGeneric,
                    onRetry:
                        () => ref.invalidate(
                          lessonsForLanguageProvider(languageCode),
                        ),
                  ),
              data:
                  (items) =>
                      items.isEmpty
                          ? Center(child: Text(l10n.errorNoLessons))
                          : ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              for (final lesson in items)
                                _LessonTile(
                                  lesson: lesson,
                                  onTap:
                                      () => context.pushNamed(
                                        AppRoutes.learnName,
                                        pathParameters: {
                                          'lessonId': '${lesson.id}',
                                        },
                                        queryParameters: {'lang': languageCode},
                                      ),
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

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.onTap});

  final Lesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: AppColors.violetSoft,
                    borderRadius: BorderRadius.circular(AppSpacing.sm + 4),
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
                        lesson.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.l10n.lessonsWordCount(lesson.wordCount),
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
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
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
