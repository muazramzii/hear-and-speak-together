import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../models/progress.dart';
import '../../providers/choice_session_provider.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/progress_repository.dart';
import '../../routes/app_router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_widgets.dart';

/// The "Learning Journey": picks which lesson a mode runs on, presented as
/// a curved visual progression map rather than a plain list. Before this
/// existed every mode opened the first lesson, so the rest of the seeded
/// content was unreachable - the picker itself is unchanged in that
/// respect; only its presentation is new for Phase 3.
class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({
    super.key,
    required this.mode,
    required this.languageCode,
  });

  /// Kept for callers built against the old four-mode picker; every mode now
  /// opens the same guided lesson experience (Stage 3), which walks Learn,
  /// Listen, Speak and Quiz in one sequence, so this no longer changes where
  /// tapping a lesson leads.
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
    context.pushNamed(
      AppRoutes.lessonSessionName,
      pathParameters: {'lessonId': '${lesson.id}'},
      queryParameters: {'lang': languageCode},
    );
  }
}

/// Kept for the same reason as `LessonListScreen.mode` above - opens the
/// same guided lesson experience as every other entry point now that a
/// lesson is a full Intro-to-Celebration sequence, not a single mode.
class LearnLessonListScreen extends ConsumerWidget {
  const LearnLessonListScreen({super.key, required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _JourneyScaffold(
      languageCode: languageCode,
      onOpen:
          (context, lesson) => context.pushNamed(
            AppRoutes.lessonSessionName,
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

/// A curved progression map: every lesson is a node on a smooth path that
/// winds left and right down the screen, coloured up to the last completed
/// lesson so "how far you've come" is visible at a glance, not just "which
/// one is next".
class _JourneyPath extends StatelessWidget {
  const _JourneyPath({
    required this.lessons,
    required this.progressByLessonId,
    required this.onOpen,
  });

  final List<Lesson> lessons;
  final Map<int, LessonProgress> progressByLessonId;
  final void Function(Lesson lesson) onOpen;

  static const double _stepHeight = 152;
  static const double _nodeSize = 88;
  static const double _horizontalInset = 40;

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

  Offset _centerFor(int index, double width) {
    final dx =
        index.isOdd
            ? width - _horizontalInset - _nodeSize / 2
            : _horizontalInset + _nodeSize / 2;
    return Offset(dx, index * _stepHeight + _nodeSize / 2);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final totalHeight = lessons.length * _stepHeight;
          final centers = [
            for (var i = 0; i < lessons.length; i++) _centerFor(i, width),
          ];

          return SizedBox(
            width: width,
            height: totalHeight,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(width, totalHeight),
                  painter: _JourneyCurvePainter(
                    centers: centers,
                    isSegmentTravelled: [
                      for (var i = 0; i < lessons.length - 1; i++)
                        _isCompleted(lessons[i]),
                    ],
                  ),
                ),
                for (var i = 0; i < lessons.length; i++)
                  Positioned(
                    top: i * _stepHeight,
                    left: 0,
                    right: 0,
                    height: _stepHeight,
                    child: _JourneyStep(
                      lesson: lessons[i],
                      alignRight: i.isOdd,
                      isCurrent: i == currentIndex,
                      isCompleted: _isCompleted(lessons[i]),
                      isLocked: _isLocked(i),
                      progress: progressByLessonId[lessons[i].id],
                      nodeSize: _nodeSize,
                      horizontalInset: _horizontalInset,
                      onTap: _isLocked(i) ? null : () => onOpen(lessons[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Draws the winding line behind the nodes - a smooth curve through each
/// node's centre (a quadratic bezier per segment, not a sharp zig-zag), in
/// two colours: `successStrong` for the stretch already completed, `border`
/// for what's still ahead.
class _JourneyCurvePainter extends CustomPainter {
  const _JourneyCurvePainter({
    required this.centers,
    required this.isSegmentTravelled,
  });

  final List<Offset> centers;
  final List<bool> isSegmentTravelled;

  @override
  void paint(Canvas canvas, Size size) {
    final travelledPaint =
        Paint()
          ..color = AppColors.successStrong
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
    final aheadPaint =
        Paint()
          ..color = AppColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;

    for (var i = 0; i < centers.length - 1; i++) {
      final start = centers[i];
      final end = centers[i + 1];
      final control = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

      final path =
          Path()
            ..moveTo(start.dx, start.dy)
            ..quadraticBezierTo(control.dx, start.dy, control.dx, control.dy)
            ..quadraticBezierTo(control.dx, end.dy, end.dx, end.dy);

      canvas.drawPath(
        path,
        isSegmentTravelled[i] ? travelledPaint : aheadPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_JourneyCurvePainter oldDelegate) =>
      oldDelegate.centers != centers ||
      oldDelegate.isSegmentTravelled != isSegmentTravelled;
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.lesson,
    required this.alignRight,
    required this.isCurrent,
    required this.isCompleted,
    required this.isLocked,
    required this.progress,
    required this.nodeSize,
    required this.horizontalInset,
    required this.onTap,
  });

  final Lesson lesson;
  final bool alignRight;
  final bool isCurrent;
  final bool isCompleted;
  final bool isLocked;
  final LessonProgress? progress;
  final double nodeSize;
  final double horizontalInset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final node = Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _JourneyNode(
          lesson: lesson,
          isLocked: isLocked,
          isCompleted: isCompleted,
          progress: progress,
          size: nodeSize,
          onTap: onTap,
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: nodeSize + 48,
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

    final mascotBubble =
        isCurrent
            ? Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: alignRight ? 0 : AppSpacing.sm,
                  right: alignRight ? AppSpacing.sm : 0,
                  top: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment:
                      alignRight
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Mascot(state: MascotState.encourage, size: 40),
                    const SizedBox(height: AppSpacing.xs),
                    MascotSpeechBubble(text: context.l10n.journeyMascotPrompt),
                  ],
                ),
              ),
            )
            : const Spacer();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalInset - AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignRight ? [mascotBubble, node] : [node, mascotBubble],
      ),
    );
  }
}

class _JourneyNode extends StatelessWidget {
  const _JourneyNode({
    required this.lesson,
    required this.isLocked,
    required this.isCompleted,
    required this.progress,
    required this.size,
    required this.onTap,
  });

  final Lesson lesson;
  final bool isLocked;
  final bool isCompleted;
  final LessonProgress? progress;
  final double size;
  final VoidCallback? onTap;

  Gradient get _gradient {
    if (isLocked) {
      return const LinearGradient(colors: [AppColors.border, AppColors.border]);
    }
    if (isCompleted) return AppGradients.success;
    return AppGradients.primary;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (progress?.completionPercentage ?? 0) / 100;
    final gradient = _gradient;
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
        child: CircularScore(
          value: isLocked ? 0 : fraction,
          size: size,
          strokeWidth: 8,
          color: isCompleted ? AppColors.successStrong : AppColors.accent,
          duration: AppMotion.slow,
          child: Container(
            height: size * 0.72,
            width: size * 0.72,
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
              size: size * 0.32,
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
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppOutlineButton(
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
