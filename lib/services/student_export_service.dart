import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import '../models/class_model.dart';
import '../models/student_model.dart';

/// Result class for import operations
class ImportResult {
  final List<Map<String, String>>? students;
  final String? error;

  ImportResult({this.students, this.error});

  bool get isSuccess => students != null && students!.isNotEmpty;
}

class StudentExportService {
  /// Export students list to PDF
  Future<void> exportStudentsToPdf({
    required ClassModel classItem,
    required List<StudentModel> students,
  }) async {
    // Sort students alphabetically
    final sortedStudents = List<StudentModel>.from(students);
    sortedStudents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final pdf = pw.Document();

    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

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
                    classItem.name,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Student List',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.purple700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Generated on: $formattedDate',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Total Students: ${sortedStudents.length}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Student Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.purple100,
                  ),
                  children: [
                    _buildTableCell('S.No', isHeader: true),
                    _buildTableCell('Student Name', isHeader: true),
                    _buildTableCell('Phone', isHeader: true),
                    _buildTableCell('Father Phone', isHeader: true),
                    _buildTableCell('Mother Phone', isHeader: true),
                  ],
                ),
                // Data Rows
                ...sortedStudents.asMap().entries.map((entry) {
                  final index = entry.key;
                  final student = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      _buildTableCell('${index + 1}'),
                      _buildTableCell(student.name),
                      _buildTableCell(student.phoneNo.isNotEmpty ? student.phoneNo : '-'),
                      _buildTableCell(student.fatherPhNo.isNotEmpty ? student.fatherPhNo : '-'),
                      _buildTableCell(student.motherPhNo.isNotEmpty ? student.motherPhNo : '-'),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 24),

            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Class: ${classItem.name}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Total Strength: ${sortedStudents.length}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
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
    final fileName = '${classItem.name.replaceAll(' ', '_')}_Students.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${classItem.name} - Student List',
    );
  }

  /// Export students list to Excel
  Future<void> exportStudentsToExcel({
    required ClassModel classItem,
    required List<StudentModel> students,
  }) async {
    // Sort students alphabetically
    final sortedStudents = List<StudentModel>.from(students);
    sortedStudents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final excel = Excel.createExcel();
    final sheetName = classItem.name.length > 31
        ? classItem.name.substring(0, 31)
        : classItem.name;

    // Remove default sheet and create new one
    excel.delete('Sheet1');
    final sheet = excel[sheetName];

    // Header style
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#9D8FFF'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Add headers
    final headers = ['S.No', 'Student Name', 'Phone', 'Father Phone', 'Mother Phone'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Add student data
    for (var i = 0; i < sortedStudents.length; i++) {
      final student = sortedStudents[i];
      final rowIndex = i + 1;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue('${i + 1}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(student.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(student.phoneNo);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(student.fatherPhNo);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(student.motherPhNo);
    }

    // Set column widths
    sheet.setColumnWidth(0, 8);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);

    // Save and share Excel
    final output = await getTemporaryDirectory();
    final fileName = '${classItem.name.replaceAll(' ', '_')}_Students.xlsx';
    final file = File('${output.path}/$fileName');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${classItem.name} - Student List',
      );
    }
  }

  /// Import students from Excel or PDF file
  /// Returns a result object with either students list or error message
  Future<ImportResult> importStudentsFromExcel() async {
    try {
      // Clear any previous FilePicker cache
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {
      // Ignore clear errors
    }

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'pdf'],
        allowMultiple: false,
        withData: true,
      );
    } catch (e) {
      // If custom type fails, try with any type
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
          withData: true,
        );
      } catch (e2) {
        return ImportResult(error: 'Could not open file picker. Please restart the app and try again.');
      }
    }

    if (result == null || result.files.isEmpty) {
      return ImportResult(error: 'No file selected');
    }

    final pickedFile = result.files.single;
    final extension = pickedFile.extension?.toLowerCase() ?? '';

    // Validate file type
    if (!['xlsx', 'xls', 'pdf'].contains(extension)) {
      return ImportResult(error: 'Unsupported file type. Please select an Excel (.xlsx, .xls) or PDF file.');
    }

    // Get bytes - either from bytes property or read from path
    List<int>? bytes;
    try {
      if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
        bytes = pickedFile.bytes!;
      } else if (pickedFile.path != null) {
        final file = File(pickedFile.path!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }
    } catch (e) {
      return ImportResult(error: 'Could not read file: ${e.toString()}');
    }

    if (bytes == null || bytes.isEmpty) {
      return ImportResult(error: 'Could not read file. Please try copying the file to Downloads folder first.');
    }

    // Route to appropriate parser based on file type
    if (extension == 'pdf') {
      return _parseStudentsFromPdf(bytes);
    } else {
      return _parseStudentsFromExcel(bytes);
    }
  }

  /// Parse students from PDF file
  ImportResult _parseStudentsFromPdf(List<int> bytes) {
    try {
      final sf_pdf.PdfDocument document = sf_pdf.PdfDocument(inputBytes: bytes);

      // Extract text from all pages
      String fullText = '';
      for (int i = 0; i < document.pages.count; i++) {
        final sf_pdf.PdfTextExtractor extractor = sf_pdf.PdfTextExtractor(document);
        fullText += extractor.extractText(startPageIndex: i, endPageIndex: i) + '\n';
      }
      document.dispose();

      if (fullText.trim().isEmpty) {
        return ImportResult(error: 'No text found in PDF. Make sure the PDF is not image-based.');
      }

      // Parse students from extracted text
      final students = _extractStudentsFromText(fullText);

      if (students.isEmpty) {
        return ImportResult(
          error: 'No student names found. Text found: "${fullText.substring(0, fullText.length > 200 ? 200 : fullText.length)}..."'
        );
      }

      return ImportResult(students: students);
    } catch (e) {
      return ImportResult(error: 'Error reading PDF: ${e.toString()}');
    }
  }

  /// Extract student names from text (PDF)
  List<Map<String, String>> _extractStudentsFromText(String text) {
    final List<Map<String, String>> students = [];

    // Split by newlines
    final lines = text.split(RegExp(r'[\n\r]+'));

    // Pattern: Numbered list (1. Name, 1) Name, etc.)
    final numberedPattern = RegExp(r'^\s*\d+[\.\)\-\s]+(.+)$');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      String? name;

      // Try numbered pattern first
      final numberedMatch = numberedPattern.firstMatch(line);
      if (numberedMatch != null) {
        name = numberedMatch.group(1)?.trim();
      }

      // Skip headers and common non-name lines
      if (name == null) {
        final lowerLine = line.toLowerCase();
        if (lowerLine.contains('student') && (lowerLine.contains('name') || lowerLine.contains('list'))) {
          continue; // Skip header lines
        }
        if (lowerLine.contains('s.no') || lowerLine.contains('sr.no') || lowerLine.contains('serial')) {
          continue; // Skip serial number headers
        }
        if (lowerLine.contains('phone') || lowerLine.contains('mobile') || lowerLine.contains('contact')) {
          continue; // Skip phone headers
        }
        if (lowerLine.contains('class') || lowerLine.contains('total') || lowerLine.contains('generated')) {
          continue; // Skip class info lines
        }

        // If line is not a header and contains letters, it might be a name
        if (RegExp(r'[a-zA-Z]').hasMatch(line)) {
          // Skip if it looks like a pure number
          if (double.tryParse(line.replaceAll(RegExp(r'\s'), '')) != null) {
            continue;
          }
          // Skip very short lines (likely not names)
          if (line.length < 2) continue;

          // Use the whole line as a potential name
          name = line;
        }
      }

      if (name != null && name.isNotEmpty) {
        // Clean up the name
        name = name.replaceAll(RegExp(r'^\d+[\.\)\-\s]*'), '').trim(); // Remove leading numbers
        name = name.replaceAll(RegExp(r'\s+'), ' '); // Normalize spaces

        // Skip if still looks like a number or too short
        if (name.isEmpty || name.length < 2) continue;
        if (double.tryParse(name) != null) continue;

        // Add only if we don't already have this name
        final exists = students.any((s) => s['name']?.toLowerCase() == name!.toLowerCase());
        if (!exists) {
          students.add({
            'name': name,
            'phone': '',
            'fatherPhone': '',
            'motherPhone': '',
          });
        }
      }
    }

    return students;
  }

  /// Parse students from Excel file
  ImportResult _parseStudentsFromExcel(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        return ImportResult(error: 'No sheets found in Excel file');
      }

      final List<Map<String, String>> students = [];

      // Get the first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        return ImportResult(error: 'Sheet is empty');
      }

      // Find column indices based on headers (first row)
      int nameCol = -1;
      int phoneCol = -1;
      int fatherPhoneCol = -1;
      int motherPhoneCol = -1;

      final headerRow = sheet.rows.first;
      List<String> foundHeaders = [];

      for (var i = 0; i < headerRow.length; i++) {
        final cell = headerRow[i];
        if (cell == null) continue;

        final cellValue = cell.value?.toString().toLowerCase() ?? '';
        if (cellValue.isNotEmpty) {
          foundHeaders.add(cellValue);
        }

        // Check for name column (but not father/mother name)
        if (nameCol == -1 &&
            (cellValue.contains('name') || cellValue.contains('student')) &&
            !cellValue.contains('father') && !cellValue.contains('mother')) {
          nameCol = i;
        }
        // Check for student phone (not father/mother)
        else if (phoneCol == -1 &&
            (cellValue.contains('phone') || cellValue.contains('mobile') || cellValue.contains('contact')) &&
            !cellValue.contains('father') && !cellValue.contains('mother')) {
          phoneCol = i;
        }
        // Check for father phone
        else if (fatherPhoneCol == -1 && cellValue.contains('father')) {
          fatherPhoneCol = i;
        }
        // Check for mother phone
        else if (motherPhoneCol == -1 && cellValue.contains('mother')) {
          motherPhoneCol = i;
        }
      }

      // If no name column found by header, try to detect from data
      if (nameCol == -1) {
        for (var i = 0; i < headerRow.length && i < 5; i++) {
          final cellValue = headerRow[i]?.value?.toString().toLowerCase() ?? '';
          if (!cellValue.contains('s.no') && !cellValue.contains('sr') &&
              !cellValue.contains('no.') && !cellValue.contains('sl') &&
              !cellValue.contains('#') && cellValue.isNotEmpty) {
            nameCol = i;
            break;
          }
        }
        if (nameCol == -1) {
          nameCol = headerRow.length > 1 ? 1 : 0;
        }
      }

      // Skip header row and process data rows
      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        bool hasData = row.any((cell) =>
          cell != null && cell.value != null && cell.value.toString().trim().isNotEmpty
        );
        if (!hasData) continue;

        String name = '';
        if (nameCol >= 0 && nameCol < row.length && row[nameCol] != null) {
          name = row[nameCol]!.value?.toString().trim() ?? '';
        }

        if (name.isEmpty) continue;
        if (double.tryParse(name) != null && name.length < 4) continue;

        String phone = '';
        if (phoneCol >= 0 && phoneCol < row.length && row[phoneCol] != null) {
          phone = row[phoneCol]!.value?.toString().trim() ?? '';
        }

        String fatherPhone = '';
        if (fatherPhoneCol >= 0 && fatherPhoneCol < row.length && row[fatherPhoneCol] != null) {
          fatherPhone = row[fatherPhoneCol]!.value?.toString().trim() ?? '';
        }

        String motherPhone = '';
        if (motherPhoneCol >= 0 && motherPhoneCol < row.length && row[motherPhoneCol] != null) {
          motherPhone = row[motherPhoneCol]!.value?.toString().trim() ?? '';
        }

        students.add({
          'name': name,
          'phone': phone,
          'fatherPhone': fatherPhone,
          'motherPhone': motherPhone,
        });
      }

      if (students.isEmpty) {
        String headerInfo = foundHeaders.isNotEmpty
            ? 'Found headers: ${foundHeaders.join(", ")}'
            : 'No headers detected';
        return ImportResult(
          error: 'No students found in file. $headerInfo. Make sure first row has column headers like "Student Name" or "Name".'
        );
      }

      return ImportResult(students: students);
    } catch (e) {
      return ImportResult(error: 'Error reading Excel file: ${e.toString()}');
    }
  }

  /// Create a sample Excel template for importing students
  Future<void> downloadSampleTemplate() async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Students'];

    // Header style
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#9D8FFF'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Add headers
    final headers = ['S.No', 'Student Name', 'Phone', 'Father Phone', 'Mother Phone'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Add sample data
    final sampleData = [
      ['1', 'John Doe', '9876543210', '9876543211', '9876543212'],
      ['2', 'Jane Smith', '9876543213', '9876543214', '9876543215'],
      ['3', 'Mike Johnson', '9876543216', '9876543217', '9876543218'],
    ];

    for (var i = 0; i < sampleData.length; i++) {
      for (var j = 0; j < sampleData[i].length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
            .value = TextCellValue(sampleData[i][j]);
      }
    }

    // Set column widths
    sheet.setColumnWidth(0, 8);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);

    // Save and share template
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Student_Import_Template.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Student Import Template',
      );
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
