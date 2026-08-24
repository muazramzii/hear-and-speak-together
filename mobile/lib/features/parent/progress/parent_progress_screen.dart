import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/progress.dart';
import '../../../repositories/attempts_repository.dart';
import '../../../repositories/students_repository.dart';
import '../../../routes/app_router.dart';
import '../design/parent_theme.dart';
import '../parent_providers.dart';
import '../widgets/parent_widgets.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Screen 3: detailed analytics in five tabs - Overall, Categories,
/// Pronunciation, Improvement, History.
class ParentProgressScreen extends ConsumerWidget {
  const ParentProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final studentsAsync = ref.watch(studentsProvider);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          title: const Text('Progress'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overall'),
              Tab(text: 'Categories'),
              Tab(text: 'Pronunciation'),
              Tab(text: 'Improvement'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: SafeArea(
          child: studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (students) {
              if (students.isEmpty) {
                return const ParentEmptyState(
                  icon: Icons.family_restroom_rounded,
                  message: 'Link a learner to see their progress.',
                );
              }

              final studentId = effectiveStudentId(ref, students)!;
              final reportAsync = ref.watch(studentProgressProvider(studentId));

              return reportAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) => Center(
                      child: Text(
                        error is ApiException ? error.message : '$error',
                      ),
                    ),
                data:
                    (report) => TabBarView(
                      children: [
                        _OverallTab(report: report),
                        _CategoriesTab(report: report),
                        _PronunciationTab(report: report),
                        _ImprovementTab(report: report),
                        _HistoryTab(studentId: studentId),
                      ],
                    ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OverallTab extends StatelessWidget {
  const _OverallTab({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            AnalyticsCard(
              child: MetricTile(
                label: 'Average score',
                value:
                    summary.averageScore == null
                        ? '—'
                        : '${summary.averageScore}%',
                icon: Icons.speed_rounded,
              ),
            ),
            AnalyticsCard(
              child: MetricTile(
                label: 'Lessons completed',
                value: '${summary.lessonsCompleted}',
                icon: Icons.menu_book_rounded,
              ),
            ),
            AnalyticsCard(
              child: MetricTile(
                label: 'Speaking attempts',
                value: '${summary.practiceSessions}',
                icon: Icons.mic_rounded,
              ),
            ),
            AnalyticsCard(
              child: MetricTile(
                label: 'Words practised',
                value: '${summary.wordsPractised}',
                icon: Icons.spellcheck_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LineChartCard(
          title: 'Weekly trend',
          trend: report.trend,
          weekdayLabels: _weekdayLabels,
        ),
      ],
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    if (report.categories.isEmpty) {
      return const ParentEmptyState(
        icon: Icons.category_rounded,
        message:
            "Start your child's first practice to see category breakdowns.",
      );
    }

    final sorted = [...report.categories]
      ..sort((a, b) => b.averageScore.compareTo(a.averageScore));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                HeatBar(
                  label: sorted[i].name,
                  value: sorted[i].averageScore,
                  subtitle: '${sorted[i].attempts} attempts',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PronunciationTab extends StatelessWidget {
  const _PronunciationTab({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final weak = report.phonemes.weak;
    final strong = report.phonemes.strong;

    if (weak.isEmpty && strong.isEmpty) {
      return const ParentEmptyState(
        icon: Icons.graphic_eq_rounded,
        message:
            'Not enough speaking attempts yet to analyse pronunciation patterns.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (weak.isNotEmpty) ...[
          Text(
            'Needs improvement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          AnalyticsCard(
            child: Column(
              children: [
                for (var i = 0; i < weak.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  PhonemeBar(stat: weak[i], isWeak: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (strong.isNotEmpty) ...[
          Text('Strong sounds', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          AnalyticsCard(
            child: Column(
              children: [
                for (var i = 0; i < strong.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  PhonemeBar(stat: strong[i], isWeak: false),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ImprovementTab extends StatelessWidget {
  const _ImprovementTab({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final comparison = report.weeklyComparison;
    if (comparison == null || comparison.thisWeek.attempts == 0) {
      return const ParentEmptyState(
        icon: Icons.trending_up_rounded,
        message: 'Practise this week to see how it compares with last week.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (comparison.scoreChange != null)
          AnalyticsCard(
            child: _ImprovementHeadline(
              value: comparison.scoreChange!,
              label: 'Score',
            ),
          ),
        const SizedBox(height: 12),
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComparisonRow(
                label: 'Attempts',
                thisWeek: comparison.thisWeek.attempts,
                lastWeek: comparison.lastWeek.attempts,
                change: comparison.attemptsChange,
              ),
              const Divider(height: 24),
              _ComparisonRow(
                label: 'Words completed',
                thisWeek: comparison.thisWeek.wordsCompleted,
                lastWeek: comparison.lastWeek.wordsCompleted,
                change: comparison.wordsCompletedChange,
              ),
              const Divider(height: 24),
              _ComparisonRow(
                label: 'Current streak',
                thisWeek: comparison.streakDays,
                lastWeek: null,
                change: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImprovementHeadline extends StatelessWidget {
  const _ImprovementHeadline({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;
    final positive = value >= 0;
    final color = positive ? palette.emerald : palette.amber;

    return Row(
      children: [
        Icon(
          positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: color,
          size: 32,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${positive ? '+' : ''}$value%',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(color: color),
            ),
            Text(
              positive
                  ? 'Great improvement this week!'
                  : '$label dipped slightly this week - steady practice will bring it back up.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.thisWeek,
    required this.lastWeek,
    required this.change,
  });

  final String label;
  final int thisWeek;
  final int? lastWeek;
  final int? change;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Text('$thisWeek', style: Theme.of(context).textTheme.titleMedium),
        if (lastWeek != null) ...[
          const SizedBox(width: 8),
          Text(
            'vs $lastWeek last week',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
        if (change != null) ...[
          const SizedBox(width: 8),
          Icon(
            change! >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 14,
            color: change! >= 0 ? palette.emerald : palette.amber,
          ),
        ],
      ],
    );
  }
}

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab({required this.studentId});

  final int studentId;

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  late AttemptFilter _filter = AttemptFilter(profileId: widget.studentId);

  @override
  Widget build(BuildContext context) {
    final attemptsAsync = ref.watch(attemptsProvider(_filter));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _ResultFilterChips(
                  value: _filter.result,
                  onChanged:
                      (result) => setState(
                        () =>
                            _filter = _filter.copyWith(result: result, page: 1),
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.date_range_rounded),
                tooltip: 'Filter by date',
                onPressed: () => _pickDateRange(context),
              ),
              if (_filter.dateFrom != null || _filter.dateTo != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear date filter',
                  onPressed:
                      () => setState(
                        () =>
                            _filter = _filter.copyWith(
                              clearDateFrom: true,
                              clearDateTo: true,
                              page: 1,
                            ),
                      ),
                ),
            ],
          ),
        ),
        Expanded(
          child: attemptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => Center(
                  child: Text(error is ApiException ? error.message : '$error'),
                ),
            data: (page) {
              if (page.results.isEmpty) {
                return const ParentEmptyState(
                  icon: Icons.history_rounded,
                  message: "Start your child's first practice.",
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: page.results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final attempt = page.results[index];
                  return AttemptRow(
                    attempt: attempt,
                    onTap:
                        () => context.pushNamed(
                          AppRoutes.parentAttemptDetailName,
                          pathParameters: {'attemptId': '${attempt.id}'},
                        ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange:
          _filter.dateFrom != null && _filter.dateTo != null
              ? DateTimeRange(start: _filter.dateFrom!, end: _filter.dateTo!)
              : null,
    );
    if (range != null) {
      setState(
        () =>
            _filter = _filter.copyWith(
              dateFrom: range.start,
              dateTo: range.end,
              page: 1,
            ),
      );
    }
  }
}

class _ResultFilterChips extends StatelessWidget {
  const _ResultFilterChips({required this.value, required this.onChanged});

  final AttemptResultFilter value;
  final void Function(AttemptResultFilter) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in AttemptResultFilter.values) ...[
            ChoiceChip(
              label: Text(switch (option) {
                AttemptResultFilter.any => 'All',
                AttemptResultFilter.pass => 'Passed',
                AttemptResultFilter.fail => 'Needs work',
              }),
              selected: value == option,
              onSelected: (_) => onChanged(option),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
