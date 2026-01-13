import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with TickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();

  late AnimationController _monthLeftController;
  late AnimationController _monthRightController;
  late Animation<double> _monthLeftScale;
  late Animation<double> _monthRightScale;

  @override
  void initState() {
    super.initState();
    _monthLeftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _monthRightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _monthLeftScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _monthLeftController, curve: Curves.easeInOut),
    );
    _monthRightScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _monthRightController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _monthLeftController.dispose();
    _monthRightController.dispose();
    super.dispose();
  }

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
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            _buildHeader(),

            // Month Selector
            _buildMonthSelector(),

            // History List
            Expanded(
              child: _buildHistoryList(attendanceService),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
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
                const Text(
                  'Attendance History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.classItem.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTapDown: (_) => HapticFeedback.selectionClick(),
            onTap: () async {
              HapticFeedback.lightImpact();
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDatePickerMode: DatePickerMode.year,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF00BFA5),
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: AppTheme.textDark,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedMonth = DateTime(picked.year, picked.month);
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTapDown: (_) {
              HapticFeedback.selectionClick();
              _monthLeftController.forward();
            },
            onTapUp: (_) => _monthLeftController.reverse(),
            onTapCancel: () => _monthLeftController.reverse(),
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
            child: AnimatedBuilder(
              animation: _monthLeftScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _monthLeftScale.value,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppTheme.textDark,
                      size: 26,
                    ),
                  ),
                );
              },
            ),
          ),
          Column(
            children: [
              Text(
                DateFormat('MMMM').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                DateFormat('yyyy').format(_selectedMonth),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTapDown: (_) {
              HapticFeedback.selectionClick();
              _monthRightController.forward();
            },
            onTapUp: (_) => _monthRightController.reverse(),
            onTapCancel: () => _monthRightController.reverse(),
            onTap: () {
              final nextMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
              );
              if (nextMonth.isBefore(DateTime.now()) ||
                  nextMonth.month == DateTime.now().month) {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedMonth = nextMonth;
                });
              } else {
                HapticFeedback.heavyImpact();
              }
            },
            child: AnimatedBuilder(
              animation: _monthRightScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _monthRightScale.value,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textDark,
                      size: 26,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(AttendanceService attendanceService) {
    return StreamBuilder<List<AttendanceModel>>(
      stream: attendanceService.getAllClassAttendance(widget.classItem.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00BFA5),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('No attendance records', 'Start taking attendance to see history');
        }

        final allRecords = snapshot.data!;
        final monthRecords = allRecords.where((record) {
          return record.date.year == _selectedMonth.year &&
              record.date.month == _selectedMonth.month;
        }).toList();

        if (monthRecords.isEmpty) {
          return _buildEmptyState(
            'No records for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            'Try selecting a different month',
          );
        }

        final groupedByDate = _groupByDate(monthRecords);
        final sortedDates = groupedByDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateKey = sortedDates[index];
            final dateRecords = groupedByDate[dateKey]!;
            final date = dateRecords.first.date;
            final sessions = _groupBySession(dateRecords);
            return _buildDateCard(date, sessions);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
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
              Icons.history_rounded,
              size: 60,
              color: const Color(0xFF00BFA5).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(DateTime date, Map<String, List<AttendanceModel>> sessions) {
    final colors = [
      const Color(0xFF00BFA5),
      const Color(0xFF7C4DFF),
      const Color(0xFF2196F3),
      const Color(0xFFFF6D00),
      const Color(0xFFE91E63),
    ];
    final colorIndex = date.day % colors.length;
    final cardColor = colors[colorIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor, cardColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${sessions.length} ${sessions.length == 1 ? 'Session' : 'Sessions'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
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
    final sortedRecords = List<AttendanceModel>.from(sessionRecords);
    sortedRecords.sort((a, b) => a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

    final firstRecord = sortedRecords.first;
    final presentCount = sessionRecords.where((r) => r.status == 'present').length;
    final absentCount = sessionRecords.where((r) => r.status == 'absent').length;
    final lateCount = sessionRecords.where((r) => r.status == 'late').length;
    final leaveCount = sessionRecords.where((r) => r.status == 'leave').length;
    final sickCount = sessionRecords.where((r) => r.status == 'sick').length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                  const Color(0xFF7C4DFF).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF7C4DFF),
              size: 22,
            ),
          ),
          title: Text(
            firstRecord.sessionDisplay,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textDark,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (presentCount > 0)
                  _buildStatusChip('$presentCount Present', const Color(0xFF4CAF50)),
                if (absentCount > 0)
                  _buildStatusChip('$absentCount Absent', const Color(0xFFE53935)),
                if (lateCount > 0)
                  _buildStatusChip('$lateCount Late', const Color(0xFF2196F3)),
                if (leaveCount > 0)
                  _buildStatusChip('$leaveCount Leave', const Color(0xFFFF9800)),
                if (sickCount > 0)
                  _buildStatusChip('$sickCount Sick', const Color(0xFFE91E63)),
              ],
            ),
          ),
          onExpansionChanged: (expanded) {
            HapticFeedback.selectionClick();
          },
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: sortedRecords.asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  return Container(
                    decoration: BoxDecoration(
                      border: index < sortedRecords.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.1),
                              ),
                            )
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(record.status),
                              _getStatusColor(record.status).withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(record.status).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getStatusIcon(record.status),
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        record.studentName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(record.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          record.status.substring(0, 1).toUpperCase() +
                              record.status.substring(1),
                          style: TextStyle(
                            color: _getStatusColor(record.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
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
}
