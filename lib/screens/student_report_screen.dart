import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/student_model.dart';
import '../models/class_model.dart';
import '../models/marks_model.dart';
import '../services/marks_service.dart';
import '../utils/app_theme.dart';
import 'edit_single_mark_screen.dart';

class StudentReportScreen extends StatefulWidget {
  final StudentModel student;
  final ClassModel classItem;

  const StudentReportScreen({
    super.key,
    required this.student,
    required this.classItem,
  });

  @override
  State<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends State<StudentReportScreen> {
  String _selectedFilter = 'all';

  void _showSnackBar(String message, Color color, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showWhatsAppRecipientDialog(List<MarksModel> allMarks) {
    HapticFeedback.mediumImpact();

    final hasFatherPhone = widget.student.fatherPhNo != null && widget.student.fatherPhNo!.isNotEmpty;
    final hasMotherPhone = widget.student.motherPhNo != null && widget.student.motherPhNo!.isNotEmpty;
    final hasStudentPhone = widget.student.phoneNo.isNotEmpty;

    if (!hasFatherPhone && !hasMotherPhone && !hasStudentPhone) {
      _showSnackBar('No phone numbers available for this student', Colors.orange, isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Color(0xFF25D366),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Send Report To'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFatherPhone)
              _buildRecipientOption(
                icon: Icons.person,
                label: "Father's WhatsApp",
                subtitle: widget.student.fatherPhNo!,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _sendMarksReportViaWhatsApp(widget.student.fatherPhNo!, allMarks);
                },
              ),
            if (hasFatherPhone && (hasMotherPhone || hasStudentPhone))
              const SizedBox(height: 12),
            if (hasMotherPhone)
              _buildRecipientOption(
                icon: Icons.person,
                label: "Mother's WhatsApp",
                subtitle: widget.student.motherPhNo!,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _sendMarksReportViaWhatsApp(widget.student.motherPhNo!, allMarks);
                },
              ),
            if (hasMotherPhone && hasStudentPhone)
              const SizedBox(height: 12),
            if (hasStudentPhone)
              _buildRecipientOption(
                icon: Icons.school,
                label: "Student's WhatsApp",
                subtitle: widget.student.phoneNo,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _sendMarksReportViaWhatsApp(widget.student.phoneNo, allMarks);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogContext);
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF25D366), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF25D366)),
          ],
        ),
      ),
    );
  }

  String _formatPhoneNumber(String phoneNumber) {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanNumber.startsWith('+')) {
      if (cleanNumber.startsWith('0')) {
        cleanNumber = '92${cleanNumber.substring(1)}';
      } else {
        cleanNumber = '92$cleanNumber';
      }
    }
    return cleanNumber;
  }

  Future<void> _sendMarksReportViaWhatsApp(String phoneNumber, List<MarksModel> allMarks) async {
    final formattedPhone = _formatPhoneNumber(phoneNumber);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF25D366)),
                SizedBox(height: 16),
                Text('Generating PDF...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Generate PDF using existing method
      final pdfFile = await _generateMarksPdf(allMarks);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Calculate overall average for message
      double overallAverage = 0.0;
      if (allMarks.isNotEmpty) {
        double total = 0.0;
        for (var mark in allMarks) {
          total += (mark.obtainedMarks / mark.totalMarks * 100);
        }
        overallAverage = total / allMarks.length;
      }

      // Create message text
      final message = Uri.encodeComponent(
        'Academic Report Card for ${widget.student.name}\n'
        'Class: ${widget.classItem.name}\n'
        'Overall Average: ${overallAverage.toStringAsFixed(1)}%\n\n'
        'Please check the PDF attachment.'
      );

      // Open WhatsApp directly with the contact
      final whatsappUrl = Uri.parse('https://wa.me/$formattedPhone?text=$message');

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);

        // Show instruction to attach PDF
        _showSnackBar('WhatsApp opened! Tap 📎 to attach the PDF from Downloads', const Color(0xFF25D366));

        // Share PDF so user can easily attach it
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'Academic Report Card',
        );
      } else {
        _showSnackBar('WhatsApp is not installed', Colors.orange, isError: true);
      }

      HapticFeedback.lightImpact();
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error: $e', Colors.red, isError: true);
    }
  }

  String _getGradeFromPercentage(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    if (percentage >= 40) return 'E';
    return 'U';
  }

  PdfColor _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
        return PdfColors.green800;
      case 'A':
        return PdfColors.green700;
      case 'B':
        return PdfColors.blue700;
      case 'C':
        return PdfColors.orange700;
      case 'D':
        return PdfColors.orange900;
      case 'E':
        return PdfColors.amber900;
      default:
        return PdfColors.red700;
    }
  }

  Color _getGradeColorUI(String grade) {
    switch (grade) {
      case 'A+':
        return const Color(0xFF2E7D32); // Dark green
      case 'A':
        return const Color(0xFF388E3C); // Green
      case 'B':
        return const Color(0xFF1976D2); // Blue
      case 'C':
        return const Color(0xFFF57C00); // Orange
      case 'D':
        return const Color(0xFFE64A19); // Dark orange
      case 'E':
        return const Color(0xFFF9A825); // Amber
      default:
        return const Color(0xFFC62828); // Red
    }
  }

  Future<File> _generateMarksPdf(List<MarksModel> allMarks) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year}';

    // Calculate averages
    final mockMarks = allMarks.where((m) => m.assessmentType == 'mock').toList();
    final assignmentMarks = allMarks.where((m) => m.assessmentType == 'assignment').toList();

    // Sort by date (oldest first)
    mockMarks.sort((a, b) {
      try {
        final dateA = DateFormat('dd/MM/yyyy').parse(a.date);
        final dateB = DateFormat('dd/MM/yyyy').parse(b.date);
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    assignmentMarks.sort((a, b) {
      try {
        final dateA = DateFormat('dd/MM/yyyy').parse(a.date);
        final dateB = DateFormat('dd/MM/yyyy').parse(b.date);
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    double mockAverage = 0.0;
    if (mockMarks.isNotEmpty) {
      double total = 0.0;
      for (var mark in mockMarks) {
        total += (mark.obtainedMarks / mark.totalMarks * 100);
      }
      mockAverage = total / mockMarks.length;
    }

    double assignmentAverage = 0.0;
    if (assignmentMarks.isNotEmpty) {
      double total = 0.0;
      for (var mark in assignmentMarks) {
        total += (mark.obtainedMarks / mark.totalMarks * 100);
      }
      assignmentAverage = total / assignmentMarks.length;
    }

    double overallAverage = 0.0;
    if (allMarks.isNotEmpty) {
      double total = 0.0;
      for (var mark in allMarks) {
        total += (mark.obtainedMarks / mark.totalMarks * 100);
      }
      overallAverage = total / allMarks.length;
    }

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
                    'Student Report Card',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    widget.student.name,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Class: ${widget.classItem.name}',
                    style: const pw.TextStyle(fontSize: 12),
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

            // Overall Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: overallAverage >= 80
                    ? PdfColors.green100
                    : overallAverage >= 60
                    ? PdfColors.orange100
                    : overallAverage >= 40
                    ? PdfColors.amber100
                    : PdfColors.red100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(
                  color: overallAverage >= 80
                      ? PdfColors.green
                      : overallAverage >= 60
                      ? PdfColors.orange
                      : overallAverage >= 40
                      ? PdfColors.amber
                      : PdfColors.red,
                  width: 2,
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        '${overallAverage.toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Overall Average'),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: _getGradeColor(_getGradeFromPercentage(overallAverage)),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          _getGradeFromPercentage(overallAverage),
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Grade'),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        '${allMarks.length}',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Total Assessments'),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Assessment Type Averages
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.purple50,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Mock Average',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          mockMarks.isEmpty ? 'N/A' : '${mockAverage.toStringAsFixed(1)}%',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.purple900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Assignment Average',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          assignmentMarks.isEmpty ? 'N/A' : '${assignmentAverage.toStringAsFixed(1)}%',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Mock Exams Section
            if (mockMarks.isNotEmpty) ...[
              pw.Text(
                'Mock Exams',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Assessment', isHeader: true),
                      _buildTableCell('Date', isHeader: true),
                      _buildTableCell('Marks', isHeader: true),
                      _buildTableCell('Percentage', isHeader: true),
                      _buildTableCell('Grade', isHeader: true),
                    ],
                  ),
                  ...mockMarks.map((mark) {
                    final percentage = (mark.obtainedMarks / mark.totalMarks * 100);
                    final grade = _getGradeFromPercentage(percentage);
                    return pw.TableRow(
                      children: [
                        _buildTableCell(mark.assessmentName),
                        _buildTableCell(mark.date),
                        _buildTableCell(
                          '${mark.obtainedMarks.toStringAsFixed(0)}/${mark.totalMarks.toStringAsFixed(0)}',
                        ),
                        _buildTableCell(
                          '${percentage.toStringAsFixed(1)}%',
                          color: percentage >= 80
                              ? PdfColors.green700
                              : percentage >= 60
                              ? PdfColors.orange700
                              : percentage >= 40
                              ? PdfColors.amber700
                              : PdfColors.red700,
                        ),
                        _buildTableCell(
                          grade,
                          color: _getGradeColor(grade),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // Assignments Section
            if (assignmentMarks.isNotEmpty) ...[
              pw.Text(
                'Assignments',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Assessment', isHeader: true),
                      _buildTableCell('Date', isHeader: true),
                      _buildTableCell('Marks', isHeader: true),
                      _buildTableCell('Percentage', isHeader: true),
                      _buildTableCell('Grade', isHeader: true),
                    ],
                  ),
                  ...assignmentMarks.map((mark) {
                    final percentage = (mark.obtainedMarks / mark.totalMarks * 100);
                    final grade = _getGradeFromPercentage(percentage);
                    return pw.TableRow(
                      children: [
                        _buildTableCell(mark.assessmentName),
                        _buildTableCell(mark.date),
                        _buildTableCell(
                          '${mark.obtainedMarks.toStringAsFixed(0)}/${mark.totalMarks.toStringAsFixed(0)}',
                        ),
                        _buildTableCell(
                          '${percentage.toStringAsFixed(1)}%',
                          color: percentage >= 80
                              ? PdfColors.green700
                              : percentage >= 60
                              ? PdfColors.orange700
                              : percentage >= 40
                              ? PdfColors.amber700
                              : PdfColors.red700,
                        ),
                        _buildTableCell(
                          grade,
                          color: _getGradeColor(grade),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],

            pw.SizedBox(height: 32),

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
                    'Grading Scale',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('A+: 90% - 100%', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('A: 80% - 89%', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('B: 70% - 79%', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('C: 60% - 69%', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('D: 50% - 59%', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('E: 40% - 49%', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('U: 0% - 39%', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      'Generated by Edu Manager',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Save PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/${widget.student.name}_Report_Card.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  Future<void> _exportToPdf(List<MarksModel> allMarks) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Use the shared PDF generation method
      final file = await _generateMarksPdf(allMarks);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Share the PDF
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '${widget.student.name} - Report Card',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF exported successfully!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final marksService = Provider.of<MarksService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.name,
                          style: AppTheme.heading2,
                        ),
                        Text(
                          'Report Card',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Student Info Card with Export Button
            StreamBuilder<List<MarksModel>>(
              stream: marksService.getStudentMarks(widget.student.id),
              builder: (context, marksSnapshot) {
                final allMarks = marksSnapshot.data ?? [];

                // Calculate average
                double average = 0.0;
                if (allMarks.isNotEmpty) {
                  double total = 0.0;
                  for (var mark in allMarks) {
                    total += (mark.obtainedMarks / mark.totalMarks * 100);
                  }
                  average = total / allMarks.length;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          child: Text(
                            widget.student.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.student.name,
                                style: AppTheme.heading2.copyWith(color: Colors.white),
                              ),
                              Text(
                                widget.classItem.name,
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${average.toStringAsFixed(1)}%',
                                    style: AppTheme.heading3.copyWith(
                                      color: average >= 80
                                          ? AppTheme.success
                                          : average >= 60
                                          ? AppTheme.warning
                                          : average >= 40
                                          ? const Color(0xFFFF9800)
                                          : AppTheme.error,
                                    ),
                                  ),
                                  Text(
                                    'Average',
                                    style: AppTheme.caption,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getGradeColorUI(_getGradeFromPercentage(average)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getGradeFromPercentage(average),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Action Buttons Row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // WhatsApp Button
                                IconButton(
                                  onPressed: allMarks.isEmpty ? null : () => _showWhatsAppRecipientDialog(allMarks),
                                  icon: const Icon(Icons.chat_rounded),
                                  color: Colors.white,
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366).withOpacity(0.8),
                                  ),
                                  tooltip: 'Send via WhatsApp',
                                ),
                                const SizedBox(width: 8),
                                // Export PDF Button
                                IconButton(
                                  onPressed: allMarks.isEmpty ? null : () => _exportToPdf(allMarks),
                                  icon: const Icon(Icons.picture_as_pdf),
                                  color: Colors.white,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                  ),
                                  tooltip: 'Export to PDF',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Filter Tabs - Only Mock and Assignment
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Mock', 'mock'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Assignment', 'assignment'),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Marks List
            Expanded(
              child: StreamBuilder<List<MarksModel>>(
                stream: marksService.getStudentMarks(widget.student.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grade_outlined,
                            size: 80,
                            color: AppTheme.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            'No marks recorded yet',
                            style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  var marks = snapshot.data!;

                  // Filter by assessment type
                  if (_selectedFilter != 'all') {
                    marks = marks.where((m) => m.assessmentType == _selectedFilter).toList();
                  }

                  // Sort by date (oldest first)
                  marks.sort((a, b) {
                    try {
                      final dateA = DateFormat('dd/MM/yyyy').parse(a.date);
                      final dateB = DateFormat('dd/MM/yyyy').parse(b.date);
                      return dateA.compareTo(dateB);
                    } catch (e) {
                      return 0;
                    }
                  });

                  if (marks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list_off,
                            size: 80,
                            color: AppTheme.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            'No $_selectedFilter marks found',
                            style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Table Header
                      Container(
                        margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, AppTheme.spacing16, AppTheme.spacing16, 8),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Assessment',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Date',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryPurple,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Marks',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryPurple,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '%',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryPurple,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Container(
                                width: 60,
                                alignment: Alignment.center,
                                child: Text(
                                  'Grade',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryPurple,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Marks List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, AppTheme.spacing16, AppTheme.spacing16),
                          itemCount: marks.length,
                          itemBuilder: (context, index) {
                      final mark = marks[index];
                      final percentage = mark.percentage;

                      Color cardColor;
                      switch (mark.assessmentType) {
                        case 'mock':
                          cardColor = AppTheme.lightPurple;
                          break;
                        case 'assignment':
                          cardColor = AppTheme.lightBlue;
                          break;
                        default:
                          cardColor = AppTheme.lightGreen;
                      }

                      return Dismissible(
                        key: Key(mark.id),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          alignment: Alignment.centerRight,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Delete Marks'),
                                content: const Text('Are you sure you want to delete this record?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) async {
                          await marksService.deleteMarks(mark.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Marks deleted'),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                // Assessment Name
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      mark.assessmentName,
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                // Date
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: AppTheme.borderGrey, width: 1),
                                      ),
                                    ),
                                    child: Text(
                                      mark.date,
                                      style: AppTheme.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                // Marks
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: AppTheme.borderGrey, width: 1),
                                      ),
                                    ),
                                    child: Text(
                                      '${mark.obtainedMarks.toStringAsFixed(0)}/${mark.totalMarks.toStringAsFixed(0)}',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                // Percentage
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: AppTheme.borderGrey, width: 1),
                                      ),
                                    ),
                                    child: Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: percentage >= 80
                                            ? AppTheme.success
                                            : percentage >= 60
                                            ? AppTheme.warning
                                            : percentage >= 40
                                            ? const Color(0xFFFF9800)
                                            : AppTheme.error,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                // Grade
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _getGradeColorUI(_getGradeFromPercentage(percentage)),
                                    border: Border(
                                      left: BorderSide(color: AppTheme.borderGrey, width: 1),
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(AppTheme.radiusMedium),
                                      bottomRight: Radius.circular(AppTheme.radiusMedium),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _getGradeFromPercentage(percentage),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EditSingleMarkScreen(
                                                classItem: widget.classItem,
                                                markToEdit: mark,
                                                studentName: widget.student.name,
                                              ),
                                            ),
                                          );
                                          setState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: AppTheme.primaryPurple,
      backgroundColor: AppTheme.cardWhite,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textDark,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryPurple : AppTheme.borderGrey,
        ),
      ),
    );
  }
}