import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _StudentAttendanceDetailScreenState extends State<StudentAttendanceDetailScreen>
    with TickerProviderStateMixin {
  String _filterStatus = 'all';

  late AnimationController _pdfButtonController;
  late Animation<double> _pdfButtonScale;

  @override
  void initState() {
    super.initState();
    _pdfButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pdfButtonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pdfButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pdfButtonController.dispose();
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

  Future<void> _exportToPdf(List<AttendanceModel> attendanceRecords) async {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF00BFA5)),
              SizedBox(height: 16),
              Text('Generating PDF...'),
            ],
          ),
        ),
      ),
    );

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = '${now.day}/${now.month}/${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      int presentCount = attendanceRecords.where((a) => a.status == 'present').length;
      int absentCount = attendanceRecords.where((a) => a.status == 'absent').length;
      int lateCount = attendanceRecords.where((a) => a.status == 'late').length;
      int leaveCount = attendanceRecords.where((a) => a.status == 'leave').length;
      int sickCount = attendanceRecords.where((a) => a.status == 'sick').length;
      int totalDays = attendanceRecords.length;
      double percentage = totalDays > 0 ? (presentCount / totalDays * 100) : 0.0;

      final sortedRecords = List<AttendanceModel>.from(attendanceRecords);
      sortedRecords.sort((a, b) => b.date.compareTo(a.date));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal100,
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
                        color: PdfColors.teal900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Class: ${widget.classItem.name}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on: $formattedDate at $formattedTime',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
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
                        _buildPdfStatColumn('Present', presentCount, PdfColors.green),
                        _buildPdfStatColumn('Absent', absentCount, PdfColors.red),
                        _buildPdfStatColumn('Late', lateCount, PdfColors.blue),
                        _buildPdfStatColumn('Leave', leaveCount, PdfColors.orange),
                        _buildPdfStatColumn('Sick', sickCount, PdfColors.pink),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
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
                    0: const pw.FlexColumnWidth(0.5),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.teal100),
                      children: [
                        _buildTableCell('#', isHeader: true),
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('Time', isHeader: true),
                        _buildTableCell('Status', isHeader: true),
                      ],
                    ),
                    ...sortedRecords.asMap().entries.map((entry) {
                      final index = entry.key;
                      final record = entry.value;
                      final statusColor = _getStatusColorPdf(record.status);
                      final statusLabel = _getStatusLabel(record.status);

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                        ),
                        children: [
                          _buildTableCell('${index + 1}'),
                          _buildTableCell(_formatDatePdf(record.date)),
                          _buildTableCell(record.sessionDisplay),
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
                      'Total Sessions Recorded: $totalDays',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Present: $presentCount sessions (${presentCount > 0 ? (presentCount / totalDays * 100).toStringAsFixed(1) : 0}%)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Absent: $absentCount sessions (${absentCount > 0 ? (absentCount / totalDays * 100).toStringAsFixed(1) : 0}%)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${widget.student.name}_Attendance_Report.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '${widget.student.name} - Attendance Report',
        );
        HapticFeedback.lightImpact();
        _showSnackBar('Attendance report exported successfully!', const Color(0xFF4CAF50));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.heavyImpact();
        _showSnackBar('Error exporting PDF: $e', const Color(0xFFE53935), isError: true);
      }
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
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

  pw.Widget _buildPdfStatColumn(String label, int value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          '$value',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9),
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
      case 'leave':
        return PdfColors.orange700;
      case 'sick':
        return PdfColors.pink700;
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
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            _buildHeader(attendanceService),

            // Filter Chips
            _buildFilterChips(),

            const SizedBox(height: 16),

            // Attendance List
            Expanded(
              child: _buildAttendanceList(attendanceService),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AttendanceService attendanceService) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTapDown: (_) => HapticFeedback.selectionClick(),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textDark,
                size: 24,
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Attendance Details',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<List<AttendanceModel>>(
            stream: attendanceService.getStudentAttendance(widget.student.id, widget.classItem.id),
            builder: (context, snapshot) {
              final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
              return GestureDetector(
                onTapDown: hasData
                    ? (_) {
                        HapticFeedback.selectionClick();
                        _pdfButtonController.forward();
                      }
                    : null,
                onTapUp: hasData ? (_) => _pdfButtonController.reverse() : null,
                onTapCancel: hasData ? () => _pdfButtonController.reverse() : null,
                onTap: hasData ? () => _exportToPdf(snapshot.data!) : null,
                child: AnimatedBuilder(
                  animation: _pdfButtonScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pdfButtonScale.value,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: hasData
                              ? const LinearGradient(
                                  colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: hasData ? null : Colors.grey[300],
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: hasData
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: hasData ? Colors.white : Colors.grey[500],
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildFilterChip('All', 'all', const Color(0xFF7C4DFF)),
          const SizedBox(width: 10),
          _buildFilterChip('Present', 'present', const Color(0xFF4CAF50)),
          const SizedBox(width: 10),
          _buildFilterChip('Absent', 'absent', const Color(0xFFE53935)),
          const SizedBox(width: 10),
          _buildFilterChip('Late', 'late', const Color(0xFF2196F3)),
          const SizedBox(width: 10),
          _buildFilterChip('Sick', 'sick', const Color(0xFFE91E63)),
          const SizedBox(width: 10),
          _buildFilterChip('Leave', 'leave', const Color(0xFFFF9800)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _filterStatus == value;

    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _filterStatus = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.transparent : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList(AttendanceService attendanceService) {
    return StreamBuilder<List<AttendanceModel>>(
      stream: attendanceService.getStudentAttendance(widget.student.id, widget.classItem.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('No attendance records', Icons.event_busy_rounded);
        }

        var attendanceList = snapshot.data!;

        if (_filterStatus != 'all') {
          attendanceList = attendanceList.where((a) => a.status == _filterStatus).toList();
        }

        attendanceList.sort((a, b) => b.date.compareTo(a.date));

        if (attendanceList.isEmpty) {
          return _buildEmptyState('No $_filterStatus records found', Icons.filter_list_off_rounded);
        }

        final allRecords = snapshot.data!;
        final presentCount = allRecords.where((a) => a.status == 'present').length;
        final absentCount = allRecords.where((a) => a.status == 'absent').length;
        final lateCount = allRecords.where((a) => a.status == 'late').length;
        final leaveCount = allRecords.where((a) => a.status == 'leave').length;
        final sickCount = allRecords.where((a) => a.status == 'sick').length;
        final totalDays = allRecords.length;
        final attendancePercentage = totalDays > 0 ? (presentCount / totalDays * 100) : 0.0;

        return Column(
          children: [
            // Summary Card
            _buildSummaryCard(attendancePercentage, presentCount, absentCount, lateCount, leaveCount, sickCount),

            const SizedBox(height: 16),

            // Attendance Records
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: attendanceList.length,
                itemBuilder: (context, index) {
                  final attendance = attendanceList[index];
                  return _buildAttendanceCard(attendance, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: const Color(0xFF00BFA5).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    double percentage,
    int present,
    int absent,
    int late,
    int leave,
    int sick,
  ) {
    final Color primaryColor = percentage >= 75
        ? const Color(0xFF4CAF50)
        : percentage >= 50
            ? const Color(0xFFFF9800)
            : const Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Overall Attendance',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryStat(present.toString(), 'Present', Colors.white),
              _buildSummaryStat(absent.toString(), 'Absent', Colors.white),
              _buildSummaryStat(late.toString(), 'Late', Colors.white),
              _buildSummaryStat(leave.toString(), 'Leave', Colors.white),
              _buildSummaryStat(sick.toString(), 'Sick', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceModel attendance, int index) {
    final statusColor = _getStatusColor(attendance.status);
    final statusLabel = _getStatusLabel(attendance.status);
    final statusIcon = _getStatusIcon(attendance.status);

    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                statusIcon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(attendance.date),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        attendance.sessionDisplay,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                statusLabel.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF4CAF50);
      case 'absent':
        return const Color(0xFFE53935);
      case 'late':
        return const Color(0xFF2196F3);
      case 'leave':
        return const Color(0xFFFF9800);
      case 'sick':
        return const Color(0xFFE91E63);
      default:
        return Colors.grey;
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
      case 'leave':
        return 'Leave';
      case 'sick':
        return 'Sick';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.schedule_rounded;
      case 'leave':
        return Icons.event_busy_rounded;
      case 'sick':
        return Icons.local_hospital_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }
}
