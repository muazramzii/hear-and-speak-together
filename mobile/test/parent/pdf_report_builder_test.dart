import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/features/parent/reports/pdf_report_builder.dart';
import 'package:hear_speak_together/models/progress.dart';
import 'package:hear_speak_together/repositories/students_repository.dart';

SupervisedStudent _student({String name = 'Ali'}) {
  return SupervisedStudent.fromJson({
    'id': 1,
    'name': name,
    'avatar': 'BOY_1',
    'language_code': 'en',
    'level': 3,
    'points': 230,
    'streak_days': 5,
    'summary': {'average_score': 82},
  });
}

ProgressReport _report() {
  return ProgressReport.fromJson(const {
    'summary': {'average_score': 82, 'practice_sessions': 12, 'lessons_completed': 3},
    'categories': [
      {'category_id': 1, 'name': 'Animals', 'average_score': 91, 'is_weak': false},
      {'category_id': 2, 'name': 'Food', 'average_score': 60, 'is_weak': true},
    ],
    'trend': [
      {'date': '2026-08-24', 'average_score': 82, 'attempts': 3},
    ],
    'phonemes': {
      'weak': [
        {
          'phoneme': 'l',
          'frequency': 68,
          'occurrences': 6,
          'sample_size': 9,
          'examples': ['bola', 'belon'],
        },
      ],
      'strong': [
        {'phoneme': 'k', 'frequency': 0, 'occurrences': 0, 'sample_size': 4, 'examples': []},
      ],
    },
    'weekly_comparison': {
      'this_week': {'average_score': 82, 'attempts': 3, 'words_completed': 2},
      'last_week': {'average_score': 75, 'attempts': 2, 'words_completed': 1},
      'score_change': 7,
      'attempts_change': 1,
      'words_completed_change': 1,
      'streak_days': 5,
    },
    'recommendations': [
      {
        'type': 'practise_words',
        'reason': 'below_target_score',
        'words': [
          {'word_id': 3, 'text': 'gajah', 'lesson_id': 2, 'average_score': 55, 'attempts': 3},
        ],
      },
    ],
  });
}

void main() {
  group('PdfReportBuilder.fileName', () {
    test('is a safe, deterministic filename', () {
      final name = PdfReportBuilder.fileName(
        _student(name: 'Ali Bin Ahmad'),
        DateTime(2026, 8, 24),
      );

      expect(name, 'hear_speak_report_Ali_Bin_Ahmad_20260824.pdf');
    });

    test('strips characters that are unsafe in a filename', () {
      final name = PdfReportBuilder.fileName(
        _student(name: "O'Brien/Test"),
        DateTime(2026, 1, 5),
      );

      expect(name, isNot(contains("'")));
      expect(name, isNot(contains('/')));
    });
  });

  group('PdfReportBuilder.buildDocument', () {
    test('produces a non-empty PDF for a full report', () async {
      final doc = await PdfReportBuilder.buildDocument(
        student: _student(),
        report: _report(),
        generatedAt: DateTime(2026, 8, 24),
      );
      final bytes = await doc.save();

      expect(bytes, isNotEmpty);
      // The PDF file signature - proof this is a real PDF, not empty bytes.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('does not throw for a learner with no data yet', () async {
      final emptyReport = ProgressReport.fromJson(const {});

      final doc = await PdfReportBuilder.buildDocument(
        student: _student(),
        report: emptyReport,
        generatedAt: DateTime(2026, 8, 24),
      );
      final bytes = await doc.save();

      expect(bytes, isNotEmpty);
    });
  });
}
