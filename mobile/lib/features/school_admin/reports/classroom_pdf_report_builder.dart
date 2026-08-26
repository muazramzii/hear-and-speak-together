import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/school.dart';
import '../../../models/school_analytics.dart';

/// Builds the per-classroom PDF report (Phase 6 Task 9, Feature 2) - same
/// on-device generation and palette as [SchoolPdfReportBuilder] and
/// Parent Mode's report, scoped to one classroom's own staff, students,
/// and analytics rather than the whole school.
class ClassroomPdfReportBuilder {
  const ClassroomPdfReportBuilder._();

  static const _indigo = PdfColor.fromInt(0xFF4F46E5);
  static const _emerald = PdfColor.fromInt(0xFF059669);
  static const _amber = PdfColor.fromInt(0xFFB45309);
  static const _amberSoft = PdfColor.fromInt(0xFFFFFBEB);
  static const _slate = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _ink = PdfColor.fromInt(0xFF0F172A);

  static Future<pw.Document> buildDocument({
    required School school,
    required ClassroomDetail classroom,
    required ClassroomAnalytics? analytics,
    required List<PhonemeAnalytics> phonemes,
    required List<DailyTrend> recentActivity,
    required DateTime generatedAt,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _header(school, classroom, generatedAt),
        build: (context) => [
          _summarySection(classroom, analytics),
          pw.SizedBox(height: 20),
          _teacherSection(classroom),
          pw.SizedBox(height: 20),
          _phonemeSection(phonemes),
          pw.SizedBox(height: 20),
          _recentActivitySection(recentActivity),
        ],
      ),
    );

    return doc;
  }

  static Future<Uint8List> buildBytes({
    required School school,
    required ClassroomDetail classroom,
    required ClassroomAnalytics? analytics,
    required List<PhonemeAnalytics> phonemes,
    required List<DailyTrend> recentActivity,
    required DateTime generatedAt,
  }) async {
    final doc = await buildDocument(
      school: school,
      classroom: classroom,
      analytics: analytics,
      phonemes: phonemes,
      recentActivity: recentActivity,
      generatedAt: generatedAt,
    );
    return doc.save();
  }

  static String fileName(Classroom classroom, DateTime generatedAt) {
    final safeName = classroom.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final date =
        '${generatedAt.year}${generatedAt.month.toString().padLeft(2, '0')}'
        '${generatedAt.day.toString().padLeft(2, '0')}';
    return 'classroom_report_${safeName}_$date.pdf';
  }

  // ---- Sections -----------------------------------------------------

  static pw.Widget _header(
    School school,
    ClassroomDetail classroom,
    DateTime generatedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              school.name,
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
          '${classroom.name} - Classroom Report',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Code ${classroom.classroomCode} · '
          '${classroom.isActive ? 'Active' : 'Archived'}',
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

  static pw.Widget _summarySection(
    ClassroomDetail classroom,
    ClassroomAnalytics? analytics,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Summary'),
        pw.Row(
          children: [
            _metricBox('Students', '${classroom.studentCount}'),
            pw.SizedBox(width: 12),
            _metricBox(
              'Average score',
              analytics == null
                  ? '-'
                  : '${analytics.averagePronunciationScore}%',
            ),
            pw.SizedBox(width: 12),
            _metricBox(
              'Completion rate',
              analytics == null
                  ? '-'
                  : '${analytics.completionRate.round()}%',
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _teacherSection(ClassroomDetail classroom) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Teachers'),
        if (classroom.staff.isEmpty)
          pw.Text(
            'No teacher assigned yet.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          )
        else
          pw.Column(
            children: [
              for (final member in classroom.staff)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        member.teacherName,
                        style: const pw.TextStyle(fontSize: 10, color: _ink),
                      ),
                      pw.Text(
                        member.roleLabel,
                        style: const pw.TextStyle(fontSize: 9, color: _slate),
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
        _sectionTitle('Weak Phonemes'),
        if (phonemes.isEmpty)
          pw.Text(
            'Not enough attempts yet to identify a pattern in this '
            'classroom.',
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
                          '${phoneme.affectedStudents} students',
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

  static pw.Widget _recentActivitySection(List<DailyTrend> trend) {
    final activeDays = trend.where((point) => point.attempts > 0).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recent Activity (7 days)'),
        if (trend.isEmpty || activeDays.isEmpty)
          pw.Text(
            'No practice recorded in this classroom in the last 7 days.',
            style: const pw.TextStyle(fontSize: 10, color: _slate),
          )
        else
          pw.Column(
            children: [
              for (final point in trend)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        _formatDate(point.date),
                        style: const pw.TextStyle(fontSize: 9, color: _ink),
                      ),
                      pw.Text(
                        point.attempts == 0
                            ? 'No practice'
                            : '${point.attempts} attempts · '
                                  '${point.averageScore}% average',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: point.attempts == 0 ? _slate : _emerald,
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

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
