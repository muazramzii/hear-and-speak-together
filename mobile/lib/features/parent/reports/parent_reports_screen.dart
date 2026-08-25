import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/progress.dart';
import '../../../repositories/students_repository.dart';
import '../design/parent_theme.dart';
import '../parent_providers.dart';
import '../widgets/parent_widgets.dart';
import 'pdf_report_builder.dart';

/// Screen 5: exportable learning reports. Every section reads the same
/// analytics the other screens do, laid out as a report; the PDF export
/// button turns whatever is currently on screen into a real PDF, generated
/// and shared entirely on-device (see `PdfReportBuilder`).
class ParentReportsScreen extends ConsumerWidget {
  const ParentReportsScreen({super.key});

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final students = ref.read(studentsProvider).valueOrNull;
    if (students == null || students.isEmpty) return;

    final studentId = effectiveStudentId(ref, students);
    final report =
        studentId == null
            ? null
            : ref.read(studentProgressProvider(studentId)).valueOrNull;

    if (report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report data is still loading - try again in a moment.'),
        ),
      );
      return;
    }

    final student = students.firstWhere((s) => s.id == studentId);
    final generatedAt = DateTime.now();

    final bytes = await PdfReportBuilder.buildBytes(
      student: student,
      report: report,
      generatedAt: generatedAt,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: PdfReportBuilder.fileName(student, generatedAt),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.parentColors;
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export as PDF',
            onPressed: () => _exportPdf(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (students) {
            if (students.isEmpty) {
              return const ParentEmptyState(
                icon: Icons.description_rounded,
                message: 'Link a learner to generate their first report.',
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
                  (report) => _ReportBody(
                    student: students.firstWhere((s) => s.id == studentId),
                    report: report,
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.student, required this.report});

  final SupervisedStudent student;
  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${student.name}\'s Learning Report',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Generated ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),

        _ReportSection(
          title: 'Weekly Report',
          child: _WeeklyReportContent(report: report),
        ),
        const SizedBox(height: 20),

        _ReportSection(
          title: 'Monthly Report',
          child: _MonthlyReportContent(report: report),
        ),
        const SizedBox(height: 20),

        _ReportSection(
          title: 'Category Performance',
          child:
              report.categories.isEmpty
                  ? const ParentEmptyState(
                    icon: Icons.category_rounded,
                    message: 'No category data yet.',
                  )
                  : Column(
                    children: [
                      for (var i = 0; i < report.categories.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        HeatBar(
                          label: report.categories[i].name,
                          value: report.categories[i].averageScore,
                        ),
                      ],
                    ],
                  ),
        ),
        const SizedBox(height: 20),

        _ReportSection(
          title: 'Pronunciation Summary',
          child: _PronunciationSummaryContent(report: report),
        ),
        const SizedBox(height: 20),

        _ReportSection(
          title: 'Recommendations',
          child:
              report.recommendations.isEmpty
                  ? const ParentEmptyState(
                    icon: Icons.lightbulb_outline_rounded,
                    message:
                        'Complete more lessons to receive personalized recommendations.',
                  )
                  : Column(
                    children: [
                      for (final recommendation in report.recommendations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RecommendationCard(
                            recommendation: recommendation,
                          ),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        AnalyticsCard(child: child),
      ],
    );
  }
}

class _WeeklyReportContent extends StatelessWidget {
  const _WeeklyReportContent({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final comparison = report.weeklyComparison;
    if (comparison == null) {
      return const ParentEmptyState(
        icon: Icons.calendar_view_week_rounded,
        message: 'No practice recorded this week yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Attempts this week',
                value: '${comparison.thisWeek.attempts}',
              ),
            ),
            Expanded(
              child: MetricTile(
                label: 'Average score',
                value:
                    comparison.thisWeek.averageScore == null
                        ? '—'
                        : '${comparison.thisWeek.averageScore}%',
                trend:
                    comparison.scoreChange == null
                        ? null
                        : '${comparison.scoreChange! >= 0 ? '+' : ''}${comparison.scoreChange}% vs last week',
                trendPositive:
                    comparison.scoreChange == null
                        ? null
                        : comparison.scoreChange! >= 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthlyReportContent extends StatelessWidget {
  const _MonthlyReportContent({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;

    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Total sessions',
            value: '${summary.practiceSessions}',
          ),
        ),
        Expanded(
          child: MetricTile(
            label: 'Lessons completed',
            value: '${summary.lessonsCompleted}',
          ),
        ),
        Expanded(
          child: MetricTile(
            label: 'Current streak',
            value: '${summary.streakDays}d',
          ),
        ),
      ],
    );
  }
}

class _PronunciationSummaryContent extends StatelessWidget {
  const _PronunciationSummaryContent({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final weak = report.phonemes.weak;
    final strong = report.phonemes.strong;

    if (weak.isEmpty && strong.isEmpty) {
      return const ParentEmptyState(
        icon: Icons.graphic_eq_rounded,
        message: 'Not enough attempts yet for a pronunciation summary.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (weak.isNotEmpty) ...[
          Text(
            'Needs improvement',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final stat in weak.take(3)) PhonemeBar(stat: stat, isWeak: true),
          const SizedBox(height: 12),
        ],
        if (strong.isNotEmpty) ...[
          Text('Strong sounds', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final stat in strong.take(3))
            PhonemeBar(stat: stat, isWeak: false),
        ],
      ],
    );
  }
}
