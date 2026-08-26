import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/report_filter.dart';
import '../../../models/school.dart';
import '../../../models/school_analytics.dart';

/// Builds the school-wide PDF report (Phase 6 Task 9), entirely on the
/// device from data the Reports screen has already fetched - no backend
/// PDF endpoint, matching Parent Mode's own
/// `../../parent/reports/pdf_report_builder.dart`, whose section/style
/// conventions this mirrors exactly (same palette, same static-class
/// shape) so the two report families read as one product.
class SchoolPdfReportBuilder {
  const SchoolPdfReportBuilder._();

  static const _indigo = PdfColor.fromInt(0xFF4F46E5);
  static const _emerald = PdfColor.fromInt(0xFF059669);
  static const _amber = PdfColor.fromInt(0xFFB45309);
  static const _amberSoft = PdfColor.fromInt(0xFFFFFBEB);
  static const _slate = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _ink = PdfColor.fromInt(0xFF0F172A);

  static Future<pw.Document> buildDocument({
    required School school,
    required SchoolOverview overview,
    required List<ClassroomAnalytics> classrooms,
    required List<PhonemeAnalytics> phonemes,
    required List<DailyTrend> trend,
    required ReportDateRange range,
    required DateTime generatedAt,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document();
    final recommendations = _buildRecommendations(
      overview: overview,
      classrooms: classrooms,
      phonemes: phonemes,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            _header(school, generatedAt, logoBytes: logoBytes),
        build: (context) => [
          _overviewSection(overview),
          pw.SizedBox(height: 20),
          _classroomRankingSection(classrooms),
          pw.SizedBox(height: 20),
          _phonemeSection(phonemes),
          pw.SizedBox(height: 20),
          _trendSection(trend, range),
          pw.SizedBox(height: 20),
          _recommendationsSection(recommendations),
        ],
      ),
    );

    return doc;
  }

  static Future<Uint8List> buildBytes({
    required School school,
    required SchoolOverview overview,
    required List<ClassroomAnalytics> classrooms,
    required List<PhonemeAnalytics> phonemes,
    required List<DailyTrend> trend,
    required ReportDateRange range,
    required DateTime generatedAt,
    Uint8List? logoBytes,
  }) async {
    final doc = await buildDocument(
      school: school,
      overview: overview,
      classrooms: classrooms,
      phonemes: phonemes,
      trend: trend,
      range: range,
      generatedAt: generatedAt,
      logoBytes: logoBytes,
    );
    return doc.save();
  }

  static String fileName(School school, DateTime generatedAt) {
    final safeName = school.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final date =
        '${generatedAt.year}${generatedAt.month.toString().padLeft(2, '0')}'
        '${generatedAt.day.toString().padLeft(2, '0')}';
    return 'school_report_${safeName}_$date.pdf';
  }

  // ---- Sections -----------------------------------------------------

  static pw.Widget _header(
    School school,
    DateTime generatedAt, {
    Uint8List? logoBytes,
  }) {
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
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoBytes != null) ...[
              pw.ClipOval(
                child: pw.Image(
                  pw.MemoryImage(logoBytes),
                  width: 40,
                  height: 40,
                  fit: pw.BoxFit.cover,
                ),
              ),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    school.name,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'School Performance Report',
                    style: const pw.TextStyle(fontSize: 11, color: _slate),
                  ),
                ],
              ),
            ),
          ],
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
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
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
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: _slate),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _overviewSection(SchoolOverview overview) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Overview'),
        pw.Row(
          children: [
            _metricBox('Students', '${overview.totalStudents}'),
            pw.SizedBox(width: 12),
            _metricBox('Teachers', '${overview.totalTeachers}'),
            pw.SizedBox(width: 12),
            _metricBox('Classrooms', '${overview.totalClassrooms}'),
            pw.SizedBox(width: 12),
            _metricBox('Active today', '${overview.activeStudentsToday}'),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            _metricBox(
              'Weekly average',
              overview.weeklyAverageScore == null
                  ? '-'
                  : '${overview.weeklyAverageScore}%',
            ),
            pw.SizedBox(width: 12),
            _metricBox(
              'Monthly average',
              overview.monthlyAverageScore == null
                  ? '-'
                  : '${overview.monthlyAverageScore}%',
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _classroomRankingSection(List<ClassroomAnalytics> rows) {
    final ranked = [...rows]
      ..sort(
        (a, b) => b.averagePronunciationScore.compareTo(
          a.averagePronunciationScore,
        ),
      );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Classroom Performance Ranking'),
        if (ranked.isEmpty)
          pw.Text(
            'No active classrooms yet.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          )
        else
          pw.Column(
            children: [
              for (var i = 0; i < ranked.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 18,
                        child: pw.Text(
                          '${i + 1}.',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _slate,
                          ),
                        ),
                      ),
                      pw.SizedBox(
                        width: 110,
                        child: pw.Text(
                          ranked[i].classroomName,
                          style: const pw.TextStyle(fontSize: 9, color: _ink),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: ranked[i].averagePronunciationScore.clamp(
                                1,
                                100,
                              ),
                              child: pw.Container(
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color: _emerald,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            if (ranked[i].averagePronunciationScore < 100)
                              pw.Expanded(
                                flex: 100 -
                                    ranked[i].averagePronunciationScore.clamp(
                                      0,
                                      99,
                                    ),
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
                        width: 32,
                        child: pw.Text(
                          '${ranked[i].averagePronunciationScore}%',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
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

  static pw.Widget _phonemeSection(List<PhonemeAnalytics> phonemes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Weakest Phonemes'),
        if (phonemes.isEmpty)
          pw.Text(
            'Not enough attempts yet to identify a pattern.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          )
        else
          pw.Column(
            children: [
              for (final phoneme in phonemes)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 32,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: _amberSoft,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '/${phoneme.phoneme}/',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _amber,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Text(
                          '${phoneme.errorRate}% error rate · '
                          '${phoneme.affectedStudents} students · '
                          '${phoneme.totalOccurrences} occurrences',
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

  /// Rendered as individually-labelled bars for a short window; a longer
  /// custom/monthly window drops per-bar labels (there is no room for 30+
  /// on an A4 page) and shows only the range's start/end dates instead.
  static pw.Widget _trendSection(List<DailyTrend> trend, ReportDateRange range) {
    if (trend.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('${range.label} Trend'),
          pw.Text(
            'No practice recorded in this period yet.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          ),
        ],
      );
    }

    final showLabels = trend.length <= 14;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('${range.label} Trend'),
        pw.Container(
          height: 90,
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (final point in trend)
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      if (showLabels && point.attempts > 0)
                        pw.Text(
                          '${point.averageScore}',
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: _slate,
                          ),
                        ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                        height:
                            50 * (point.averageScore / 100).clamp(0.04, 1.0),
                        decoration: pw.BoxDecoration(
                          color: point.attempts == 0 ? _border : _indigo,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _formatDate(trend.first.date),
              style: const pw.TextStyle(fontSize: 8, color: _slate),
            ),
            pw.Text(
              _formatDate(trend.last.date),
              style: const pw.TextStyle(fontSize: 8, color: _slate),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _recommendationsSection(List<String> recommendations) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recommendations'),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final recommendation in recommendations)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Bullet(
                  text: recommendation,
                  style: const pw.TextStyle(fontSize: 9.5, color: _ink),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Simple, deterministic rules over figures the report already shows -
  /// no new analytics, just presentation-layer phrasing of numbers
  /// already computed server-side.
  static List<String> _buildRecommendations({
    required SchoolOverview overview,
    required List<ClassroomAnalytics> classrooms,
    required List<PhonemeAnalytics> phonemes,
  }) {
    final recommendations = <String>[];

    if (overview.weeklyAverageScore != null &&
        overview.weeklyAverageScore! < 70) {
      recommendations.add(
        'School-wide weekly accuracy is ${overview.weeklyAverageScore}%, '
        'below the 70% target - consider scheduling extra practice '
        'sessions this week.',
      );
    }

    if (phonemes.isNotEmpty) {
      final weakest = phonemes.first;
      recommendations.add(
        'Focus practice on /${weakest.phoneme}/ - the most common error '
        'school-wide, affecting ${weakest.affectedStudents} students.',
      );
    }

    if (classrooms.isNotEmpty) {
      final lowest = classrooms.reduce(
        (a, b) => a.averagePronunciationScore <= b.averagePronunciationScore
            ? a
            : b,
      );
      recommendations.add(
        '${lowest.classroomName} has the lowest average score '
        '(${lowest.averagePronunciationScore}%) - consider pairing with a '
        'higher-performing classroom or scheduling additional support.',
      );
    }

    if (overview.activeStudentsToday == 0 && overview.totalStudents > 0) {
      recommendations.add(
        'No students practised today - a reminder to families or '
        'teachers may help re-engage the school.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Overall performance is on track - keep up the current practice '
        'routine.',
      );
    }

    return recommendations;
  }

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
