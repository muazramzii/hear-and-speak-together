import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../parent/design/parent_theme.dart';

/// A print/share preview for a generated report PDF (Phase 6 Task 9,
/// Feature 4) - built once the bytes already exist, so the export
/// button's own loading state covers network/PDF-generation time and
/// this screen only ever renders a finished document. `PdfPreview`
/// (from `package:printing`) already provides page-scrolling, print,
/// and share out of the box - no new package, no custom viewer.
class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.bytes,
  });

  final String title;
  final String fileName;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) async => bytes,
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
