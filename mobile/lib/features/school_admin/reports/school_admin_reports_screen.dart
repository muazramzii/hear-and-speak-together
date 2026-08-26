import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/report_filter.dart';
import '../../../models/school_analytics.dart';
import '../../../repositories/classroom_repository.dart';
import '../../../repositories/school_analytics_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../parent/design/parent_theme.dart';
import '../../parent/widgets/parent_widgets.dart';
import '../widgets/school_admin_skeleton.dart';
import '../widgets/school_trend_bar_chart.dart';
import 'classroom_pdf_report_builder.dart';
import 'report_preview_screen.dart';
import 'school_pdf_report_builder.dart';

/// School-wide reports: overview cards, classroom performance, weak
/// phonemes, a filterable trend, and completion rate - the five sections
/// the Phase 6 brief lists, each backed by its own `GET
/// /api/schools/analytics/*` endpoint (Task 7). Every number is already
/// computed server-side; this screen only presents it.
///
/// Task 9 adds printable exports (school-wide and per-classroom PDFs,
/// previewed before sharing) and a date-range filter. The filter only
/// narrows the Trend section: it is the only endpoint here that accepts
/// a day count at all (`?days=`), so "Last 30 days"/"This month" apply
/// there and nowhere else - Overview's weekly/monthly averages and the
/// Weak Phonemes list keep their own fixed, server-defined windows
/// rather than pretending to honor a filter the API has no way to apply
/// to them.
class SchoolAdminReportsScreen extends ConsumerWidget {
  const SchoolAdminReportsScreen({super.key});

  Future<Uint8List?> _fetchLogoBytes(Dio dio, String url) async {
    try {
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } catch (_) {
      // A missing/unreachable logo must never block the report itself -
      // the PDF just renders without one.
      return null;
    }
  }

  Future<void> _exportSchoolReport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final school = ref.read(mySchoolProvider).valueOrNull;
    final overview = ref.read(schoolOverviewProvider).valueOrNull;
    final classrooms = ref.read(classroomAnalyticsProvider).valueOrNull;
    final phonemes = ref.read(weakestPhonemesProvider).valueOrNull;
    final trend = ref.read(reportTrendProvider).valueOrNull;
    final range = ref.read(reportDateRangeProvider);

    if (school == null ||
        overview == null ||
        classrooms == null ||
        phonemes == null ||
        trend == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report data is still loading - try again in a moment.'),
        ),
      );
      return;
    }

    if (overview.totalStudents == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No report available yet - nothing to export.'),
        ),
      );
      return;
    }

    Uint8List? logoBytes;
    if (school.logo != null) {
      logoBytes = await _fetchLogoBytes(ref.read(dioProvider), school.logo!);
    }

    try {
      final generatedAt = DateTime.now();
      final bytes = await SchoolPdfReportBuilder.buildBytes(
        school: school,
        overview: overview,
        classrooms: classrooms,
        phonemes: phonemes,
        trend: trend,
        range: range,
        generatedAt: generatedAt,
        logoBytes: logoBytes,
      );

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportPreviewScreen(
            title: 'School Report',
            fileName: SchoolPdfReportBuilder.fileName(school, generatedAt),
            bytes: bytes,
          ),
        ),
      );
    } catch (_) {
      // PDF generation has no DioException path of its own (bytes are
      // already fetched by here) - a failure at this point is a local
      // rendering problem, e.g. malformed logo bytes reaching
      // pw.MemoryImage, not a network error worth parsing for detail.
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not generate the report. Try again.')),
      );
    }
  }

  Future<void> _pickClassroomAndExport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final classrooms = ref.read(classroomAnalyticsProvider).valueOrNull;
    final school = ref.read(mySchoolProvider).valueOrNull;

    if (classrooms == null || classrooms.isEmpty || school == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No active classrooms to report on yet.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<ClassroomAnalytics>(
      context: context,
      builder: (_) => _ClassroomPickerSheet(classrooms: classrooms),
    );
    if (selected == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        // `barrierDismissible: false` only blocks tap-outside; without
        // this, the system back button can still pop the dialog while
        // the fetch below is in flight, and the unconditional pop() on
        // completion would then close whatever route is on top instead
        // - in practice, the Reports screen itself.
        canPop: false,
        child: Center(
          child: Semantics(
            label: 'Preparing classroom report',
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final classroomRepo = ref.read(classroomRepositoryProvider);
      final analyticsRepo = ref.read(schoolAnalyticsRepositoryProvider);

      final detail = await classroomRepo.fetchClassroomDetail(
        selected.classroomId,
      );
      final phonemes = await analyticsRepo.fetchWeakestPhonemes(
        classroomId: selected.classroomId,
      );
      final recentActivity = await analyticsRepo.fetchTrends(
        days: 7,
        classroomId: selected.classroomId,
      );

      final generatedAt = DateTime.now();
      final bytes = await ClassroomPdfReportBuilder.buildBytes(
        school: school,
        classroom: detail,
        analytics: selected,
        phonemes: phonemes,
        recentActivity: recentActivity,
        generatedAt: generatedAt,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportPreviewScreen(
            title: detail.name,
            fileName: ClassroomPdfReportBuilder.fileName(detail, generatedAt),
            bytes: bytes,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(error.fieldMessage ?? error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final overviewAsync = ref.watch(schoolOverviewProvider);
    final classroomsAsync = ref.watch(classroomAnalyticsProvider);
    final phonemesAsync = ref.watch(weakestPhonemesProvider);
    final trendAsync = ref.watch(reportTrendProvider);
    final range = ref.watch(reportDateRangeProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<_ExportChoice>(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export report',
            onSelected: (choice) {
              switch (choice) {
                case _ExportChoice.school:
                  _exportSchoolReport(context, ref);
                case _ExportChoice.classroom:
                  _pickClassroomAndExport(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ExportChoice.school,
                child: Text('Export school report'),
              ),
              PopupMenuItem(
                value: _ExportChoice.classroom,
                child: Text('Export classroom report'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: overviewAsync.when(
                loading: () => const _ReportsSkeleton(),
                error: (error, _) => _ErrorState(
                  message: error is ApiException ? error.message : '$error',
                  onRetry: () => ref.invalidate(schoolOverviewProvider),
                ),
                data: (overview) {
                  if (overview.totalStudents == 0) {
                    return const _NoReportYetState();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(schoolOverviewProvider);
                      ref.invalidate(classroomAnalyticsProvider);
                      ref.invalidate(weakestPhonemesProvider);
                      ref.invalidate(reportTrendProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const _SectionTitle('Overview'),
                        const SizedBox(height: 12),
                        AnalyticsCard(
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
                        const SizedBox(height: 24),

                        const _SectionTitle('Classroom Performance'),
                        const SizedBox(height: 12),
                        classroomsAsync.when(
                          loading: () =>
                              const SkeletonBox(height: 140, borderRadius: 16),
                          error: (error, _) => _ErrorState(
                            message: error is ApiException
                                ? error.message
                                : '$error',
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
                                  for (
                                    var i = 0;
                                    i < classrooms.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const Divider(height: 24),
                                    HeatBar(
                                      label: classrooms[i].classroomName,
                                      value:
                                          classrooms[i].averagePronunciationScore,
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

                        const _SectionTitle('Weak Phonemes'),
                        const SizedBox(height: 12),
                        phonemesAsync.when(
                          loading: () =>
                              const SkeletonBox(height: 140, borderRadius: 16),
                          error: (error, _) => _ErrorState(
                            message: error is ApiException
                                ? error.message
                                : '$error',
                            onRetry: () =>
                                ref.invalidate(weakestPhonemesProvider),
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

                        const _SectionTitle('Trend'),
                        const SizedBox(height: 12),
                        Semantics(
                          container: true,
                          label: 'Filter the trend chart by date range',
                          child: _ReportRangeFilter(current: range),
                        ),
                        const SizedBox(height: 12),
                        trendAsync.when(
                          loading: () =>
                              const SkeletonBox(height: 180, borderRadius: 16),
                          error: (error, _) => _ErrorState(
                            message: error is ApiException
                                ? error.message
                                : '$error',
                            onRetry: () => ref.invalidate(reportTrendProvider),
                          ),
                          data: (trend) {
                            final hasActivity = trend.any(
                              (point) => point.attempts > 0,
                            );
                            if (!hasActivity) {
                              return const AnalyticsCard(
                                child: ParentEmptyState(
                                  icon: Icons.timeline_rounded,
                                  message:
                                      'No activity recorded in this period.',
                                ),
                              );
                            }
                            return SchoolTrendBarChart(
                              trend: trend,
                              title: '${range.label} Trend',
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        const _SectionTitle('Completion Rate'),
                        const SizedBox(height: 12),
                        classroomsAsync.when(
                          loading: () =>
                              const SkeletonBox(height: 140, borderRadius: 16),
                          error: (error, _) => _ErrorState(
                            message: error is ApiException
                                ? error.message
                                : '$error',
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
                                  for (
                                    var i = 0;
                                    i < classrooms.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const Divider(height: 24),
                                    HeatBar(
                                      label: classrooms[i].classroomName,
                                      value: classrooms[i].completionRate
                                          .round(),
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

enum _ExportChoice { school, classroom }

/// A section heading, marked as a semantics header so a screen-reader
/// user can jump between report sections the same way a sighted user
/// scans the page visually.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(width: 120, height: 20),
        SizedBox(height: 12),
        SkeletonBox(height: 90, borderRadius: 16),
        SizedBox(height: 24),
        SkeletonBox(width: 200, height: 20),
        SizedBox(height: 12),
        SkeletonBox(height: 140, borderRadius: 16),
        SizedBox(height: 24),
        SkeletonBox(width: 160, height: 20),
        SizedBox(height: 12),
        SkeletonBox(height: 140, borderRadius: 16),
      ],
    );
  }
}

/// Segmented, tappable date-range control for the Trend section
/// (Task 9, Feature 3). "Custom range" opens a date picker for the
/// start date rather than immediately selecting itself - there is
/// nothing useful to show until a start date exists.
class _ReportRangeFilter extends ConsumerWidget {
  const _ReportRangeFilter({required this.current});

  final ReportDateRange current;

  Future<void> _pickCustomStart(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.customStart ?? now.subtract(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = ReportDateRange(
        preset: ReportRangePreset.custom,
        customStart: picked,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in ReportRangePreset.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(ReportDateRange(preset: preset).label),
                selected: current.preset == preset,
                onSelected: (_) {
                  if (preset == ReportRangePreset.custom) {
                    _pickCustomStart(context, ref);
                  } else {
                    ref.read(reportDateRangeProvider.notifier).state =
                        ReportDateRange(preset: preset);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassroomPickerSheet extends StatelessWidget {
  const _ClassroomPickerSheet({required this.classrooms});

  final List<ClassroomAnalytics> classrooms;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              header: true,
              child: Text(
                'Select a classroom',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          for (final classroom in classrooms)
            ListTile(
              title: Text(classroom.classroomName),
              subtitle: Text(
                '${classroom.studentCount} students · '
                '${classroom.averagePronunciationScore}% average',
              ),
              onTap: () => Navigator.of(context).pop(classroom),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NoReportYetState extends StatelessWidget {
  const _NoReportYetState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ParentEmptyState(
          icon: Icons.insert_chart_outlined_rounded,
          message:
              'No report available yet. Once students start practising, '
              'their progress will appear here.',
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
