// COMPLETE ATTENDANCE_HISTORY_SCREEN.DART - Compatible with Updated Model
// Replace your existing file with this

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../utils/app_theme.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final ClassModel classItem;

  const AttendanceHistoryScreen({
    super.key,
    required this.classItem,
  });

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _selectedMonth = DateTime.now();

  // Group attendance records by date
  Map<String, List<AttendanceModel>> _groupByDate(List<AttendanceModel> records) {
    final Map<String, List<AttendanceModel>> grouped = {};

    for (var record in records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(record);
    }

    return grouped;
  }

  // Group by session within a date
  Map<String, List<AttendanceModel>> _groupBySession(List<AttendanceModel> records) {
    final Map<String, List<AttendanceModel>> grouped = {};

    for (var record in records) {
      final key = record.sessionId;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(record);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = Provider.of<AttendanceService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked != null) {
                setState(() {
                  _selectedMonth = DateTime(picked.year, picked.month);
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardWhite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      );
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: AppTheme.heading2,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final nextMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                    if (nextMonth.isBefore(DateTime.now()) ||
                        nextMonth.month == DateTime.now().month) {
                      setState(() {
                        _selectedMonth = nextMonth;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // History list
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream: attendanceService.getAllClassAttendance(widget.classItem.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryPurple,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 80,
                          color: AppTheme.textGrey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records',
                          style: AppTheme.heading3.copyWith(
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter by selected month
                final allRecords = snapshot.data!;
                final monthRecords = allRecords.where((record) {
                  return record.date.year == _selectedMonth.year &&
                      record.date.month == _selectedMonth.month;
                }).toList();

                if (monthRecords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: AppTheme.textGrey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No records for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                          style: AppTheme.heading3.copyWith(
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date
                final groupedByDate = _groupByDate(monthRecords);
                final sortedDates = groupedByDate.keys.toList()
                  ..sort((a, b) => b.compareTo(a)); // Newest first

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final dateKey = sortedDates[index];
                    final dateRecords = groupedByDate[dateKey]!;
                    final date = dateRecords.first.date;

                    // Group by session for this date
                    final sessions = _groupBySession(dateRecords);

                    return _buildDateCard(date, sessions);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(DateTime date, Map<String, List<AttendanceModel>> sessions) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Column(
        children: [
          // Date header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryPurple,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sessions.length} ${sessions.length == 1 ? 'Session' : 'Sessions'}',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sessions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: sessions.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSessionCard(entry.key, entry.value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(String sessionKey, List<AttendanceModel> sessionRecords) {
    // Sort students alphabetically by name
    final sortedRecords = List<AttendanceModel>.from(sessionRecords);
    sortedRecords.sort((a, b) => a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

    final firstRecord = sortedRecords.first;
    final presentCount = sessionRecords.where((r) => r.status == 'present').length;
    final absentCount = sessionRecords.where((r) => r.status == 'absent').length;
    final lateCount = sessionRecords.where((r) => r.status == 'late').length;
    final leaveCount = sessionRecords.where((r) => r.status == 'leave').length;
    final sickCount = sessionRecords.where((r) => r.status == 'sick').length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.borderGrey.withOpacity(0.5),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(12),
          childrenPadding: const EdgeInsets.only(
            bottom: 12,
            left: 12,
            right: 12,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.access_time,
              color: AppTheme.primaryPurple,
              size: 20,
            ),
          ),
          title: Text(
            firstRecord.sessionDisplay,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (presentCount > 0)
                  _buildStatusChip('Present', presentCount, AppTheme.success),
                if (absentCount > 0)
                  _buildStatusChip('Absent', absentCount, AppTheme.error),
                if (lateCount > 0)
                  _buildStatusChip('Late', lateCount, Colors.blue),
                if (leaveCount > 0)
                  _buildStatusChip('Leave', leaveCount, AppTheme.warning),
                if (sickCount > 0)
                  _buildStatusChip('Sick', sickCount, Colors.pink),
              ],
            ),
          ),
          children: [
            // Student list (sorted alphabetically)
            ...sortedRecords.map((record) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _getStatusColor(record.status).withOpacity(0.1),
                child: Icon(
                  _getStatusIcon(record.status),
                  size: 16,
                  color: _getStatusColor(record.status),
                ),
              ),
              title: Text(
                record.studentName,
                style: const TextStyle(fontSize: 14),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(record.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(record.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppTheme.success;
      case 'absent':
        return AppTheme.error;
      case 'late':
        return Colors.blue;
      case 'leave':
        return AppTheme.warning;
      case 'sick':
        return Colors.pink;
      default:
        return AppTheme.textGrey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      case 'leave':
        return Icons.event_busy;
      case 'sick':
        return Icons.local_hospital;
      default:
        return Icons.help_outline;
    }
  }
}