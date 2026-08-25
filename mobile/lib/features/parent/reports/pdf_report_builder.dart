import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/progress.dart';
import '../../../models/user.dart';
import '../../../repositories/students_repository.dart';

/// Builds the parent-facing learning report as a real PDF, entirely on the
/// device from data already fetched for the Reports screen - no backend
/// endpoint of its own, per the Phase 5 brief ("export locally").
///
/// Kept separate from any widget so it can be unit tested without a
/// rendering surface: [buildDocument] returns a `pw.Document`, and the
/// screen is the only thing that turns that into bytes/prints/shares it.
class PdfReportBuilder {
  const PdfReportBuilder._();

  static const _indigo = PdfColor.fromInt(0xFF4F46E5);
  static const _emerald = PdfColor.fromInt(0xFF059669);
  static const _emeraldSoft = PdfColor.fromInt(0xFFECFDF5);
  static const _amber = PdfColor.fromInt(0xFFB45309);
  static const _amberSoft = PdfColor.fromInt(0xFFFFFBEB);
  static const _slate = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _ink = PdfColor.fromInt(0xFF0F172A);

  static Future<pw.Document> buildDocument({
    required SupervisedStudent student,
    required ProgressReport report,
    required DateTime generatedAt,
  }) async {
    final doc = pw.Document();
    final language = AppLanguage.fromCode(student.languageCode).label;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _header(student, language, generatedAt),
        build:
            (context) => [
              _weeklyScoreSection(report),
              pw.SizedBox(height: 20),
              _weeklyTrendSection(report),
              pw.SizedBox(height: 20),
              _phonemeSection('Strong Sounds', report.phonemes.strong, _emerald),
              pw.SizedBox(height: 16),
              _phonemeSection('Weak Sounds', report.phonemes.weak, _amber),
              pw.SizedBox(height: 20),
              _categorySection(report),
              pw.SizedBox(height: 20),
              _recommendationsSection(report),
            ],
      ),
    );

    return doc;
  }

  static Future<Uint8List> buildBytes({
    required SupervisedStudent student,
    required ProgressReport report,
    required DateTime generatedAt,
  }) async {
    final doc = await buildDocument(
      student: student,
      report: report,
      generatedAt: generatedAt,
    );
    return doc.save();
  }

  static String fileName(SupervisedStudent student, DateTime generatedAt) {
    final safeName = student.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final date =
        '${generatedAt.year}${generatedAt.month.toString().padLeft(2, '0')}'
        '${generatedAt.day.toString().padLeft(2, '0')}';
    return 'hear_speak_report_${safeName}_$date.pdf';
  }

  // ---- Sections -----------------------------------------------------

  static pw.Widget _header(
    SupervisedStudent student,
    String language,
    DateTime generatedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Hear & Speak Together',
              style: pw.TextStyle(
                fontSize: 12,
                color: _slate,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Generated ${_formatDate(generatedAt)}',
              style: const pw.TextStyle(fontSize: 10, color: _slate),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          "${student.name}'s Learning Report",
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '$language · Level ${student.level} · ${student.streakDays}-day streak',
          style: const pw.TextStyle(fontSize: 11, color: _slate),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: _border, thickness: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink),
      ),
    );
  }

  static pw.Widget _weeklyScoreSection(ProgressReport report) {
    final comparison = report.weeklyComparison;
    final summary = report.summary;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Weekly Score'),
        pw.Row(
          children: [
            _metricBox(
              'This week',
              comparison?.thisWeek.averageScore == null
                  ? '-'
                  : '${comparison!.thisWeek.averageScore}%',
            ),
            pw.SizedBox(width: 12),
            _metricBox(
              'Change vs last week',
              comparison?.scoreChange == null
                  ? '-'
                  : '${comparison!.scoreChange! >= 0 ? '+' : ''}${comparison.scoreChange}%',
            ),
            pw.SizedBox(width: 12),
            _metricBox(
              'Overall average',
              summary.averageScore == null ? '-' : '${summary.averageScore}%',
            ),
            pw.SizedBox(width: 12),
            _metricBox('Lessons completed', '${summary.lessonsCompleted}'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _metricBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _slate)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _indigo),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _weeklyTrendSection(ProgressReport report) {
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final slots = List<int?>.filled(7, null);
    final now = DateTime.now();
    final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));

    for (final point in report.trend) {
      final daysFromMonday = point.date
          .difference(
            DateTime(mondayThisWeek.year, mondayThisWeek.month, mondayThisWeek.day),
          )
          .inDays;
      if (daysFromMonday >= 0 && daysFromMonday < 7) {
        slots[daysFromMonday] = point.averageScore;
      }
    }

    if (report.trend.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Weekly Trend'),
          pw.Text(
            'No practice recorded this week yet.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Weekly Trend'),
        pw.Container(
          height: 90,
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      if (slots[i] != null)
                        pw.Text(
                          '${slots[i]}',
                          style: const pw.TextStyle(fontSize: 7, color: _slate),
                        ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                        height: 50 * ((slots[i] ?? 0) / 100).clamp(0.04, 1.0),
                        decoration: pw.BoxDecoration(
                          color: slots[i] == null ? _border : _indigo,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        weekdayLabels[i],
                        style: const pw.TextStyle(fontSize: 7, color: _slate),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _phonemeSection(
    String title,
    List<PhonemeStat> stats,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        if (stats.isEmpty)
          pw.Text(
            'Not enough attempts yet.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          )
        else
          pw.Column(
            children: [
              for (final stat in stats)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 32,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: color == _emerald ? _emeraldSoft : _amberSoft,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '/${stat.phoneme}/',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Text(
                          stat.examples.isEmpty
                              ? '${stat.frequency}% error rate'
                              : '${stat.frequency}% error rate · e.g. ${stat.examples.join(', ')}',
                          style: const pw.TextStyle(fontSize: 9, color: _ink),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _categorySection(ProgressReport report) {
    final sorted = [...report.categories]
      ..sort((a, b) => b.averageScore.compareTo(a.averageScore));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Category Mastery'),
        if (sorted.isEmpty)
          pw.Text('No category data yet.', style: const pw.TextStyle(fontSize: 10, color: _slate))
        else
          pw.Column(
            children: [
              for (final category in sorted)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 90,
                        child: pw.Text(
                          category.name,
                          style: const pw.TextStyle(fontSize: 9, color: _ink),
                        ),
                      ),
                      pw.Expanded(
                        // `pw` has no FractionallySizedBox, so the fraction
                        // is expressed as a flex split instead: a filled bar
                        // sized to the score, and a bare-track remainder.
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: category.averageScore.clamp(1, 100),
                              child: pw.Container(
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color: category.isWeak ? _amber : _emerald,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            if (category.averageScore < 100)
                              pw.Expanded(
                                flex: 100 - category.averageScore.clamp(0, 99),
                                child: pw.Container(
                                  height: 8,
                                  decoration: const pw.BoxDecoration(
                                    color: _border,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.SizedBox(
                        width: 30,
                        child: pw.Text(
                          '${category.averageScore}%',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _recommendationsSection(ProgressReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recommendations'),
        if (report.recommendations.isEmpty)
          pw.Text(
            'Complete more lessons to receive personalized recommendations.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          )
        else
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final recommendation in report.recommendations)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Bullet(
                    text: _recommendationText(recommendation),
                    style: const pw.TextStyle(fontSize: 9.5, color: _ink),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static String _recommendationText(Recommendation recommendation) {
    final words = recommendation.words.map((w) => w.text).join(', ');
    return switch (recommendation.type) {
      'practise_words' =>
        'Practise again: $words (scoring below target).',
      'revisit_categories' =>
        'Revisit ${recommendation.categories.map((c) => c.name).join(', ')} (below target average).',
      'gentle_reminder' =>
        "It's been ${recommendation.daysSincePractice ?? 'a few'} days since the last session - a short practice today would help.",
      'get_started' => 'No sessions recorded yet - start the first lesson.',
      _ => recommendation.reason,
    };
  }

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
