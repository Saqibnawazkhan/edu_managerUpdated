import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/marks_model.dart';
import '../models/attendance_model.dart';
import '../services/student_service.dart';
import '../services/marks_service.dart';
import '../services/attendance_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen_new.dart';
import 'attendance_selection_screen.dart';
import 'student_report_screen.dart';
import 'student_attendance_detail_screen.dart';
import 'add_marks_screen.dart';
import 'marks_report_screen.dart';

class StatisticsScreen extends StatefulWidget {
  final ClassModel classItem;

  const StatisticsScreen({super.key, required this.classItem});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  String _attendanceSearchQuery = '';
  String _marksSearchQuery = '';

  // Keys to force refresh when returning from add marks screen
  UniqueKey _attendanceKey = UniqueKey();
  UniqueKey _marksKey = UniqueKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _refreshData() {
    setState(() {
      _attendanceKey = UniqueKey();
      _marksKey = UniqueKey();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportClassAttendanceToPdf() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final studentService = Provider.of<StudentService>(context, listen: false);
      final attendanceService = Provider.of<AttendanceService>(context, listen: false);

      final students = await studentService.getStudents(widget.classItem.id).first;

      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = '${now.day}/${now.month}/${now.year}';

      // Gather attendance data for each student
      final List<Map<String, dynamic>> studentAttendanceData = [];

      for (var student in students) {
        final attendanceRecords = await attendanceService.getStudentAttendance(student.id).first;

        int presentCount = attendanceRecords.where((a) => a.status == 'present').length;
        int absentCount = attendanceRecords.where((a) => a.status == 'absent').length;
        int lateCount = attendanceRecords.where((a) => a.status == 'late').length;
        int sickCount = attendanceRecords.where((a) => a.status == 'sick').length;
        int totalDays = attendanceRecords.length;
        double percentage = totalDays > 0 ? (presentCount / totalDays * 100) : 0.0;

        studentAttendanceData.add({
          'name': student.name,
          'present': presentCount,
          'absent': absentCount,
          'late': lateCount,
          'sick': sickCount,
          'total': totalDays,
          'percentage': percentage,
        });
      }

      // Sort by name
      studentAttendanceData.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

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
                      '${widget.classItem.name} - Attendance Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
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

              // Summary Stats
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          '${studentAttendanceData.length}',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text('Total Students'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          studentAttendanceData.isEmpty
                              ? '0.0%'
                              : '${(studentAttendanceData.map((s) => s['percentage'] as double).reduce((a, b) => a + b) / studentAttendanceData.length).toStringAsFixed(1)}%',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.Text('Class Average'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Student Attendance Table
              pw.Text(
                'Student-wise Attendance',
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
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Student Name', isHeader: true),
                      _buildTableCell('Present', isHeader: true),
                      _buildTableCell('Absent', isHeader: true),
                      _buildTableCell('Late', isHeader: true),
                      _buildTableCell('Sick', isHeader: true),
                      _buildTableCell('Total', isHeader: true),
                      _buildTableCell('%', isHeader: true),
                    ],
                  ),
                  ...studentAttendanceData.map((data) {
                    final percentage = data['percentage'] as double;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(data['name'] as String),
                        _buildTableCell('${data['present']}'),
                        _buildTableCell('${data['absent']}'),
                        _buildTableCell('${data['late']}'),
                        _buildTableCell('${data['sick']}'),
                        _buildTableCell('${data['total']}'),
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

              // Legend
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
                      'Legend',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Green: 75% and above (Excellent)', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Orange: 50% - 74% (Needs Improvement)', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Red: Below 50% (Critical)', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Save and share PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${widget.classItem.name}_Attendance_Report.pdf');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Share the PDF
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '${widget.classItem.name} - Attendance Report',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Attendance report exported successfully!'),
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

  Future<void> _exportMarksToPdf() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final studentService = Provider.of<StudentService>(context, listen: false);
      final marksService = Provider.of<MarksService>(context, listen: false);

      final students = await studentService.getStudents(widget.classItem.id).first;

      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = '${now.day}/${now.month}/${now.year}';

      // Gather marks data for each student
      final List<Map<String, dynamic>> studentMarksData = [];

      for (var student in students) {
        final marks = await marksService.getStudentMarks(student.id).first;

        double average = 0.0;
        if (marks.isNotEmpty) {
          double total = 0.0;
          for (var mark in marks) {
            total += (mark.obtainedMarks / mark.totalMarks * 100);
          }
          average = total / marks.length;
        }

        studentMarksData.add({
          'name': student.name,
          'marks': marks,
          'average': average,
        });
      }

      // Sort by name
      studentMarksData.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

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
                      '${widget.classItem.name} - Marks Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
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

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          '${studentMarksData.length}',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text('Total Students'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          '${studentMarksData.where((s) => (s['marks'] as List).isNotEmpty).length}',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.Text('Students with Marks'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Student Marks Details
              ...studentMarksData.map((data) {
                final marks = data['marks'] as List<MarksModel>;
                final average = data['average'] as double;

                if (marks.isEmpty) return pw.SizedBox();

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: average >= 75
                            ? PdfColors.green100
                            : average >= 50
                            ? PdfColors.orange100
                            : PdfColors.red100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            data['name'] as String,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${average.toStringAsFixed(1)}%',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: average >= 75
                                  ? PdfColors.green900
                                  : average >= 50
                                  ? PdfColors.orange900
                                  : PdfColors.red900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
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
                            _buildTableCell('%', isHeader: true),
                          ],
                        ),
                        ...marks.map((mark) {
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
                    pw.SizedBox(height: 16),
                  ],
                );
              }),
            ];
          },
        ),
      );

      // Save and share PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${widget.classItem.name}_Marks_Report.pdf');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Share the PDF
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '${widget.classItem.name} - Marks Report',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marks report exported successfully!'),
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final studentService = Provider.of<StudentService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);
    final marksService = Provider.of<MarksService>(context, listen: false);

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
                          widget.classItem.name,
                          style: AppTheme.heading2,
                        ),
                        Text(
                          'Statistics Overview',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Marks Report button
                  if (_tabController.index == 1)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.assessment),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MarksReportScreen(
                                classItem: widget.classItem,
                              ),
                            ),
                          );
                        },
                        color: AppTheme.primaryPurple,
                        tooltip: 'Assessments Report',
                      ),
                    ),
                  // Export button - changes based on active tab
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: _tabController.index == 0
                          ? _exportClassAttendanceToPdf
                          : _exportMarksToPdf,
                      color: AppTheme.error,
                      tooltip: 'Export to PDF',
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: AppTheme.softShadow,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textDark,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.calendar_today, size: 20),
                      text: 'Attendance',
                      height: 60,
                    ),
                    Tab(
                      icon: Icon(Icons.star, size: 20),
                      text: 'Marks',
                      height: 60,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAttendanceTab(studentService, attendanceService),
                  _buildMarksTab(studentService, marksService),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreenNew()),
                  (route) => false,
            );
          } else if (index == 1) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AttendanceSelectionScreen()),
                  (route) => false,
            );
          } else if (index == 2) {
            Navigator.pop(context);
          }
        },
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
        onPressed: () async {
          // Navigate and wait for result
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMarksScreenBulk(
                classItem: widget.classItem,
              ),
            ),
          );
          // Refresh data when returning
          _refreshData();
        },
        backgroundColor: AppTheme.primaryPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Marks',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildAttendanceTab(
      StudentService studentService,
      AttendanceService attendanceService,
      ) {
    return Column(
      key: _attendanceKey, // Key to force refresh
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.softShadow,
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _attendanceSearchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search students...',
                hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textGrey),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textGrey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing12,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacing16),

        Expanded(
          child: FutureBuilder<List<StudentModel>>(
            future: studentService.getStudents(widget.classItem.id).first,
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
                        Icons.people_outline,
                        size: 80,
                        color: AppTheme.textGrey.withOpacity(0.3),
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      Text(
                        'No students in this class',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                );
              }

              var students = snapshot.data!;

              // Sort alphabetically
              students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              // Filter by search query
              if (_attendanceSearchQuery.isNotEmpty) {
                students = students
                    .where((s) => s.name.toLowerCase().contains(_attendanceSearchQuery))
                    .toList();
              }

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: AppTheme.textGrey.withOpacity(0.3),
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      Text(
                        'No students found',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                );
              }

              final colors = [
                AppTheme.primaryPurple,
                AppTheme.primaryGreen,
                AppTheme.primaryYellow,
                AppTheme.primaryPink,
                AppTheme.primaryBlue,
              ];

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final color = colors[index % colors.length];

                  return FutureBuilder<List<AttendanceModel>>(
                    future: attendanceService.getStudentAttendance(student.id).first,
                    builder: (context, attendanceSnapshot) {
                      int presentCount = 0;
                      int absentCount = 0;
                      int totalSessions = 0;

                      if (attendanceSnapshot.hasData) {
                        final records = attendanceSnapshot.data!;
                        totalSessions = records.length;
                        presentCount = records.where((a) => a.status == 'present').length;
                        absentCount = records.where((a) => a.status == 'absent').length;
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentAttendanceDetailScreen(
                                student: student,
                                classItem: widget.classItem,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: color,
                                child: Text(
                                  student.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: AppTheme.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$totalSessions ${totalSessions == 1 ? 'session' : 'sessions'} recorded',
                                      style: AppTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _buildStatBox(presentCount.toString(), 'Present', AppTheme.success),
                                  const SizedBox(width: 8),
                                  _buildStatBox(absentCount.toString(), 'Absent', AppTheme.error),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarksTab(
      StudentService studentService,
      MarksService marksService,
      ) {
    return Column(
      key: _marksKey, // Key on entire column to force refresh
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.softShadow,
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _marksSearchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search students...',
                hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textGrey),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textGrey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing12,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacing16),

        Expanded(
          child: FutureBuilder<List<StudentModel>>(
            future: studentService.getStudents(widget.classItem.id).first,
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
                        Icons.people_outline,
                        size: 80,
                        color: AppTheme.textGrey.withOpacity(0.3),
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      Text(
                        'No students in this class',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                );
              }

              var students = snapshot.data!;

              // Sort alphabetically
              students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              // Filter by search query
              if (_marksSearchQuery.isNotEmpty) {
                students = students
                    .where((s) => s.name.toLowerCase().contains(_marksSearchQuery))
                    .toList();
              }

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: AppTheme.textGrey.withOpacity(0.3),
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      Text(
                        'No students found',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                );
              }

              final colors = [
                AppTheme.primaryPurple,
                AppTheme.primaryGreen,
                AppTheme.primaryYellow,
                AppTheme.primaryPink,
                AppTheme.primaryBlue,
              ];

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final color = colors[index % colors.length];

                  return FutureBuilder<List<MarksModel>>(
                    future: marksService.getStudentMarks(student.id).first,
                    builder: (context, marksSnapshot) {
                      double average = 0.0;
                      int marksCount = 0;

                      if (marksSnapshot.hasData && marksSnapshot.data!.isNotEmpty) {
                        final marks = marksSnapshot.data!;
                        marksCount = marks.length;
                        double total = 0.0;
                        for (var mark in marks) {
                          total += (mark.obtainedMarks / mark.totalMarks * 100);
                        }
                        average = total / marks.length;
                      }

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentReportScreen(
                                student: student,
                                classItem: widget.classItem,
                              ),
                            ),
                          );
                          // Refresh data when returning (in case marks were deleted/edited)
                          _refreshData();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: color,
                                    child: Text(
                                      student.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          style: AppTheme.bodyLarge.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '$marksCount assessments',
                                          style: AppTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: average >= 75
                                          ? AppTheme.success
                                          : average >= 50
                                          ? AppTheme.warning
                                          : AppTheme.error,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${average.toStringAsFixed(1)}%',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (marksSnapshot.hasData && marksSnapshot.data!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 60,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: marksSnapshot.data!.length,
                                    itemBuilder: (context, markIndex) {
                                      final mark = marksSnapshot.data![markIndex];
                                      final percentage = mark.percentage;

                                      return Container(
                                        width: 80,
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cardWhite,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              mark.assessmentName.length > 8
                                                  ? '${mark.assessmentName.substring(0, 7)}...'
                                                  : mark.assessmentName,
                                              style: AppTheme.caption,
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${percentage.toStringAsFixed(0)}%',
                                              style: AppTheme.bodyMedium.copyWith(
                                                color: percentage >= 75
                                                    ? AppTheme.success
                                                    : percentage >= 50
                                                    ? AppTheme.warning
                                                    : AppTheme.error,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTheme.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}