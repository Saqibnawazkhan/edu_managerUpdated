import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../utils/app_theme.dart';

class StudentAttendanceDetailScreen extends StatefulWidget {
  final StudentModel student;
  final ClassModel classItem;

  const StudentAttendanceDetailScreen({
    super.key,
    required this.student,
    required this.classItem,
  });

  @override
  State<StudentAttendanceDetailScreen> createState() => _StudentAttendanceDetailScreenState();
}

class _StudentAttendanceDetailScreenState extends State<StudentAttendanceDetailScreen> {
  String _filterStatus = 'all';

  Future<void> _exportToPdf(List<AttendanceModel> attendanceRecords) async {
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

      // Calculate stats
      int presentCount = attendanceRecords.where((a) => a.status == 'present').length;
      int absentCount = attendanceRecords.where((a) => a.status == 'absent').length;
      int lateCount = attendanceRecords.where((a) => a.status == 'late').length;
      int sickCount = attendanceRecords.where((a) => a.status == 'sick').length;
      int shortLeaveCount = attendanceRecords.where((a) => a.status == 'short_leave').length;
      int totalDays = attendanceRecords.length;
      double percentage = totalDays > 0 ? (presentCount / totalDays * 100) : 0.0;

      // Sort by date (newest first)
      final sortedRecords = List<AttendanceModel>.from(attendanceRecords);
      sortedRecords.sort((a, b) => b.date.compareTo(a.date));

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
                      '${widget.student.name} - Attendance Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
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

              // Summary Stats
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: percentage >= 75
                      ? PdfColors.green100
                      : percentage >= 50
                      ? PdfColors.orange100
                      : PdfColors.red100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: percentage >= 75
                        ? PdfColors.green
                        : percentage >= 50
                        ? PdfColors.orange
                        : PdfColors.red,
                    width: 2,
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: percentage >= 75
                            ? PdfColors.green900
                            : percentage >= 50
                            ? PdfColors.orange900
                            : PdfColors.red900,
                      ),
                    ),
                    pw.Text(
                      'Overall Attendance',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Present', presentCount),
                        _buildStatColumn('Absent', absentCount),
                        _buildStatColumn('Late', lateCount),
                        _buildStatColumn('Sick', sickCount),
                      ],
                    ),
                    if (shortLeaveCount > 0) ...[
                      pw.SizedBox(height: 8),
                      _buildStatColumn('Short Leave', shortLeaveCount),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Attendance Records
              if (sortedRecords.isNotEmpty) ...[
                pw.Text(
                  'Attendance History',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('#', isHeader: true),
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('Status', isHeader: true),
                      ],
                    ),
                    ...sortedRecords.asMap().entries.map((entry) {
                      final index = entry.key;
                      final record = entry.value;
                      final statusColor = _getStatusColorPdf(record.status);
                      final statusLabel = _getStatusLabel(record.status);

                      return pw.TableRow(
                        children: [
                          _buildTableCell('${index + 1}'),
                          _buildTableCell(_formatDatePdf(record.date)),
                          _buildTableCell(
                            statusLabel.toUpperCase(),
                            color: statusColor,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],

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
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Total Days Recorded: $totalDays',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Present: $presentCount days (${presentCount > 0 ? (presentCount / totalDays * 100).toStringAsFixed(1) : 0}%)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Absent: $absentCount days (${absentCount > 0 ? (absentCount / totalDays * 100).toStringAsFixed(1) : 0}%)',
                      style: const pw.TextStyle(fontSize: 10),
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
      final file = File('${output.path}/${widget.student.name}_Attendance_Report.pdf');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Share the PDF
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '${widget.student.name} - Attendance Report',
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

  pw.Widget _buildStatColumn(String label, int value) {
    return pw.Column(
      children: [
        pw.Text(
          '$value',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  PdfColor _getStatusColorPdf(String status) {
    switch (status) {
      case 'present':
        return PdfColors.green700;
      case 'absent':
        return PdfColors.red700;
      case 'late':
        return PdfColors.blue700;
      case 'sick':
        return PdfColors.orange700;
      case 'short_leave':
        return PdfColors.yellow700;
      default:
        return PdfColors.grey700;
    }
  }

  String _formatDatePdf(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[date.weekday - 1];
    return '$dayName, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = Provider.of<AttendanceService>(context);

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
                          'Attendance Details',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // PDF Export Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: StreamBuilder<List<AttendanceModel>>(
                      stream: attendanceService.getStudentAttendance(widget.student.id, widget.classItem.id),
                      builder: (context, snapshot) {
                        final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
                        return IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          onPressed: hasData ? () => _exportToPdf(snapshot.data!) : null,
                          color: AppTheme.error,
                          tooltip: 'Export to PDF',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Present', 'present', AppTheme.success),
                  const SizedBox(width: 8),
                  _buildFilterChip('Absent', 'absent', AppTheme.error),
                  const SizedBox(width: 8),
                  _buildFilterChip('Late', 'late', AppTheme.info),
                  const SizedBox(width: 8),
                  _buildFilterChip('Sick', 'sick', AppTheme.warning),
                  const SizedBox(width: 8),
                  _buildFilterChip('Short Leave', 'short_leave', AppTheme.primaryYellow),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Attendance List
            Expanded(
              child: StreamBuilder<List<AttendanceModel>>(
                stream: attendanceService.getStudentAttendance(widget.student.id, widget.classItem.id),
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
                            Icons.event_busy,
                            size: 80,
                            color: AppTheme.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            'No attendance records',
                            style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  var attendanceList = snapshot.data!;

                  // Filter by status
                  if (_filterStatus != 'all') {
                    attendanceList = attendanceList
                        .where((a) => a.status == _filterStatus)
                        .toList();
                  }

                  // Sort by date (newest first)
                  attendanceList.sort((a, b) => b.date.compareTo(a.date));

                  if (attendanceList.isEmpty) {
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
                            'No $_filterStatus records found',
                            style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Calculate summary stats
                  final allRecords = snapshot.data!;
                  final presentCount = allRecords.where((a) => a.status == 'present').length;
                  final absentCount = allRecords.where((a) => a.status == 'absent').length;
                  final lateCount = allRecords.where((a) => a.status == 'late').length;
                  final sickCount = allRecords.where((a) => a.status == 'sick').length;
                  final shortLeaveCount = allRecords.where((a) => a.status == 'short_leave').length;
                  final totalDays = allRecords.length;
                  final attendancePercentage = totalDays > 0
                      ? (presentCount / totalDays * 100)
                      : 0.0;

                  return Column(
                    children: [
                      // Summary Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                attendancePercentage >= 75 ? AppTheme.success :
                                attendancePercentage >= 50 ? AppTheme.warning : AppTheme.error,
                                attendancePercentage >= 75 ? AppTheme.success.withOpacity(0.7) :
                                attendancePercentage >= 50 ? AppTheme.warning.withOpacity(0.7) : AppTheme.error.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${attendancePercentage.toStringAsFixed(1)}%',
                                style: AppTheme.heading1.copyWith(
                                  color: Colors.white,
                                  fontSize: 36,
                                ),
                              ),
                              Text(
                                'Overall Attendance',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildSummaryStat(presentCount.toString(), 'Present'),
                                  _buildSummaryStat(absentCount.toString(), 'Absent'),
                                  _buildSummaryStat(lateCount.toString(), 'Late'),
                                  _buildSummaryStat(sickCount.toString(), 'Sick'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacing16),

                      // Attendance Records
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                          itemCount: attendanceList.length,
                          itemBuilder: (context, index) {
                            final attendance = attendanceList[index];
                            final statusColor = _getStatusColor(attendance.status);
                            final statusLabel = _getStatusLabel(attendance.status);
                            final statusIcon = _getStatusIcon(attendance.status);

                            return Container(
                              margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                              padding: const EdgeInsets.all(AppTheme.spacing16),
                              decoration: BoxDecoration(
                                color: AppTheme.cardWhite,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                boxShadow: AppTheme.cardShadow,
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      statusIcon,
                                      color: statusColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDate(attendance.date),
                                          style: AppTheme.heading3,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          statusLabel,
                                          style: AppTheme.bodySmall.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusLabel.toUpperCase(),
                                      style: AppTheme.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
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

  Widget _buildFilterChip(String label, String value, [Color? color]) {
    final isSelected = _filterStatus == value;
    final chipColor = color ?? AppTheme.primaryPurple;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: chipColor,
      backgroundColor: AppTheme.cardWhite,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textDark,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? chipColor : AppTheme.borderGrey,
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.heading2.copyWith(
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return AppTheme.success;
      case 'absent':
        return AppTheme.error;
      case 'late':
        return AppTheme.info;
      case 'sick':
        return AppTheme.warning;
      case 'short_leave':
        return AppTheme.primaryYellow;
      default:
        return AppTheme.textGrey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'late':
        return 'Late';
      case 'sick':
        return 'Sick';
      case 'short_leave':
        return 'Short Leave';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      case 'sick':
        return Icons.local_hospital;
      case 'short_leave':
        return Icons.exit_to_app;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }
}