import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/school_analytics.dart';
import '../../../repositories/school_analytics_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../routes/app_router.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/widgets/parent_widgets.dart';
import '../widgets/school_admin_skeleton.dart';

/// The School Admin landing page: school identity, headline totals,
/// weekly/monthly pronunciation averages, the top 5 weakest sounds
/// school-wide, and recent activity.
///
/// "Recent activity" has no dedicated events feed at the API layer - this
/// task must not modify the backend, and Task 7's analytics API only
/// exposes aggregates (overview/classrooms/phonemes/trends), not a list
/// of individual attempts. It is built from the 7-day trend instead,
/// most recently active day first - an honest use of the data that
/// actually exists, not a fabricated activity log.
class SchoolAdminDashboardScreen extends ConsumerWidget {
  const SchoolAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final schoolAsync = ref.watch(mySchoolProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: schoolAsync.when(
                loading: () => const SchoolAdminDashboardSkeleton(),
                error: (error, _) => _ErrorState(
                  message: error is ApiException ? error.message : '$error',
                  onRetry: () => ref.invalidate(mySchoolProvider),
                ),
                data: (school) {
                  if (school == null) {
                    return _NoSchoolYetState(
                      onSetUp: () =>
                          context.goNamed(AppRoutes.schoolAdminSettingsName),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      // Includes mySchoolProvider itself - a rename made
                      // in Settings should show up here on the next pull,
                      // not just the score/phoneme/trend figures.
                      ref.invalidate(mySchoolProvider);
                      ref.invalidate(schoolOverviewProvider);
                      ref.invalidate(weakestPhonemesProvider);
                      ref.invalidate(dailyTrendsProvider);
                    },
                    child: _DashboardBody(schoolName: school.name),
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

class _NoSchoolYetState extends StatelessWidget {
  const _NoSchoolYetState({required this.onSetUp});

  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ParentEmptyState(
              icon: Icons.apartment_rounded,
              message:
                  'Set up your school in Settings to start inviting '
                  'teachers and tracking progress.',
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: onSetUp, child: const Text('Go to Settings')),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.schoolName});

  final String schoolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(schoolOverviewProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(schoolName, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        overviewAsync.when(
          loading: () => const SchoolAdminDashboardSkeleton(),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : '$error',
            onRetry: () => ref.invalidate(schoolOverviewProvider),
          ),
          data: (overview) => _OverviewSections(overview: overview),
        ),
      ],
    );
  }
}

class _OverviewSections extends ConsumerWidget {
  const _OverviewSections({required this.overview});

  final SchoolOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phonemesAsync = ref.watch(weakestPhonemesProvider);
    final trendAsync = ref.watch(dailyTrendsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnalyticsCard(
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Students',
                  value: '${overview.totalStudents}',
                  icon: Icons.groups_rounded,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Teachers',
                  value: '${overview.totalTeachers}',
                  icon: Icons.school_rounded,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Classrooms',
                  value: '${overview.totalClassrooms}',
                  icon: Icons.meeting_room_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnalyticsCard(
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Weekly average',
                  value: overview.weeklyAverageScore == null
                      ? '—'
                      : '${overview.weeklyAverageScore}%',
                  icon: Icons.trending_up_rounded,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Monthly average',
                  value: overview.monthlyAverageScore == null
                      ? '—'
                      : '${overview.monthlyAverageScore}%',
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Active today',
                  value: '${overview.activeStudentsToday}',
                  icon: Icons.bolt_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Weakest Sounds School-Wide',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        phonemesAsync.when(
          loading: () => const SkeletonBox(height: 120, borderRadius: 16),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : '$error',
            onRetry: () => ref.invalidate(weakestPhonemesProvider),
          ),
          data: (phonemes) {
            final top5 = phonemes.take(5).toList();
            if (top5.isEmpty) {
              return const AnalyticsCard(
                child: ParentEmptyState(
                  icon: Icons.graphic_eq_rounded,
                  message:
                      'Not enough attempts yet to identify a pattern in '
                      'mispronounced sounds across the school.',
                ),
              );
            }
            return AnalyticsCard(
              child: Column(
                children: [
                  for (var i = 0; i < top5.length; i++) ...[
                    if (i > 0) const Divider(height: 24),
                    HeatBar(
                      label: '/${top5[i].phoneme}/',
                      value: top5[i].errorRate,
                      subtitle:
                          '${top5[i].affectedStudents} students affected · '
                          '${top5[i].totalOccurrences} errors',
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        trendAsync.when(
          loading: () => const SkeletonBox(height: 120, borderRadius: 16),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : '$error',
            onRetry: () => ref.invalidate(dailyTrendsProvider),
          ),
          data: (trend) {
            final active = trend
                .where((day) => day.attempts > 0)
                .toList()
                .reversed
                .toList();
            if (active.isEmpty) {
              return const AnalyticsCard(
                child: ParentEmptyState(
                  icon: Icons.history_rounded,
                  message: 'No practice recorded across the school this week.',
                ),
              );
            }
            return AnalyticsCard(
              child: Column(
                children: [
                  for (var i = 0; i < active.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ActivityDayRow(day: active[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActivityDayRow extends StatelessWidget {
  const _ActivityDayRow({required this.day});

  final DailyTrend day;

  String get _label {
    final today = DateTime.now();
    final isToday =
        day.date.year == today.year &&
        day.date.month == today.month &&
        day.date.day == today.day;
    if (isToday) return 'Today';
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday =
        day.date.year == yesterday.year &&
        day.date.month == yesterday.month &&
        day.date.day == yesterday.day;
    if (isYesterday) return 'Yesterday';
    return '${day.date.month}/${day.date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(_label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(
            '${day.attempts} attempts',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            '${day.averageScore}%',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: palette.indigo),
          ),
        ],
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
