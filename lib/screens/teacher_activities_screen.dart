import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/app_theme.dart';
import '../services/teacher_activity_service.dart';
import '../services/teacher_export_service.dart';

class TeacherActivitiesScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final Timestamp? joinedDate;
  final bool isDisabled;

  const TeacherActivitiesScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    this.joinedDate,
    this.isDisabled = false,
  });

  @override
  State<TeacherActivitiesScreen> createState() => _TeacherActivitiesScreenState();
}

class _TeacherActivitiesScreenState extends State<TeacherActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeacherActivityService _activityService = TeacherActivityService();
  final TeacherExportService _exportService = TeacherExportService();

  TeacherActivityData? _activityData;
  bool _isLoading = true;
  String? _error;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  String _marksFilter = 'all'; // 'all', 'mock', 'assignment'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _activityService.getTeacherActivityData(
        teacherId: widget.teacherId,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _activityData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showDateRangePickerDialog() async {
    DateTime tempStartDate = _startDate;
    DateTime tempEndDate = _endDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Select Date Range'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempStartDate,
                        firstDate: DateTime(2020),
                        lastDate: tempEndDate,
                      );
                      if (picked != null) {
                        setDialogState(() => tempStartDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Text(
                                DateFormat('dd/MM/yyyy').format(tempStartDate),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempEndDate,
                        firstDate: tempStartDate,
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => tempEndDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Text(
                                DateFormat('dd/MM/yyyy').format(tempEndDate),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _startDate = tempStartDate;
        _endDate = tempEndDate;
      });
      _loadData();
    }
  }

  Future<void> _handleExport(String type) async {
    if (_activityData == null) return;

    // Build class names map
    Map<String, String> classNames = {};
    for (var classItem in _activityData!.classes) {
      classNames[classItem.id] = classItem.name;
    }

    try {
      switch (type) {
        case 'pdf_attendance':
          await _exportService.exportAttendanceToPdf(
            teacherName: widget.teacherName,
            activityData: _activityData!,
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'pdf_marks':
          await _exportService.exportMarksToPdf(
            teacherName: widget.teacherName,
            activityData: _activityData!,
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'excel_attendance':
          await _exportService.exportAttendanceToExcel(
            teacherName: widget.teacherName,
            activityData: _activityData!,
            classNames: classNames,
          );
          break;
        case 'excel_marks':
          await _exportService.exportMarksToExcel(
            teacherName: widget.teacherName,
            activityData: _activityData!,
            classNames: classNames,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teacher Activities',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.teacherName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_activityData != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download, color: Colors.white),
              onSelected: _handleExport,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf_attendance',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red),
                      SizedBox(width: 12),
                      Text('PDF - Attendance Report'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf_marks',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red),
                      SizedBox(width: 12),
                      Text('PDF - Marks Report'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'excel_attendance',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, color: Colors.green),
                      SizedBox(width: 12),
                      Text('Excel - Attendance Data'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'excel_marks',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, color: Colors.green),
                      SizedBox(width: 12),
                      Text('Excel - Marks Data'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Date range picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _showDateRangePickerDialog,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppTheme.primaryPurple,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Attendance'),
                    Tab(text: 'Marks'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : _activityData == null
                  ? const Center(child: Text('No data available'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildAttendanceTab(),
                        _buildMarksTab(),
                      ],
                    ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: widget.isDisabled
                            ? Colors.red.withOpacity(0.1)
                            : AppTheme.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.teacherName.isNotEmpty ? widget.teacherName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: widget.isDisabled ? Colors.red : AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.teacherName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.teacherEmail,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          if (widget.joinedDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Joined: ${DateFormat('dd MMM yyyy').format(widget.joinedDate!.toDate())}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isDisabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Disabled',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Classes',
                  _activityData!.classes.length.toString(),
                  Icons.class_,
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Students',
                  _activityData!.totalStudents.toString(),
                  Icons.people,
                  AppTheme.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Attendance',
                  _activityData!.overallAttendanceStats.totalRecords.toString(),
                  Icons.check_circle,
                  AppTheme.primaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Marks',
                  _activityData!.overallMarksStats.totalRecords.toString(),
                  Icons.grade,
                  AppTheme.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Classes List
          const Text(
            'Classes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_activityData!.classes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.class_, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No classes yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_activityData!.classes.map((classItem) {
              final classData = _activityData!.classActivities[classItem.id];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.class_, color: AppTheme.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classItem.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '${classData?.studentCount ?? 0} students',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (classData != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildClassStat(
                              'Attendance',
                              classData.attendanceStats.totalRecords.toString(),
                              AppTheme.primaryPurple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildClassStat(
                              'Marks',
                              classData.marksStats.totalRecords.toString(),
                              AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    final stats = _activityData!.overallAttendanceStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Attendance Statistics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total Records: ${stats.totalRecords}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                if (stats.totalRecords > 0) ...[
                  // Pie Chart
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          if (stats.presentCount > 0)
                            PieChartSectionData(
                              value: stats.presentCount.toDouble(),
                              title: '${stats.presentPercentage.toStringAsFixed(1)}%',
                              color: Colors.green,
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          if (stats.absentCount > 0)
                            PieChartSectionData(
                              value: stats.absentCount.toDouble(),
                              title: '${stats.absentPercentage.toStringAsFixed(1)}%',
                              color: Colors.red,
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          if (stats.lateCount > 0)
                            PieChartSectionData(
                              value: stats.lateCount.toDouble(),
                              title: '${stats.latePercentage.toStringAsFixed(1)}%',
                              color: Colors.orange,
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          if (stats.leaveCount > 0)
                            PieChartSectionData(
                              value: stats.leaveCount.toDouble(),
                              title: '${stats.leavePercentage.toStringAsFixed(1)}%',
                              color: Colors.blue,
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          if (stats.sickCount > 0)
                            PieChartSectionData(
                              value: stats.sickCount.toDouble(),
                              title: '${stats.sickPercentage.toStringAsFixed(1)}%',
                              color: Colors.purple,
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem('Present', stats.presentCount, Colors.green),
                      _buildLegendItem('Absent', stats.absentCount, Colors.red),
                      _buildLegendItem('Late', stats.lateCount, Colors.orange),
                      _buildLegendItem('Leave', stats.leaveCount, Colors.blue),
                      _buildLegendItem('Sick', stats.sickCount, Colors.purple),
                    ],
                  ),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No attendance records in this period'),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Class-wise Breakdown
          const Text(
            'Class-wise Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...(_activityData!.classes.map((classItem) {
            final classData = _activityData!.classActivities[classItem.id];
            if (classData == null || classData.attendanceStats.totalRecords == 0) {
              return const SizedBox();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classItem.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: ${classData.attendanceStats.totalRecords} records',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildAttendanceChip('P', classData.attendanceStats.presentCount, Colors.green),
                      _buildAttendanceChip('A', classData.attendanceStats.absentCount, Colors.red),
                      _buildAttendanceChip('L', classData.attendanceStats.lateCount, Colors.orange),
                      _buildAttendanceChip('Lv', classData.attendanceStats.leaveCount, Colors.blue),
                      _buildAttendanceChip('S', classData.attendanceStats.sickCount, Colors.purple),
                    ],
                  ),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildMarksTab() {
    final stats = _activityData!.overallMarksStats;

    // Filter marks based on selected filter
    List<AssessmentSummary> filteredAssessments = stats.assessments;
    if (_marksFilter != 'all') {
      filteredAssessments = stats.assessments.where((a) => a.assessmentType == _marksFilter).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Mocks', 'mock'),
              const SizedBox(width: 8),
              _buildFilterChip('Assignments', 'assignment'),
            ],
          ),

          const SizedBox(height: 16),

          // Overall Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Marks Statistics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Total', stats.totalRecords.toString(), AppTheme.primaryBlue),
                    ),
                    Expanded(
                      child: _buildStatItem('Mocks', stats.mockCount.toString(), AppTheme.primaryPurple),
                    ),
                    Expanded(
                      child: _buildStatItem('Assignments', stats.assignmentCount.toString(), AppTheme.warning),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Average',
                        '${stats.averagePercentage.toStringAsFixed(1)}%',
                        _getGradeColor(stats.averagePercentage),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Class-wise Breakdown
          const Text(
            'Class-wise Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...(_activityData!.classes.map((classItem) {
            final classData = _activityData!.classActivities[classItem.id];
            if (classData == null || classData.marksStats.totalRecords == 0) {
              return const SizedBox();
            }

            final classAssessments = filteredAssessments.where((a) => a.classId == classItem.id).toList();
            if (classAssessments.isEmpty && _marksFilter != 'all') {
              return const SizedBox();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          classItem.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getGradeColor(classData.marksStats.averagePercentage).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Avg: ${classData.marksStats.averagePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: _getGradeColor(classData.marksStats.averagePercentage),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Records: ${classData.marksStats.totalRecords} | Mocks: ${classData.marksStats.mockCount} | Assignments: ${classData.marksStats.assignmentCount}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  if (classAssessments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...classAssessments.map((assessment) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: assessment.assessmentType == 'mock'
                                    ? AppTheme.primaryPurple.withOpacity(0.1)
                                    : AppTheme.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                assessment.assessmentType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: assessment.assessmentType == 'mock'
                                      ? AppTheme.primaryPurple
                                      : AppTheme.warning,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assessment.assessmentName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    '${assessment.studentCount} students • ${assessment.date}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${assessment.averagePercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getGradeColor(assessment.averagePercentage),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          })),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildClassStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildAttendanceChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _marksFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _marksFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }
}
