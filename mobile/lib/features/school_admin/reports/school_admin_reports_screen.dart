import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../repositories/school_analytics_repository.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/widgets/parent_widgets.dart';
import '../widgets/school_admin_skeleton.dart';
import '../widgets/school_trend_bar_chart.dart';

/// School-wide reports: overview cards, classroom performance, weak
/// phonemes, the 7-day trend, and completion rate - the five sections the
/// Phase 6 brief lists, each backed by its own `GET
/// /api/schools/analytics/*` endpoint (Task 7). Every number is already
/// computed server-side; this screen only presents it.
class SchoolAdminReportsScreen extends ConsumerWidget {
  const SchoolAdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final overviewAsync = ref.watch(schoolOverviewProvider);
    final classroomsAsync = ref.watch(classroomAnalyticsProvider);
    final phonemesAsync = ref.watch(weakestPhonemesProvider);
    final trendAsync = ref.watch(dailyTrendsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(schoolOverviewProvider);
                  ref.invalidate(classroomAnalyticsProvider);
                  ref.invalidate(weakestPhonemesProvider);
                  ref.invalidate(dailyTrendsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    overviewAsync.when(
                      loading: () =>
                          const SkeletonBox(height: 90, borderRadius: 16),
                      error: (error, _) => _ErrorState(
                        message:
                            error is ApiException ? error.message : '$error',
                        onRetry: () => ref.invalidate(schoolOverviewProvider),
                      ),
                      data: (overview) => AnalyticsCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: MetricTile(
                                label: 'Students',
                                value: '${overview.totalStudents}',
                              ),
                            ),
                            Expanded(
                              child: MetricTile(
                                label: 'Weekly avg',
                                value: overview.weeklyAverageScore == null
                                    ? '—'
                                    : '${overview.weeklyAverageScore}%',
                              ),
                            ),
                            Expanded(
                              child: MetricTile(
                                label: 'Monthly avg',
                                value: overview.monthlyAverageScore == null
                                    ? '—'
                                    : '${overview.monthlyAverageScore}%',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Classroom Performance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    classroomsAsync.when(
                      loading: () =>
                          const SkeletonBox(height: 140, borderRadius: 16),
                      error: (error, _) => _ErrorState(
                        message:
                            error is ApiException ? error.message : '$error',
                        onRetry: () =>
                            ref.invalidate(classroomAnalyticsProvider),
                      ),
                      data: (classrooms) {
                        if (classrooms.isEmpty) {
                          return const AnalyticsCard(
                            child: ParentEmptyState(
                              icon: Icons.meeting_room_rounded,
                              message: 'No active classrooms yet.',
                            ),
                          );
                        }
                        return AnalyticsCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < classrooms.length; i++) ...[
                                if (i > 0) const Divider(height: 24),
                                HeatBar(
                                  label: classrooms[i].classroomName,
                                  value: classrooms[i].averagePronunciationScore,
                                  subtitle:
                                      '${classrooms[i].teacherCount} teachers · '
                                      '${classrooms[i].studentCount} students',
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Weak Phonemes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    phonemesAsync.when(
                      loading: () =>
                          const SkeletonBox(height: 140, borderRadius: 16),
                      error: (error, _) => _ErrorState(
                        message:
                            error is ApiException ? error.message : '$error',
                        onRetry: () => ref.invalidate(weakestPhonemesProvider),
                      ),
                      data: (phonemes) {
                        if (phonemes.isEmpty) {
                          return const AnalyticsCard(
                            child: ParentEmptyState(
                              icon: Icons.graphic_eq_rounded,
                              message:
                                  'Not enough attempts yet to identify a '
                                  'pattern in mispronounced sounds.',
                            ),
                          );
                        }
                        return AnalyticsCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < phonemes.length; i++) ...[
                                if (i > 0) const Divider(height: 24),
                                HeatBar(
                                  label: '/${phonemes[i].phoneme}/',
                                  value: phonemes[i].errorRate,
                                  subtitle:
                                      '${phonemes[i].affectedStudents} students · '
                                      '${phonemes[i].totalOccurrences} errors',
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    trendAsync.when(
                      loading: () =>
                          const SkeletonBox(height: 180, borderRadius: 16),
                      error: (error, _) => _ErrorState(
                        message:
                            error is ApiException ? error.message : '$error',
                        onRetry: () => ref.invalidate(dailyTrendsProvider),
                      ),
                      data: (trend) => SchoolTrendBarChart(trend: trend),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Completion Rate',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    classroomsAsync.when(
                      loading: () =>
                          const SkeletonBox(height: 140, borderRadius: 16),
                      error: (error, _) => _ErrorState(
                        message:
                            error is ApiException ? error.message : '$error',
                        onRetry: () =>
                            ref.invalidate(classroomAnalyticsProvider),
                      ),
                      data: (classrooms) {
                        if (classrooms.isEmpty) {
                          return const AnalyticsCard(
                            child: ParentEmptyState(
                              icon: Icons.check_circle_outline_rounded,
                              message: 'No active classrooms yet.',
                            ),
                          );
                        }
                        return AnalyticsCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < classrooms.length; i++) ...[
                                if (i > 0) const Divider(height: 24),
                                HeatBar(
                                  label: classrooms[i].classroomName,
                                  value: classrooms[i].completionRate.round(),
                                  subtitle: 'Lesson completion',
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
