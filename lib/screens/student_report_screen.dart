import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = '${now.day}/${now.month}/${now.year}';

      // Calculate averages
      final mockMarks = allMarks.where((m) => m.assessmentType == 'mock').toList();
      final assignmentMarks = allMarks.where((m) => m.assessmentType == 'assignment').toList();

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
                  color: overallAverage >= 75
                      ? PdfColors.green100
                      : overallAverage >= 50
                      ? PdfColors.orange100
                      : PdfColors.red100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: overallAverage >= 75
                        ? PdfColors.green
                        : overallAverage >= 50
                        ? PdfColors.orange
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
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Assessment', isHeader: true),
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('Marks', isHeader: true),
                        _buildTableCell('Percentage', isHeader: true),
                      ],
                    ),
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
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Assessment', isHeader: true),
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('Marks', isHeader: true),
                        _buildTableCell('Percentage', isHeader: true),
                      ],
                    ),
                    ...assignmentMarks.map((mark) {
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
                    pw.Text('A: 75% and above', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('B: 50% - 74%', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('C: Below 50%', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Save and share PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${widget.student.name}_Report_Card.pdf');
      await file.writeAsBytes(await pdf.save());

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
                                'BPE',
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
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
                                      color: average >= 75
                                          ? AppTheme.success
                                          : average >= 50
                                          ? AppTheme.warning
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

                  // Sort by date (newest first)
                  marks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
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
                          margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      mark.assessmentName,
                                      style: AppTheme.heading3,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Edit Button
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
                                          // Refresh data after edit
                                          setState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryPurple.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: AppTheme.primaryPurple,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Percentage Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: percentage >= 75
                                              ? AppTheme.success
                                              : percentage >= 50
                                              ? AppTheme.warning
                                              : AppTheme.error,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: AppTheme.textGrey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    mark.date,
                                    style: AppTheme.bodySmall,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${mark.obtainedMarks.toStringAsFixed(0)} / ${mark.totalMarks.toStringAsFixed(0)}',
                                    style: AppTheme.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  minHeight: 8,
                                  backgroundColor: AppTheme.borderGrey,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    percentage >= 75
                                        ? AppTheme.success
                                        : percentage >= 50
                                        ? AppTheme.warning
                                        : AppTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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