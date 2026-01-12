import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/marks_model.dart';

class PdfService {
  String _formatDateTime(DateTime dateTime) {
    try {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> exportClassMarksToPdf({
    required ClassModel classItem,
    required List<StudentModel> students,
    required Map<String, List<MarksModel>> studentMarksMap,
  }) async {
    // Sort students alphabetically by name
    final sortedStudents = List<StudentModel>.from(students);
    sortedStudents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final pdf = pw.Document();

    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // Add page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.purple100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    classItem.name,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Mock Exams Report',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.purple700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: $formattedDate',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Students and their marks
            ...sortedStudents.map((student) {
              final marks = studentMarksMap[student.id] ?? [];
              final mockMarks = marks.where((m) => m.assessmentType == 'mock').toList();

              // Calculate average
              double average = 0.0;
              if (mockMarks.isNotEmpty) {
                double total = 0.0;
                for (var mark in mockMarks) {
                  total += (mark.obtainedMarks / mark.totalMarks * 100);
                }
                average = total / mockMarks.length;
              }

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Student header
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(8),
                          topRight: pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            student.name,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (mockMarks.isNotEmpty)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: pw.BoxDecoration(
                                color: average >= 75
                                    ? PdfColors.green
                                    : average >= 50
                                    ? PdfColors.orange
                                    : PdfColors.red,
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              child: pw.Text(
                                'Average: ${average.toStringAsFixed(1)}%',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Marks table
                    if (mockMarks.isEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          'No mock exams recorded',
                          style: const pw.TextStyle(
                            color: PdfColors.grey600,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.grey300),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2),
                            1: const pw.FlexColumnWidth(2),
                            2: const pw.FlexColumnWidth(1.5),
                            3: const pw.FlexColumnWidth(1.5),
                          },
                          children: [
                            // Header
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.grey200,
                              ),
                              children: [
                                _buildTableCell('Mock', isHeader: true),
                                _buildTableCell('Date', isHeader: true),
                                _buildTableCell('Marks', isHeader: true),
                                _buildTableCell('Percentage', isHeader: true),
                              ],
                            ),
                            // Data rows
                            ...mockMarks.map((mark) {
                              final percentage = (mark.obtainedMarks / mark.totalMarks * 100);
                              return pw.TableRow(
                                children: [
                                  _buildTableCell(mark.assessmentName),
                                  _buildTableCell(mark.date),
                                  _buildTableCell(
                                    '${mark.obtainedMarks.toStringAsFixed(0)}/${mark.totalMarks.toStringAsFixed(0)}',
                                  ),
                                  _buildTableCell(
                                    '${percentage.toStringAsFixed(1)}%',
                                    color: percentage >= 75
                                        ? PdfColors.green700
                                        : percentage >= 50
                                        ? PdfColors.orange700
                                        : PdfColors.red700,
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 24),

            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Total Students: ${sortedStudents.length}'),
                  pw.Text(
                    'Students with Mock Exams: ${sortedStudents.where((s) => (studentMarksMap[s.id] ?? []).where((m) => m.assessmentType == 'mock').isNotEmpty).length}',
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Save and share PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/${classItem.name.replaceAll(' ', '_')}_Mock_Report.pdf');
    await file.writeAsBytes(await pdf.save());

    // Share the PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${classItem.name} - Mock Exams Report',
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}