import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../design_system/design_system.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../models/progress.dart';
import '../../providers/choice_session_provider.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/progress_repository.dart';
import '../../routes/app_router.dart';

/// The "Learning Journey": picks which lesson a mode runs on, presented as a
/// visual path rather than a plain list. Before this existed every mode
/// opened the first lesson, so the rest of the seeded content was
/// unreachable - the picker itself is unchanged in that respect; only its
/// presentation is new for Phase 3.
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
    return _JourneyScaffold(
      languageCode: languageCode,
      onOpen: (context, lesson) => _open(context, lesson),
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
    return _JourneyScaffold(
      languageCode: languageCode,
      onOpen:
          (context, lesson) => context.pushNamed(
            AppRoutes.learnName,
            pathParameters: {'lessonId': '${lesson.id}'},
            queryParameters: {'lang': languageCode},
          ),
    );
  }
}

/// Shared between both entry points above - the only difference between
/// "pick a lesson for Learn" and "pick a lesson for Listen/Speak/Quiz" is
/// where tapping a node navigates to.
class _JourneyScaffold extends ConsumerWidget {
  const _JourneyScaffold({required this.languageCode, required this.onOpen});

  final String languageCode;
  final void Function(BuildContext context, Lesson lesson) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lessons = ref.watch(lessonsForLanguageProvider(languageCode));
    final profile = ref.watch(activeProfileProvider);

    // Progress is what turns the plain list into a path with lock/complete
    // states. Its absence (no profile yet, or the request failed) must not
    // block the picker itself - lessons simply render as all unlocked.
    final progressByLessonId =
        profile == null
            ? const <int, LessonProgress>{}
            : ref
                .watch(progressReportProvider(profile.id))
                .maybeWhen(
                  data:
                      (report) => {
                        for (final p in report.lessons) p.lessonId: p,
                      },
                  orElse: () => const <int, LessonProgress>{},
                );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.journeyTitle)),
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
                          : _JourneyPath(
                            lessons: items,
                            progressByLessonId: progressByLessonId,
                            onOpen: (lesson) => onOpen(context, lesson),
                          ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyPath extends StatelessWidget {
  const _JourneyPath({
    required this.lessons,
    required this.progressByLessonId,
    required this.onOpen,
  });

  final List<Lesson> lessons;
  final Map<int, LessonProgress> progressByLessonId;
  final void Function(Lesson lesson) onOpen;

  bool _isCompleted(Lesson lesson) =>
      (progressByLessonId[lesson.id]?.completionPercentage ?? 0) >= 100;

  bool _hasStarted(Lesson lesson) => progressByLessonId.containsKey(lesson.id);

  /// A lesson is locked only if the one before it is incomplete *and* this
  /// one has never been opened. The second half of that rule matters:
  /// nothing already reachable before this redesign should become
  /// unreachable now that a lock exists.
  bool _isLocked(int index) {
    if (index == 0) return false;
    final previous = lessons[index - 1];
    final current = lessons[index];
    return !_isCompleted(previous) && !_hasStarted(current);
  }

  /// The first lesson that is not yet complete - where the mascot stands to
  /// point the child toward what's next.
  int get _currentIndex {
    final index = lessons.indexWhere((lesson) => !_isCompleted(lesson));
    return index == -1 ? lessons.length - 1 : index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final alignRight = index.isOdd;
        final isCurrent = index == currentIndex;

        return _JourneyStep(
          lesson: lesson,
          index: index,
          isLast: index == lessons.length - 1,
          alignRight: alignRight,
          isCurrent: isCurrent,
          isCompleted: _isCompleted(lesson),
          isLocked: _isLocked(index),
          progress: progressByLessonId[lesson.id],
          onTap: _isLocked(index) ? null : () => onOpen(lesson),
        );
      },
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.lesson,
    required this.index,
    required this.isLast,
    required this.alignRight,
    required this.isCurrent,
    required this.isCompleted,
    required this.isLocked,
    required this.progress,
    required this.onTap,
  });

  final Lesson lesson;
  final int index;
  final bool isLast;
  final bool alignRight;
  final bool isCurrent;
  final bool isCompleted;
  final bool isLocked;
  final LessonProgress? progress;
  final VoidCallback? onTap;

  static const double _nodeSize = 88;

  Gradient get _gradient {
    if (isLocked) {
      return const LinearGradient(colors: [AppColors.border, AppColors.border]);
    }
    if (isCompleted) return AppGradients.success;
    return AppGradients.primary;
  }

  @override
  Widget build(BuildContext context) {
    final node = _JourneyNode(
      lesson: lesson,
      isLocked: isLocked,
      isCompleted: isCompleted,
      gradient: _gradient,
      progress: progress,
      onTap: onTap,
    );

    final column = Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isCurrent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!alignRight) ...[
                  const Mascot(mood: MascotMood.encouraging, size: 44),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: MascotBubble(text: context.l10n.journeyMascotPrompt),
                ),
                if (alignRight) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Mascot(mood: MascotMood.encouraging, size: 44),
                ],
              ],
            ),
          ),
        node,
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: _nodeSize + 40,
          child: Text(
            lesson.title,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          context.l10n.lessonsWordCount(lesson.wordCount),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: column,
      ),
    );
  }
}

class _JourneyNode extends StatelessWidget {
  const _JourneyNode({
    required this.lesson,
    required this.isLocked,
    required this.isCompleted,
    required this.gradient,
    required this.progress,
    required this.onTap,
  });

  final Lesson lesson;
  final bool isLocked;
  final bool isCompleted;
  final Gradient gradient;
  final LessonProgress? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = (progress?.completionPercentage ?? 0) / 100;
    final iconColor =
        isLocked
            ? AppColors.textSecondary
            : AppA11y.textColorFor(gradient.colors.last);

    return Semantics(
      button: true,
      enabled: !isLocked,
      label:
          isLocked
              ? '${lesson.title}. ${context.l10n.journeyLocked}. ${context.l10n.journeyLockedHint}'
              : lesson.title,
      child: GestureDetector(
        onTap: onTap,
        child: ProgressRing(
          value: isLocked ? 0 : fraction,
          size: 88,
          strokeWidth: 8,
          color: isCompleted ? AppColors.greenStrong : AppColors.amber,
          duration: AppMotion.slow,
          child: Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLocked
                  ? Icons.lock_rounded
                  : (isCompleted
                      ? Icons.check_rounded
                      : Icons.menu_book_rounded),
              color: iconColor,
              size: 28,
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
            AppSecondaryButton(
              label: context.l10n.actionTryAgain,
              onPressed: onRetry,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }
}
