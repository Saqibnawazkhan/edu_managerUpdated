import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  String _attendanceSearchQuery = '';
  String _marksSearchQuery = '';

  UniqueKey _attendanceKey = UniqueKey();
  UniqueKey _marksKey = UniqueKey();

  late AnimationController _fabController;
  late Animation<double> _fabScale;

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

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _fabScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
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
    _fabController.dispose();
    super.dispose();
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _exportClassAttendanceToPdf() async {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      ),
    );

    try {
      final studentService = Provider.of<StudentService>(context, listen: false);
      final attendanceService = Provider.of<AttendanceService>(context, listen: false);

      final students = await studentService.getStudents(widget.classItem.id).first;

      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = '${now.day}/${now.month}/${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final List<Map<String, dynamic>> studentAttendanceData = [];

      // Get all attendance records for the class to extract session details
      final allClassAttendance = await attendanceService.getAllClassAttendance(widget.classItem.id).first;

      // Group attendance by session to get unique sessions with date/time
      final Map<String, Map<String, dynamic>> sessionDetails = {};
      for (var record in allClassAttendance) {
        if (!sessionDetails.containsKey(record.sessionId)) {
          sessionDetails[record.sessionId] = {
            'date': record.date,
            'sessionDisplay': record.sessionDisplay,
            'sessionId': record.sessionId,
          };
        }
      }

      // Sort sessions by date (newest first)
      final sortedSessions = sessionDetails.values.toList()
        ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      for (var student in students) {
        final attendanceRecords = await attendanceService.getStudentAttendance(student.id).first;

        int presentCount = attendanceRecords.where((a) => a.status == 'present').length;
        int absentCount = attendanceRecords.where((a) => a.status == 'absent').length;
        int lateCount = attendanceRecords.where((a) => a.status == 'late').length;
        int leaveCount = attendanceRecords.where((a) => a.status == 'leave').length;
        int sickCount = attendanceRecords.where((a) => a.status == 'sick').length;
        int totalDays = attendanceRecords.length;
        double percentage = totalDays > 0 ? (presentCount / totalDays * 100) : 0.0;

        studentAttendanceData.add({
          'name': student.name,
          'present': presentCount,
          'absent': absentCount,
          'late': lateCount,
          'leave': leaveCount,
          'sick': sickCount,
          'total': totalDays,
          'percentage': percentage,
          'records': attendanceRecords,
        });
      }

      studentAttendanceData.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
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
                    pw.Row(
                      children: [
                        pw.Icon(pw.IconData(0xe8df), size: 12, color: PdfColors.grey700),
                        pw.SizedBox(width: 4),
                        pw.Text(
                          'Generated on: $formattedDate at $formattedTime',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
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
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text('Total Students'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          '${sortedSessions.length}',
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue),
                        ),
                        pw.Text('Total Sessions'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          studentAttendanceData.isEmpty
                              ? '0.0%'
                              : '${(studentAttendanceData.map((s) => s['percentage'] as double).reduce((a, b) => a + b) / studentAttendanceData.length).toStringAsFixed(1)}%',
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green),
                        ),
                        pw.Text('Class Average'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Session History Section
              if (sortedSessions.isNotEmpty) ...[
                pw.Text('Attendance Sessions', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                      children: [
                        _buildTableCell('#', isHeader: true),
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('Time', isHeader: true),
                      ],
                    ),
                    ...sortedSessions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final session = entry.value;
                      final date = session['date'] as DateTime;
                      final dateStr = '${_getDayName(date.weekday)}, ${date.day}/${date.month}/${date.year}';
                      final timeStr = session['sessionDisplay'] as String;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                        ),
                        children: [
                          _buildTableCell('${index + 1}'),
                          _buildTableCell(dateStr),
                          _buildTableCell(timeStr),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 24),
              ],

              pw.Text('Student-wise Attendance Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
                      _buildTableCell('Leave', isHeader: true),
                      _buildTableCell('Sick', isHeader: true),
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
                        _buildTableCell('${data['leave']}'),
                        _buildTableCell('${data['sick']}'),
                        _buildTableCell(
                          '${percentage.toStringAsFixed(1)}%',
                          color: percentage >= 75 ? PdfColors.green700 : percentage >= 50 ? PdfColors.orange700 : PdfColors.red700,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Legend', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${widget.classItem.name}_Attendance_Report.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)], subject: '${widget.classItem.name} - Attendance Report');
        HapticFeedback.lightImpact();
        _showSnackBar('Attendance report exported successfully!', AppTheme.success);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.heavyImpact();
        _showSnackBar('Error exporting PDF: $e', AppTheme.error, isError: true);
      }
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  Future<void> _exportMarksToPdf() async {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      ),
    );

    try {
      final studentService = Provider.of<StudentService>(context, listen: false);
      final marksService = Provider.of<MarksService>(context, listen: false);

      final students = await studentService.getStudents(widget.classItem.id).first;

      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = '${now.day}/${now.month}/${now.year}';

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

      studentMarksData.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(color: PdfColors.purple100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${widget.classItem.name} - Marks Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
                    pw.SizedBox(height: 8),
                    pw.Text('Generated on: $formattedDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Column(children: [
                      pw.Text('${studentMarksData.length}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total Students'),
                    ]),
                    pw.Column(children: [
                      pw.Text('${studentMarksData.where((s) => (s['marks'] as List).isNotEmpty).length}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                      pw.Text('Students with Marks'),
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              ...studentMarksData.map((data) {
                final marks = data['marks'] as List<MarksModel>;
                final average = data['average'] as double;
                if (marks.isEmpty) return pw.SizedBox();
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(color: average >= 75 ? PdfColors.green100 : average >= 50 ? PdfColors.orange100 : PdfColors.red100, borderRadius: pw.BorderRadius.circular(8)),
                      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                        pw.Text(data['name'] as String, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${average.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: average >= 75 ? PdfColors.green900 : average >= 50 ? PdfColors.orange900 : PdfColors.red900)),
                      ]),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(1.5)},
                      children: [
                        pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                          _buildTableCell('Assessment', isHeader: true),
                          _buildTableCell('Date', isHeader: true),
                          _buildTableCell('Marks', isHeader: true),
                          _buildTableCell('%', isHeader: true),
                        ]),
                        ...marks.map((mark) {
                          final percentage = (mark.obtainedMarks / mark.totalMarks * 100);
                          return pw.TableRow(children: [
                            _buildTableCell(mark.assessmentName),
                            _buildTableCell(mark.date),
                            _buildTableCell('${mark.obtainedMarks.toStringAsFixed(0)}/${mark.totalMarks.toStringAsFixed(0)}'),
                            _buildTableCell('${percentage.toStringAsFixed(1)}%', color: percentage >= 75 ? PdfColors.green700 : percentage >= 50 ? PdfColors.orange700 : PdfColors.red700),
                          ]);
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

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${widget.classItem.name}_Marks_Report.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)], subject: '${widget.classItem.name} - Marks Report');
        HapticFeedback.lightImpact();
        _showSnackBar('Marks report exported successfully!', AppTheme.success);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.heavyImpact();
        _showSnackBar('Error exporting PDF: $e', AppTheme.error, isError: true);
      }
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: isHeader ? 12 : 10, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final studentService = Provider.of<StudentService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);
    final marksService = Provider.of<MarksService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.8)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTapDown: (_) => HapticFeedback.selectionClick(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.classItem.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Statistics Overview',
                            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    if (_tabController.index == 1)
                      GestureDetector(
                        onTapDown: (_) => HapticFeedback.selectionClick(),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MarksReportScreen(classItem: widget.classItem)));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.assessment_rounded, color: AppTheme.primaryBlue, size: 22),
                        ),
                      ),
                    GestureDetector(
                      onTapDown: (_) => HapticFeedback.selectionClick(),
                      onTap: _tabController.index == 0 ? _exportClassAttendanceToPdf : _exportMarksToPdf,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.error, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.8)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textDark,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  onTap: (_) => HapticFeedback.selectionClick(),
                  tabs: const [
                    Tab(icon: Icon(Icons.calendar_today_rounded, size: 20), text: 'Attendance', height: 60),
                    Tab(icon: Icon(Icons.star_rounded, size: 20), text: 'Marks', height: 60),
                  ],
                ),
              ),
            ),

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
          HapticFeedback.selectionClick();
          if (index == 0) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreenNew()), (route) => false);
          } else if (index == 1) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AttendanceSelectionScreen()), (route) => false);
          } else if (index == 2) {
            Navigator.pop(context);
          }
        },
      ),
      floatingActionButton: _tabController.index == 1
          ? GestureDetector(
              onTapDown: (_) {
                HapticFeedback.selectionClick();
                _fabController.forward();
              },
              onTapUp: (_) => _fabController.reverse(),
              onTapCancel: () => _fabController.reverse(),
              onTap: () async {
                HapticFeedback.mediumImpact();
                await Navigator.push(context, MaterialPageRoute(builder: (context) => AddMarksScreenBulk(classItem: widget.classItem)));
                _refreshData();
              },
              child: AnimatedBuilder(
                animation: _fabScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _fabScale.value,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.8)]),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Add Marks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : null,
    );
  }

  Widget _buildAttendanceTab(StudentService studentService, AttendanceService attendanceService) {
    return Column(
      key: _attendanceKey,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              onTap: () => HapticFeedback.selectionClick(),
              onChanged: (value) => setState(() => _attendanceSearchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search students...',
                hintStyle: const TextStyle(color: AppTheme.textGrey),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<StudentModel>>(
            future: studentService.getStudents(widget.classItem.id).first,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: const CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 3),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 64, color: AppTheme.textGrey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No students in this class', style: TextStyle(fontSize: 16, color: AppTheme.textGrey)),
                    ],
                  ),
                );
              }

              var students = snapshot.data!;
              students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (_attendanceSearchQuery.isNotEmpty) {
                students = students.where((s) => s.name.toLowerCase().contains(_attendanceSearchQuery)).toList();
              }

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textGrey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No students found', style: TextStyle(fontSize: 16, color: AppTheme.textGrey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return FutureBuilder<List<AttendanceModel>>(
                    future: attendanceService.getStudentAttendance(student.id).first,
                    builder: (context, attendanceSnapshot) {
                      int presentCount = 0;
                      int absentCount = 0;
                      int totalSessions = 0;
                      double percentage = 0;

                      if (attendanceSnapshot.hasData) {
                        final records = attendanceSnapshot.data!;
                        totalSessions = records.length;
                        presentCount = records.where((a) => a.status == 'present').length;
                        absentCount = records.where((a) => a.status == 'absent').length;
                        percentage = totalSessions > 0 ? (presentCount / totalSessions * 100) : 0;
                      }

                      return _buildStudentAttendanceCard(student, presentCount, absentCount, totalSessions, percentage);
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

  Widget _buildStudentAttendanceCard(StudentModel student, int present, int absent, int total, double percentage) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (context) => StudentAttendanceDetailScreen(student: student, classItem: widget.classItem)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(student.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$total ${total == 1 ? 'session' : 'sessions'}', style: const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
                ],
              ),
            ),
            Row(
              children: [
                _buildMiniStat(present.toString(), 'P', AppTheme.success),
                const SizedBox(width: 6),
                _buildMiniStat(absent.toString(), 'A', AppTheme.error),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: percentage >= 75 ? AppTheme.success.withValues(alpha: 0.1) : percentage >= 50 ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: percentage >= 75 ? AppTheme.success : percentage >= 50 ? AppTheme.warning : AppTheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMarksTab(StudentService studentService, MarksService marksService) {
    return Column(
      key: _marksKey,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              onTap: () => HapticFeedback.selectionClick(),
              onChanged: (value) => setState(() => _marksSearchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search students...',
                hintStyle: const TextStyle(color: AppTheme.textGrey),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<StudentModel>>(
            future: studentService.getStudents(widget.classItem.id).first,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: const CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 3),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 64, color: AppTheme.textGrey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No students in this class', style: TextStyle(fontSize: 16, color: AppTheme.textGrey)),
                    ],
                  ),
                );
              }

              var students = snapshot.data!;
              students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (_marksSearchQuery.isNotEmpty) {
                students = students.where((s) => s.name.toLowerCase().contains(_marksSearchQuery)).toList();
              }

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textGrey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No students found', style: TextStyle(fontSize: 16, color: AppTheme.textGrey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return FutureBuilder<List<MarksModel>>(
                    future: marksService.getStudentMarks(student.id).first,
                    builder: (context, marksSnapshot) {
                      // Show loading skeleton while data is loading
                      if (marksSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildStudentMarksCardLoading(student);
                      }

                      double average = 0.0;
                      int marksCount = 0;
                      List<MarksModel> marks = [];

                      if (marksSnapshot.hasData && marksSnapshot.data!.isNotEmpty) {
                        marks = marksSnapshot.data!;
                        marksCount = marks.length;
                        double total = 0.0;
                        for (var mark in marks) {
                          total += (mark.obtainedMarks / mark.totalMarks * 100);
                        }
                        average = total / marks.length;
                      }

                      return _buildStudentMarksCard(student, average, marksCount, marks);
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

  Widget _buildStudentMarksCard(StudentModel student, double average, int count, List<MarksModel> marks) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(context, MaterialPageRoute(builder: (context) => StudentReportScreen(student: student, classItem: widget.classItem)));
        _refreshData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(student.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$count assessments', style: const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: average >= 75 ? AppTheme.success : average >= 50 ? AppTheme.warning : AppTheme.error,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: (average >= 75 ? AppTheme.success : average >= 50 ? AppTheme.warning : AppTheme.error).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Text('${average.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            if (marks.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: marks.length,
                  itemBuilder: (context, markIndex) {
                    final mark = marks[markIndex];
                    final percentage = mark.percentage;
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mark.assessmentName.length > 8 ? '${mark.assessmentName.substring(0, 7)}...' : mark.assessmentName,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: percentage >= 75 ? AppTheme.success : percentage >= 50 ? AppTheme.warning : AppTheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
  }

  Widget _buildStudentMarksCardLoading(StudentModel student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(student.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
