// COMPLETE ATTENDANCE_CALENDAR_SCREEN.DART - Compatible with Updated Service
// Replace your existing file with this

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../utils/app_theme.dart';
import 'take_attendance_screen.dart';
import 'attendance_history_screen.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final ClassModel classItem;

  const AttendanceCalendarScreen({
    super.key,
    required this.classItem,
  });

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, int> _attendanceCounts = {};

  @override
  void initState() {
    super.initState();
    _loadAttendanceCounts();
  }

  Future<void> _loadAttendanceCounts() async {
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);
    final counts = await attendanceService.getMonthlyAttendanceCount(
      widget.classItem.id,
      _focusedDay,
    );

    if (mounted) {
      setState(() {
        _attendanceCounts = counts;
      });
    }
  }

  void _showDeleteSessionConfirmation(List<AttendanceModel> sessionRecords, String sessionName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete Session'),
          content: Text(
            'Are you sure you want to delete the "$sessionName" session?\n\nThis will remove attendance records for ${sessionRecords.length} students.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Close dialog immediately for responsiveness
                Navigator.pop(context);

                // Show deleting feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleting $sessionName...'),
                    backgroundColor: AppTheme.primaryPurple,
                    duration: const Duration(seconds: 1),
                  ),
                );

                // Delete all records in background
                final attendanceService = Provider.of<AttendanceService>(context, listen: false);
                Future.wait(
                  sessionRecords.map((record) => attendanceService.deleteAttendance(record.id)),
                ).then((_) {
                  // Reload counts after all deletes complete (check mounted)
                  if (mounted) {
                    _loadAttendanceCounts();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = Provider.of<AttendanceService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.classItem.name),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Calendar
          Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: AppTheme.heading2,
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppTheme.primaryPurple,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.primaryPurple,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primaryPurple,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: const TextStyle(color: AppTheme.error),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
                _loadAttendanceCounts();
              },
              calendarBuilders: CalendarBuilders(
                // Custom marker for dates with attendance
                markerBuilder: (context, date, events) {
                  final dateOnly = DateTime(date.year, date.month, date.day);
                  final count = _attendanceCounts[dateOnly] ?? 0;

                  if (count > 0) {
                    return Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  icon: Icons.circle,
                  color: AppTheme.success,
                  label: 'Has Attendance',
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  icon: Icons.access_time,
                  color: AppTheme.primaryPurple,
                  label: 'Multiple Sessions',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Selected Date Info
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Date Header
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
                                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedDay.isAfter(DateTime.now())
                                    ? 'Future date'
                                    : 'Selected Date',
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

                  // Attendance Sessions
                  Expanded(
                    child: StreamBuilder<List<AttendanceModel>>(
                      stream: attendanceService.getDailyAttendanceSessions(
                        classId: widget.classItem.id,
                        date: _selectedDay,
                      ),
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
                                  Icons.event_busy,
                                  size: 60,
                                  color: AppTheme.textGrey.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No attendance taken yet',
                                  style: TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final records = snapshot.data!;

                        // Group by session
                        final Map<String, List<AttendanceModel>> sessions = {};
                        for (var record in records) {
                          final key = record.sessionId;
                          if (!sessions.containsKey(key)) {
                            sessions[key] = [];
                          }
                          sessions[key]!.add(record);
                        }

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              '${sessions.length} ${sessions.length == 1 ? 'Session' : 'Sessions'}',
                              style: AppTheme.heading3,
                            ),
                            const SizedBox(height: 12),
                            ...sessions.entries.map((entry) {
                              final sessionRecords = entry.value;
                              final firstRecord = sessionRecords.first;
                              final presentCount = sessionRecords
                                  .where((r) => r.status == 'present')
                                  .length;
                              final absentCount = sessionRecords
                                  .where((r) => r.status == 'absent')
                                  .length;
                              final totalCount = sessionRecords.length;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 1,
                                child: ListTile(
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
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '$presentCount present, $absentCount absent of $totalCount',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Edit button
                                      InkWell(
                                        onTap: () async {
                                          // Directly navigate to edit mode with pre-filled data
                                          await Navigator.push(
                                            context,
                                            SmoothPageRoute(
                                              page: TakeAttendanceScreen(
                                                classItem: widget.classItem,
                                                selectedDate: _selectedDay,
                                                existingSessionRecords: sessionRecords,
                                                existingTime: firstRecord.time,
                                                existingSessionName: firstRecord.sessionName,
                                              ),
                                            ),
                                          );
                                          _loadAttendanceCounts();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryPurple.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: AppTheme.primaryPurple,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Delete button
                                      InkWell(
                                        onTap: () {
                                          _showDeleteSessionConfirmation(
                                            sessionRecords,
                                            firstRecord.sessionDisplay,
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.error.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: AppTheme.error,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Percentage badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: presentCount == totalCount
                                              ? AppTheme.success.withOpacity(0.1)
                                              : AppTheme.warning.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${((presentCount / totalCount) * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            color: presentCount == totalCount
                                                ? AppTheme.success
                                                : AppTheme.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // History Button - 50% width
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      SmoothPageRoute(
                        page: AttendanceHistoryScreen(
                          classItem: widget.classItem,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardWhite,
                    foregroundColor: AppTheme.primaryPurple,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text(
                    'History',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Take Attendance Button - 50% width
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      SmoothPageRoute(
                        page: TakeAttendanceScreen(
                          classItem: widget.classItem,
                          selectedDate: _selectedDay,
                        ),
                      ),
                    );
                    // Reload counts after taking attendance
                    _loadAttendanceCounts();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text(
                    'Take Attendance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLegendItem({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textGrey,
          ),
        ),
      ],
    );
  }
}