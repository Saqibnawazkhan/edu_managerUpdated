import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/attendance_model.dart';
import '../models/marks_model.dart';
import 'teacher_activity_service.dart';

// Universal import
import 'package:universal_html/html.dart' as html;
// Mobile-specific imports (will be ignored on web)
import 'dart:io' show File, Platform;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for exporting teacher activity reports to PDF and Excel
class TeacherExportService {
  /// Export attendance report to PDF
  Future<void> exportAttendanceToPdf({
    required String teacherName,
    required TeacherActivityData activityData,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final dateRangeStr =
        '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
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
                    'Teacher Attendance Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Teacher: $teacherName',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Period: $dateRangeStr',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: $formattedDate',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Overall Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Overall Summary',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatBox('Classes',
                          activityData.classes.length.toString(), PdfColors.blue),
                      _buildStatBox('Students',
                          activityData.totalStudents.toString(), PdfColors.green),
                      _buildStatBox(
                          'Records',
                          activityData.overallAttendanceStats.totalRecords
                              .toString(),
                          PdfColors.orange),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildTableCell('Status', isHeader: true),
                          _buildTableCell('Count', isHeader: true),
                          _buildTableCell('Percentage', isHeader: true),
                        ],
                      ),
                      _buildAttendanceRow(
                          'Present',
                          activityData.overallAttendanceStats.presentCount,
                          activityData.overallAttendanceStats.presentPercentage,
                          PdfColors.green700),
                      _buildAttendanceRow(
                          'Absent',
                          activityData.overallAttendanceStats.absentCount,
                          activityData.overallAttendanceStats.absentPercentage,
                          PdfColors.red700),
                      _buildAttendanceRow(
                          'Late',
                          activityData.overallAttendanceStats.lateCount,
                          activityData.overallAttendanceStats.latePercentage,
                          PdfColors.orange700),
                      _buildAttendanceRow(
                          'Leave',
                          activityData.overallAttendanceStats.leaveCount,
                          activityData.overallAttendanceStats.leavePercentage,
                          PdfColors.blue700),
                      _buildAttendanceRow(
                          'Sick',
                          activityData.overallAttendanceStats.sickCount,
                          activityData.overallAttendanceStats.sickPercentage,
                          PdfColors.purple700),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Class-wise Breakdown
            pw.Text(
              'Class-wise Breakdown',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),

            ...activityData.classes.map((classItem) {
              final classData = activityData.classActivities[classItem.id];
              if (classData == null) return pw.SizedBox();

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          classItem.name,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${classData.studentCount} students | ${classData.attendanceStats.totalRecords} records',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        _buildMiniStat('P', classData.attendanceStats.presentCount,
                            PdfColors.green),
                        pw.SizedBox(width: 8),
                        _buildMiniStat('A', classData.attendanceStats.absentCount,
                            PdfColors.red),
                        pw.SizedBox(width: 8),
                        _buildMiniStat(
                            'L', classData.attendanceStats.lateCount, PdfColors.orange),
                        pw.SizedBox(width: 8),
                        _buildMiniStat('Lv', classData.attendanceStats.leaveCount,
                            PdfColors.blue),
                        pw.SizedBox(width: 8),
                        _buildMiniStat(
                            'S', classData.attendanceStats.sickCount, PdfColors.purple),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    // Save and share PDF
    final fileName =
        '${teacherName.replaceAll(' ', '_')}_Attendance_Report.pdf';
    final pdfBytes = await pdf.save();
    await _saveAndShareFile(pdfBytes, fileName, '$teacherName - Attendance Report');
  }

  /// Export marks report to PDF
  Future<void> exportMarksToPdf({
    required String teacherName,
    required TeacherActivityData activityData,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final dateRangeStr =
        '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Teacher Marks Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Teacher: $teacherName',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Period: $dateRangeStr',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: $formattedDate',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Overall Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Overall Summary',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatBox(
                          'Total Records',
                          activityData.overallMarksStats.totalRecords.toString(),
                          PdfColors.blue),
                      _buildStatBox(
                          'Mocks',
                          activityData.overallMarksStats.mockCount.toString(),
                          PdfColors.purple),
                      _buildStatBox(
                          'Assignments',
                          activityData.overallMarksStats.assignmentCount.toString(),
                          PdfColors.orange),
                      _buildStatBox(
                          'Average',
                          '${activityData.overallMarksStats.averagePercentage.toStringAsFixed(1)}%',
                          _getPercentageColor(
                              activityData.overallMarksStats.averagePercentage)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Class-wise Breakdown
            pw.Text(
              'Class-wise Breakdown',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),

            ...activityData.classes.map((classItem) {
              final classData = activityData.classActivities[classItem.id];
              if (classData == null ||
                  classData.marksStats.totalRecords == 0) {
                return pw.SizedBox();
              }

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          classItem.name,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: _getPercentageColor(
                                classData.marksStats.averagePercentage),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Text(
                            'Avg: ${classData.marksStats.averagePercentage.toStringAsFixed(1)}%',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Records: ${classData.marksStats.totalRecords} | Mocks: ${classData.marksStats.mockCount} | Assignments: ${classData.marksStats.assignmentCount}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    if (classData.marksStats.assessments.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2),
                          1: const pw.FlexColumnWidth(1),
                          2: const pw.FlexColumnWidth(1),
                          3: const pw.FlexColumnWidth(1),
                        },
                        children: [
                          pw.TableRow(
                            decoration:
                                const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _buildTableCell('Assessment', isHeader: true),
                              _buildTableCell('Type', isHeader: true),
                              _buildTableCell('Students', isHeader: true),
                              _buildTableCell('Avg %', isHeader: true),
                            ],
                          ),
                          ...classData.marksStats.assessments
                              .where((a) => a.classId == classItem.id)
                              .map((assessment) {
                            return pw.TableRow(
                              children: [
                                _buildTableCell(assessment.assessmentName),
                                _buildTableCell(assessment.assessmentType),
                                _buildTableCell(
                                    assessment.studentCount.toString()),
                                _buildTableCell(
                                  '${assessment.averagePercentage.toStringAsFixed(1)}%',
                                  color: _getPercentageColor(
                                      assessment.averagePercentage),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    // Save and share PDF
    final fileName = '${teacherName.replaceAll(' ', '_')}_Marks_Report.pdf';
    final pdfBytes = await pdf.save();
    await _saveAndShareFile(pdfBytes, fileName, '$teacherName - Marks Report');
  }

  /// Export attendance data to Excel
  Future<void> exportAttendanceToExcel({
    required String teacherName,
    required TeacherActivityData activityData,
    required Map<String, String> classNames,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Summary Sheet
    final summarySheet = excel['Summary'];
    _addExcelHeader(
        summarySheet, ['Class', 'Students', 'Present', 'Absent', 'Late', 'Leave', 'Sick', 'Total', 'Present %']);

    int row = 1;
    for (var classItem in activityData.classes) {
      final classData = activityData.classActivities[classItem.id];
      if (classData == null) continue;

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(classItem.name);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = IntCellValue(classData.studentCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = IntCellValue(classData.attendanceStats.presentCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = IntCellValue(classData.attendanceStats.absentCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = IntCellValue(classData.attendanceStats.lateCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = IntCellValue(classData.attendanceStats.leaveCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = IntCellValue(classData.attendanceStats.sickCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = IntCellValue(classData.attendanceStats.totalRecords);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          .value = TextCellValue('${classData.attendanceStats.presentPercentage.toStringAsFixed(1)}%');
      row++;
    }

    // Set column widths for summary
    summarySheet.setColumnWidth(0, 20);
    for (var i = 1; i < 9; i++) {
      summarySheet.setColumnWidth(i, 12);
    }

    // Details Sheet
    final detailsSheet = excel['Details'];
    _addExcelHeader(
        detailsSheet, ['Date', 'Class', 'Student', 'Status', 'Session']);

    row = 1;
    final sortedRecords = List<AttendanceModel>.from(activityData.allAttendanceRecords);
    sortedRecords.sort((a, b) => b.date.compareTo(a.date));

    for (var record in sortedRecords) {
      final className = classNames[record.classId] ?? record.classId;
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(DateFormat('dd/MM/yyyy').format(record.date));
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(className);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(record.studentName);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(record.status);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(record.sessionName ?? record.time ?? '-');
      row++;
    }

    // Set column widths for details
    detailsSheet.setColumnWidth(0, 12);
    detailsSheet.setColumnWidth(1, 15);
    detailsSheet.setColumnWidth(2, 20);
    detailsSheet.setColumnWidth(3, 10);
    detailsSheet.setColumnWidth(4, 15);

    // Save and share Excel
    final fileName =
        '${teacherName.replaceAll(' ', '_')}_Attendance_Data.xlsx';
    final bytes = excel.encode();
    if (bytes != null) {
      await _saveAndShareFile(Uint8List.fromList(bytes), fileName, '$teacherName - Attendance Data');
    }
  }

  /// Export marks data to Excel
  Future<void> exportMarksToExcel({
    required String teacherName,
    required TeacherActivityData activityData,
    required Map<String, String> classNames,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Summary Sheet
    final summarySheet = excel['Summary'];
    _addExcelHeader(
        summarySheet, ['Class', 'Total Records', 'Mocks', 'Assignments', 'Average %']);

    int row = 1;
    for (var classItem in activityData.classes) {
      final classData = activityData.classActivities[classItem.id];
      if (classData == null || classData.marksStats.totalRecords == 0) continue;

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(classItem.name);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = IntCellValue(classData.marksStats.totalRecords);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = IntCellValue(classData.marksStats.mockCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = IntCellValue(classData.marksStats.assignmentCount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue('${classData.marksStats.averagePercentage.toStringAsFixed(1)}%');
      row++;
    }

    // Set column widths for summary
    summarySheet.setColumnWidth(0, 20);
    for (var i = 1; i < 5; i++) {
      summarySheet.setColumnWidth(i, 15);
    }

    // Details Sheet
    final detailsSheet = excel['Details'];
    _addExcelHeader(detailsSheet,
        ['Date', 'Class', 'Assessment', 'Type', 'Student', 'Obtained', 'Total', '%']);

    row = 1;
    // Sort by date (parsing from dd/MM/yyyy format)
    final sortedRecords = List<MarksModel>.from(activityData.allMarksRecords);
    sortedRecords.sort((a, b) {
      try {
        final partsA = a.date.split('/');
        final partsB = b.date.split('/');
        final dateA = DateTime(
            int.parse(partsA[2]), int.parse(partsA[1]), int.parse(partsA[0]));
        final dateB = DateTime(
            int.parse(partsB[2]), int.parse(partsB[1]), int.parse(partsB[0]));
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    for (var record in sortedRecords) {
      final className = classNames[record.classId] ?? record.classId;
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(record.date);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(className);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(record.assessmentName);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(record.assessmentType);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(record.id); // StudentId - would need name lookup
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = DoubleCellValue(record.obtainedMarks);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = DoubleCellValue(record.totalMarks);
      detailsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = TextCellValue('${record.percentage.toStringAsFixed(1)}%');
      row++;
    }

    // Set column widths for details
    detailsSheet.setColumnWidth(0, 12);
    detailsSheet.setColumnWidth(1, 15);
    detailsSheet.setColumnWidth(2, 15);
    detailsSheet.setColumnWidth(3, 12);
    detailsSheet.setColumnWidth(4, 20);
    detailsSheet.setColumnWidth(5, 10);
    detailsSheet.setColumnWidth(6, 10);
    detailsSheet.setColumnWidth(7, 10);

    // Save and share Excel
    final fileName = '${teacherName.replaceAll(' ', '_')}_Marks_Data.xlsx';
    final bytes = excel.encode();
    if (bytes != null) {
      await _saveAndShareFile(Uint8List.fromList(bytes), fileName, '$teacherName - Marks Data');
    }
  }

  // Helper methods for PDF generation
  pw.Widget _buildTableCell(String text,
      {bool isHeader = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  pw.TableRow _buildAttendanceRow(
      String label, int count, double percentage, PdfColor color) {
    return pw.TableRow(
      children: [
        _buildTableCell(label),
        _buildTableCell(count.toString()),
        _buildTableCell('${percentage.toStringAsFixed(1)}%', color: color),
      ],
    );
  }

  pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.9),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMiniStat(String label, int count, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color.shade(0.9),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        '$label: $count',
        style: pw.TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  PdfColor _getPercentageColor(double percentage) {
    if (percentage >= 75) return PdfColors.green;
    if (percentage >= 50) return PdfColors.orange;
    return PdfColors.red;
  }

  // Helper method for Excel header
  void _addExcelHeader(Sheet sheet, List<String> headers) {
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#9D8FFF'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
  }

  /// Platform-aware file save and share
  /// Handles both mobile (share) and web (download) platforms
  Future<void> _saveAndShareFile(
    Uint8List bytes,
    String fileName,
    String subject,
  ) async {
    if (kIsWeb) {
      // Web: Download file directly
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile: Use share functionality
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: subject);
    }
  }
}
