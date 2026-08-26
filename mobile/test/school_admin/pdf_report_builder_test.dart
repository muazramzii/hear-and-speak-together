import 'package:flutter_test/flutter_test.dart';

import 'package:hear_speak_together/features/school_admin/reports/classroom_pdf_report_builder.dart';
import 'package:hear_speak_together/features/school_admin/reports/school_pdf_report_builder.dart';
import 'package:hear_speak_together/models/report_filter.dart';
import 'package:hear_speak_together/models/school.dart';
import 'package:hear_speak_together/models/school_analytics.dart';

/// Unit tests for the PDF generation service (Task 9) - no widget
/// pumping needed, `buildBytes` runs entirely in Dart. These only
/// assert the builders produce a real, non-empty PDF for both a
/// fully-populated report and a completely empty one (a school/
/// classroom with no data yet must not throw).
void main() {
  final school = const School(
    id: 1,
    name: 'Sunshine School',
    logo: null,
    adminEmail: 'admin@example.com',
    isActive: true,
  );

  group('SchoolPdfReportBuilder', () {
    test('produces a non-empty PDF with populated data', () async {
      final bytes = await SchoolPdfReportBuilder.buildBytes(
        school: school,
        overview: const SchoolOverview(
          totalStudents: 12,
          totalTeachers: 3,
          totalClassrooms: 2,
          activeStudentsToday: 4,
          weeklyAverageScore: 81,
          monthlyAverageScore: 77,
        ),
        classrooms: const [
          ClassroomAnalytics(
            classroomId: 1,
            classroomName: 'Classroom Alpha',
            teacherCount: 1,
            studentCount: 6,
            averagePronunciationScore: 85,
            completionRate: 60,
          ),
          ClassroomAnalytics(
            classroomId: 2,
            classroomName: 'Classroom Beta',
            teacherCount: 1,
            studentCount: 6,
            averagePronunciationScore: 60,
            completionRate: 40,
          ),
        ],
        phonemes: const [
          PhonemeAnalytics(
            phoneme: 'th',
            errorRate: 62,
            totalOccurrences: 18,
            affectedStudents: 9,
          ),
        ],
        trend: [
          DailyTrend(
            date: DateTime(2026, 8, 20),
            attempts: 5,
            averageScore: 80,
          ),
        ],
        range: ReportDateRange.last7Days,
        generatedAt: DateTime(2026, 8, 26),
      );

      expect(bytes, isNotEmpty);
      // A PDF file always starts with this magic header.
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('produces a PDF for a school with no data at all', () async {
      final bytes = await SchoolPdfReportBuilder.buildBytes(
        school: school,
        overview: const SchoolOverview(
          totalStudents: 0,
          totalTeachers: 0,
          totalClassrooms: 0,
          activeStudentsToday: 0,
          weeklyAverageScore: null,
          monthlyAverageScore: null,
        ),
        classrooms: const [],
        phonemes: const [],
        trend: const [],
        range: ReportDateRange.last7Days,
        generatedAt: DateTime(2026, 8, 26),
      );

      expect(bytes, isNotEmpty);
    });

    test('fileName sanitizes the school name and stamps the date', () {
      final name = SchoolPdfReportBuilder.fileName(
        school,
        DateTime(2026, 8, 26),
      );

      expect(name, 'school_report_Sunshine_School_20260826.pdf');
    });
  });

  group('ClassroomPdfReportBuilder', () {
    final classroom = ClassroomDetail(
      id: 1,
      name: 'Classroom Alpha',
      classroomCode: 'ABC-294',
      isActive: true,
      studentCount: 6,
      staff: const [
        ClassroomMembership(
          teacherId: '11111111-1111-1111-1111-111111111111',
          teacherName: 'Ms. Tan',
          teacherEmail: 'tan@example.com',
          role: 'LEAD_TEACHER',
        ),
      ],
    );

    test('produces a non-empty PDF with populated data', () async {
      final bytes = await ClassroomPdfReportBuilder.buildBytes(
        school: school,
        classroom: classroom,
        analytics: const ClassroomAnalytics(
          classroomId: 1,
          classroomName: 'Classroom Alpha',
          teacherCount: 1,
          studentCount: 6,
          averagePronunciationScore: 85,
          completionRate: 60,
        ),
        phonemes: const [
          PhonemeAnalytics(
            phoneme: 't',
            errorRate: 40,
            totalOccurrences: 5,
            affectedStudents: 2,
          ),
        ],
        recentActivity: [
          DailyTrend(
            date: DateTime(2026, 8, 26),
            attempts: 2,
            averageScore: 70,
          ),
        ],
        generatedAt: DateTime(2026, 8, 26),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('produces a PDF for a classroom with no staff or activity', () async {
      final bytes = await ClassroomPdfReportBuilder.buildBytes(
        school: school,
        classroom: ClassroomDetail(
          id: 2,
          name: 'Empty Classroom',
          classroomCode: 'ZZZ-000',
          isActive: true,
          studentCount: 0,
          staff: const [],
        ),
        analytics: null,
        phonemes: const [],
        recentActivity: const [],
        generatedAt: DateTime(2026, 8, 26),
      );

      expect(bytes, isNotEmpty);
    });
  });
}
