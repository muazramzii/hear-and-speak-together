import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/learner_profile.dart';
import '../../../models/progress.dart';
import '../../../models/user.dart';
import '../../../repositories/profile_repository.dart';
import '../../../repositories/students_repository.dart';
import '../../../routes/app_router.dart';
import '../design/parent_theme.dart';
import '../parent_providers.dart';
import '../widgets/parent_widgets.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Screen 1: the landing page. Child selector, overall progress, weekly
/// improvement, the flagship weakest-sound card, recommended practice, and
/// recent activity - in that priority order, per the Phase 4 brief.
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) => _ErrorState(
                      message: error is ApiException ? error.message : '$error',
                      onRetry: () => ref.invalidate(studentsProvider),
                    ),
                data: (students) {
                  if (students.isEmpty) {
                    return const ParentEmptyState(
                      icon: Icons.family_restroom_rounded,
                      message:
                          'No learners yet. Link a child from the Students tab to see their progress here.',
                    );
                  }

                  final selectedId = effectiveStudentId(ref, students);
                  final selected = students.firstWhere(
                    (s) => s.id == selectedId,
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(studentsProvider);
                      ref.invalidate(studentProgressProvider(selectedId!));
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _ChildSelector(
                          students: students,
                          selectedId: selectedId,
                        ),
                        const SizedBox(height: 20),
                        _DashboardBody(student: selected),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildSelector extends ConsumerWidget {
  const _ChildSelector({required this.students, required this.selectedId});

  final List<SupervisedStudent> students;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final student = students[index];
          final isSelected = student.id == selectedId;

          return Semantics(
            button: true,
            selected: isSelected,
            label: '${student.name}, level ${student.level}',
            child: GestureDetector(
              onTap:
                  () =>
                      ref.read(selectedStudentIdProvider.notifier).state =
                          student.id,
              child: Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? palette.indigoSoft : palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? palette.indigo : palette.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: palette.indigoSoft,
                      child: Text(
                        student.name.isEmpty
                            ? '?'
                            : student.name[0].toUpperCase(),
                        style: TextStyle(
                          color: palette.indigo,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            isSelected ? palette.indigo : palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.student});

  final SupervisedStudent student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(studentProgressProvider(student.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCard(student: student),
        const SizedBox(height: 20),
        reportAsync.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => _ErrorState(
                message: error is ApiException ? error.message : '$error',
                onRetry:
                    () => ref.invalidate(studentProgressProvider(student.id)),
              ),
          data: (report) => _ReportSections(report: report, student: student),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.student});

  final SupervisedStudent student;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final language = AppLanguage.fromCode(student.languageCode).label;

    return AnalyticsCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: palette.indigoSoft,
            child: Text(
              student.name.isEmpty ? '?' : student.name[0].toUpperCase(),
              style: TextStyle(
                color: palette.indigo,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$language · Level ${student.level}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.emeraldSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: palette.emerald,
                ),
                const SizedBox(width: 4),
                Text(
                  '${student.streakDays}d',
                  style: TextStyle(
                    color: palette.emerald,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSections extends ConsumerWidget {
  const _ReportSections({required this.report, required this.student});

  final ProgressReport report;
  final SupervisedStudent student;

  Future<void> _startPractice(
    BuildContext context,
    WidgetRef ref,
    WeakWord word,
  ) async {
    final owned = await ref.read(profilesProvider.future);
    LearnerProfile? profile;
    for (final candidate in owned) {
      if (candidate.id == student.id) {
        profile = candidate;
        break;
      }
    }

    if (profile == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Starting practice is only available on this learner\'s own device.',
            ),
          ),
        );
      }
      return;
    }

    ref.read(activeProfileProvider.notifier).state = profile;
    if (context.mounted) {
      context.go('/home/lesson/${word.lessonId}?lang=${student.languageCode}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final summary = report.summary;
    final comparison = report.weeklyComparison;
    final weakestSound =
        report.phonemes.weak.isEmpty ? null : report.phonemes.weak.first;
    final practiceRecommendation = report.recommendations.firstWhere(
      (item) => item.type == 'practise_words',
      orElse:
          () =>
              report.recommendations.isEmpty
                  ? const Recommendation(type: '', reason: '')
                  : report.recommendations.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overall Progress', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        AnalyticsCard(
          child: Row(
            children: [
              _CircularMetric(
                value: summary.averageScore,
                color: palette.indigo,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pronunciation',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      summary.averageScore == null
                          ? '—'
                          : '${summary.averageScore}%',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (comparison?.scoreChange != null) ...[
                      const SizedBox(height: 4),
                      _ChangeBadge(
                        value: comparison!.scoreChange!,
                        suffix: '% this week',
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                            label: 'Words mastered',
                            value: '${summary.wordsLearned}',
                          ),
                        ),
                        Expanded(
                          child: MetricTile(
                            label: 'Lessons completed',
                            value: '${summary.lessonsCompleted}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Weekly Improvement',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        LineChartCard(
          title: 'Average pronunciation score',
          trend: report.trend,
          weekdayLabels: _weekdayLabels,
        ),
        const SizedBox(height: 24),

        Text(
          'Most Difficult Sound',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (weakestSound == null)
          const AnalyticsCard(
            child: ParentEmptyState(
              icon: Icons.graphic_eq_rounded,
              message:
                  'Not enough attempts yet to identify a pattern in mispronounced sounds.',
            ),
          )
        else
          AnalyticsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhonemeBar(stat: weakestSound, isWeak: true),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Recommended practice: /${weakestSound.phoneme}/ sounds',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => context.goNamed(AppRoutes.parentProgressName),
                      child: const Text('View details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),

        if (practiceRecommendation.type.isNotEmpty) ...[
          Text(
            'Recommended Practice',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          RecommendationCard(
            recommendation: practiceRecommendation,
            onStartPractice: (word) => _startPractice(context, ref, word),
          ),
          const SizedBox(height: 24),
        ],

        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        AnalyticsCard(
          child:
              report.recentAttempts.isEmpty
                  ? const ParentEmptyState(
                    icon: Icons.history_rounded,
                    message: "Start your child's first practice.",
                  )
                  : Column(
                    children: [
                      for (
                        var i = 0;
                        i < report.recentAttempts.length;
                        i++
                      ) ...[
                        if (i > 0) const Divider(height: 1),
                        ActivityTile(attempt: report.recentAttempts[i]),
                      ],
                    ],
                  ),
        ),
      ],
    );
  }
}

class _CircularMetric extends StatelessWidget {
  const _CircularMetric({required this.value, required this.color});

  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (value ?? 0) / 100),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, fraction, _) {
        return SizedBox(
          height: 80,
          width: 80,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RingPainter(
                fraction: fraction,
                color: color,
                track: palette.surfaceAlt,
              ),
              child: Center(
                child: Text(
                  value == null ? '—' : '$value%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint =
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    final fillPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, 0, 6.28319, false, trackPaint);
    canvas.drawArc(
      rect,
      -1.5708,
      6.28319 * fraction.clamp(0.0, 1.0),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.value, required this.suffix});

  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final positive = value >= 0;
    final color = positive ? palette.emerald : palette.amber;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${positive ? '+' : ''}$value$suffix',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
