import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, int> _attendanceCounts = {};

  late AnimationController _takeAttendanceController;
  late Animation<double> _takeAttendanceScale;
  late AnimationController _historyController;
  late Animation<double> _historyScale;

  @override
  void initState() {
    super.initState();
    _loadAttendanceCounts();

    _takeAttendanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _takeAttendanceScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _takeAttendanceController, curve: Curves.easeInOut),
    );

    _historyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _historyScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _historyController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _takeAttendanceController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceCounts() async {
    final attendanceService =
        Provider.of<AttendanceService>(context, listen: false);
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

  void _showDeleteSessionConfirmation(
      List<AttendanceModel> sessionRecords, String sessionName) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Delete Session'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete the "$sessionName" session?\n\nThis will remove attendance records for ${sessionRecords.length} students.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Deleting $sessionName...'),
                      ],
                    ),
                    backgroundColor: AppTheme.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  ),
                );

                final attendanceService =
                    Provider.of<AttendanceService>(context, listen: false);
                Future.wait(
                  sessionRecords
                      .map((record) => attendanceService.deleteAttendance(record.id)),
                ).then((_) {
                  if (mounted) {
                    _loadAttendanceCounts();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  colors: [
                    AppTheme.primaryGreen,
                    AppTheme.primaryGreen.withValues(alpha: 0.8),
                  ],
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
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attendance',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.classItem.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // History Button
                    GestureDetector(
                      onTapDown: (_) {
                        HapticFeedback.selectionClick();
                        _historyController.forward();
                      },
                      onTapUp: (_) => _historyController.reverse(),
                      onTapCancel: () => _historyController.reverse(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          SmoothPageRoute(
                            page: AttendanceHistoryScreen(
                              classItem: widget.classItem,
                            ),
                          ),
                        );
                      },
                      child: AnimatedBuilder(
                        animation: _historyScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _historyScale.value,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: AppTheme.primaryGreen,
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Calendar Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2030),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          calendarFormat: CalendarFormat.month,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            leftChevronIcon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            rightChevronIcon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            weekendTextStyle:
                                const TextStyle(color: AppTheme.error),
                            outsideDaysVisible: false,
                          ),
                          onDaySelected: (selectedDay, focusedDay) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _focusedDay = focusedDay;
                            });
                            _loadAttendanceCounts();
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              final dateOnly =
                                  DateTime(date.year, date.month, date.day);
                              final count = _attendanceCounts[dateOnly] ?? 0;

                              if (count > 0) {
                                return Positioned(
                                  right: 1,
                                  bottom: 1,
                                  child: Container(
                                    width: 8,
                                    height: 8,
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
                    ),

                    const SizedBox(height: 16),

                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(
                          color: AppTheme.success,
                          label: 'Has Attendance',
                        ),
                        const SizedBox(width: 24),
                        _buildLegendItem(
                          color: AppTheme.primaryGreen,
                          label: 'Selected',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Selected Date Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Date Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryGreen.withValues(alpha: 0.1),
                                  AppTheme.primaryGreen.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_rounded,
                                    color: AppTheme.primaryGreen,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('EEEE, MMMM d')
                                            .format(_selectedDay),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedDay.isAfter(DateTime.now())
                                            ? 'Future date'
                                            : DateFormat('yyyy')
                                                .format(_selectedDay),
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

                          // Sessions List
                          StreamBuilder<List<AttendanceModel>>(
                            stream: attendanceService.getDailyAttendanceSessions(
                              classId: widget.classItem.id,
                              date: _selectedDay,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryGreen,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.event_busy_rounded,
                                        size: 48,
                                        color:
                                            AppTheme.textGrey.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 12),
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
                              final Map<String, List<AttendanceModel>>
                                  sessions = {};
                              for (var record in records) {
                                final key = record.sessionId;
                                if (!sessions.containsKey(key)) {
                                  sessions[key] = [];
                                }
                                sessions[key]!.add(record);
                              }

                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${sessions.length} ${sessions.length == 1 ? 'Session' : 'Sessions'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...sessions.entries.map((entry) {
                                      final sessionRecords = entry.value;
                                      final firstRecord = sessionRecords.first;
                                      final presentCount = sessionRecords
                                          .where((r) => r.status == 'present')
                                          .length;
                                      final totalCount = sessionRecords.length;
                                      final percentage =
                                          ((presentCount / totalCount) * 100);

                                      return _buildSessionCard(
                                        sessionRecords: sessionRecords,
                                        firstRecord: firstRecord,
                                        presentCount: presentCount,
                                        totalCount: totalCount,
                                        percentage: percentage,
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating Take Attendance Button
      floatingActionButton: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _takeAttendanceController.forward();
        },
        onTapUp: (_) => _takeAttendanceController.reverse(),
        onTapCancel: () => _takeAttendanceController.reverse(),
        onTap: () async {
          HapticFeedback.mediumImpact();
          await Navigator.push(
            context,
            SmoothPageRoute(
              page: TakeAttendanceScreen(
                classItem: widget.classItem,
                selectedDate: _selectedDay,
              ),
            ),
          );
          _loadAttendanceCounts();
        },
        child: AnimatedBuilder(
          animation: _takeAttendanceScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _takeAttendanceScale.value,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.primaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.how_to_reg_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Take Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
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

  Widget _buildSessionCard({
    required List<AttendanceModel> sessionRecords,
    required AttendanceModel firstRecord,
    required int presentCount,
    required int totalCount,
    required double percentage,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Time icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Session info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstRecord.sessionDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$presentCount present of $totalCount students',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              GestureDetector(
                onTapDown: (_) => HapticFeedback.selectionClick(),
                onTap: () async {
                  HapticFeedback.lightImpact();
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              GestureDetector(
                onTapDown: (_) => HapticFeedback.selectionClick(),
                onTap: () {
                  _showDeleteSessionConfirmation(
                    sessionRecords,
                    firstRecord.sessionDisplay,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Percentage badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: percentage >= 80
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : percentage >= 60
                          ? AppTheme.warning.withValues(alpha: 0.1)
                          : AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: percentage >= 80
                        ? AppTheme.success
                        : percentage >= 60
                            ? AppTheme.warning
                            : AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
