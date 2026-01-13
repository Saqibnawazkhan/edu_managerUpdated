import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/student_service.dart';
import '../services/attendance_service.dart';
import '../utils/app_theme.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final ClassModel classItem;
  final DateTime selectedDate;
  final List<dynamic>? existingSessionRecords;
  final String? existingTime;
  final String? existingSessionName;

  const TakeAttendanceScreen({
    super.key,
    required this.classItem,
    required this.selectedDate,
    this.existingSessionRecords,
    this.existingTime,
    this.existingSessionName,
  });

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen>
    with TickerProviderStateMixin {
  final Map<String, String> _attendanceStatus = {};
  final _sessionNameController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSaving = false;
  String _searchQuery = '';
  List<StudentModel> _students = [];
  bool _isLoading = true;
  TimeOfDay _selectedTime = TimeOfDay.now();

  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonScale;
  late AnimationController _markAllController;
  late Animation<double> _markAllScale;

  @override
  void initState() {
    super.initState();
    _initializeEditMode();
    _loadStudents();

    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _saveButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeInOut),
    );

    _markAllController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _markAllScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _markAllController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadStudents() async {
    final studentService = Provider.of<StudentService>(context, listen: false);
    final students = await studentService.getStudents(widget.classItem.id).first;
    students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) {
      setState(() {
        _students = students;
        _isLoading = false;
      });
    }
  }

  List<StudentModel> get _filteredStudents {
    if (_searchQuery.isEmpty) {
      return _students;
    }
    return _students
        .where((s) => s.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _initializeEditMode() {
    if (widget.existingSessionRecords != null &&
        widget.existingSessionRecords!.isNotEmpty) {
      if (widget.existingTime != null) {
        try {
          final timeParts = widget.existingTime!.split(' ');
          if (timeParts.length == 2) {
            final timeNumbers = timeParts[0].split(':');
            var hour = int.parse(timeNumbers[0]);
            final minute = int.parse(timeNumbers[1]);
            final isPM = timeParts[1].toUpperCase() == 'PM';

            if (isPM && hour != 12) hour += 12;
            if (!isPM && hour == 12) hour = 0;

            _selectedTime = TimeOfDay(hour: hour, minute: minute);
          }
        } catch (e) {
          _selectedTime = TimeOfDay.now();
        }
      }

      if (widget.existingSessionName != null) {
        _sessionNameController.text = widget.existingSessionName!;
      }

      for (var record in widget.existingSessionRecords!) {
        if (record.studentId != null && record.status != null) {
          _attendanceStatus[record.studentId] = record.status;
        }
      }
    }
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _scrollController.dispose();
    _saveButtonController.dispose();
    _markAllController.dispose();
    super.dispose();
  }

  void _markAllAs(String status) {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var student in _students) {
        _attendanceStatus[student.id] = status;
      }
    });
  }

  Future<void> _saveAttendance() async {
    final unmarkedCount = _students.length - _attendanceStatus.length;

    if (unmarkedCount > 0) {
      HapticFeedback.heavyImpact();
      final unmarkedStudents = _students
          .where((s) => !_attendanceStatus.containsKey(s.id))
          .take(3)
          .map((s) => s.name)
          .toList();

      String message;
      if (unmarkedCount == 1) {
        message = 'Please mark attendance for ${unmarkedStudents.first}';
      } else if (unmarkedCount <= 3) {
        message = 'Please mark attendance for: ${unmarkedStudents.join(", ")}';
      } else {
        message = 'Please mark attendance for all students ($unmarkedCount remaining)';
      }

      _showSnackBar(message, AppTheme.warning);
      return;
    }

    setState(() => _isSaving = true);

    final attendanceService =
        Provider.of<AttendanceService>(context, listen: false);

    try {
      await Future.wait(
        _attendanceStatus.entries.map((entry) {
          final studentId = entry.key;
          final status = entry.value;
          final student = _students.firstWhere((s) => s.id == studentId);

          return attendanceService.markAttendance(
            classId: widget.classItem.id,
            studentId: studentId,
            studentName: student.name,
            status: status,
            date: widget.selectedDate,
            time: _selectedTime,
            sessionName: _sessionNameController.text.isNotEmpty
                ? _sessionNameController.text
                : null,
          );
        }),
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.pop(context, true);
        _showSnackBar(
          'Attendance saved for ${_attendanceStatus.length} students',
          AppTheme.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSnackBar('Error saving attendance: $e', AppTheme.error);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppTheme.success
                  ? Icons.check_circle_rounded
                  : color == AppTheme.error
                      ? Icons.error_rounded
                      : Icons.info_rounded,
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

  void _showTimePicker() async {
    HapticFeedback.selectionClick();
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _showMarkAllSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mark All Students',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMarkAllOption(
                    icon: Icons.check_circle_rounded,
                    label: 'Present',
                    color: AppTheme.success,
                    onTap: () {
                      Navigator.pop(context);
                      _markAllAs('present');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMarkAllOption(
                    icon: Icons.cancel_rounded,
                    label: 'Absent',
                    color: AppTheme.error,
                    onTap: () {
                      Navigator.pop(context);
                      _markAllAs('absent');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMarkAllOption(
                    icon: Icons.access_time_rounded,
                    label: 'Late',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _markAllAs('late');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMarkAllOption(
                    icon: Icons.event_busy_rounded,
                    label: 'Leave',
                    color: AppTheme.warning,
                    onTap: () {
                      Navigator.pop(context);
                      _markAllAs('leave');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkAllOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentCount =
        _attendanceStatus.values.where((s) => s == 'present').length;
    final absentCount =
        _attendanceStatus.values.where((s) => s == 'absent').length;
    final lateCount =
        _attendanceStatus.values.where((s) => s == 'late').length;
    final leaveCount =
        _attendanceStatus.values.where((s) => s == 'leave').length;
    final sickCount =
        _attendanceStatus.values.where((s) => s == 'sick').length;

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
                child: Column(
                  children: [
                    // Top row with back button and title
                    Row(
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
                              Text(
                                widget.existingSessionRecords != null
                                    ? 'Edit Attendance'
                                    : 'Take Attendance',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${widget.classItem.name} - ${DateFormat('MMM dd').format(widget.selectedDate)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Mark All Button
                        GestureDetector(
                          onTapDown: (_) {
                            HapticFeedback.selectionClick();
                            _markAllController.forward();
                          },
                          onTapUp: (_) => _markAllController.reverse(),
                          onTapCancel: () => _markAllController.reverse(),
                          onTap: _showMarkAllSheet,
                          child: AnimatedBuilder(
                            animation: _markAllScale,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _markAllScale.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
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
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.done_all_rounded,
                                        color: AppTheme.primaryGreen,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Mark All',
                                        style: TextStyle(
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stats row
                    Row(
                      children: [
                        _buildStatChip('Present', presentCount, AppTheme.success),
                        const SizedBox(width: 8),
                        _buildStatChip('Absent', absentCount, AppTheme.error),
                        const SizedBox(width: 8),
                        _buildStatChip('Late', lateCount, Colors.blue),
                        const SizedBox(width: 8),
                        _buildStatChip(
                            'Other', leaveCount + sickCount, AppTheme.warning),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Time & Session Card
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Column(
                        children: [
                          // Time Picker Row
                          GestureDetector(
                            onTapDown: (_) => HapticFeedback.selectionClick(),
                            onTap: _showTimePicker,
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
                                    Icons.access_time_rounded,
                                    color: AppTheme.primaryGreen,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Session Time',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                      Text(
                                        _selectedTime.format(context),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: AppTheme.primaryGreen,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          // Session Name Input
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextField(
                              controller: _sessionNameController,
                              onTap: () => HapticFeedback.selectionClick(),
                              decoration: InputDecoration(
                                labelText: 'Session Name (Optional)',
                                hintText: 'e.g., Morning Class, Lab Session',
                                prefixIcon: const Icon(
                                  Icons.label_rounded,
                                  color: AppTheme.primaryGreen,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8F9FE),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onTap: () => HapticFeedback.selectionClick(),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search students...',
                          hintStyle: const TextStyle(color: AppTheme.textGrey),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.textGrey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Student List
                    if (_isLoading)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else if (_students.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline_rounded,
                                    size: 64,
                                    color: AppTheme.textGrey.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No students in this class',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_filteredStudents.length, (index) {
                        final student = _filteredStudents[index];
                        final status = _attendanceStatus[student.id];
                        return _buildStudentCard(student, status);
                      }),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating Save Button
      floatingActionButton: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _saveButtonController.forward();
        },
        onTapUp: (_) => _saveButtonController.reverse(),
        onTapCancel: () => _saveButtonController.reverse(),
        onTap: _isSaving ? null : _saveAttendance,
        child: AnimatedBuilder(
          animation: _saveButtonScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _saveButtonScale.value,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    else ...[
                      const Icon(Icons.save_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Save Attendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
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

  Widget _buildStatChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentModel student, String? status) {
    Color? cardBorderColor;
    if (status == 'present') cardBorderColor = AppTheme.success;
    if (status == 'absent') cardBorderColor = AppTheme.error;
    if (status == 'late') cardBorderColor = Colors.blue;
    if (status == 'leave') cardBorderColor = AppTheme.warning;
    if (status == 'sick') cardBorderColor = Colors.pink;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: cardBorderColor != null
            ? Border.all(color: cardBorderColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: (cardBorderColor ?? Colors.black).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.primaryGreen.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    student.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (status != null)
                      Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          fontSize: 13,
                          color: cardBorderColor ?? AppTheme.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Status buttons
          Row(
            children: [
              Expanded(
                child: _buildStatusButton(
                  icon: Icons.check_circle_rounded,
                  label: 'Present',
                  color: AppTheme.success,
                  isSelected: status == 'present',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _attendanceStatus[student.id] = 'present';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusButton(
                  icon: Icons.cancel_rounded,
                  label: 'Absent',
                  color: AppTheme.error,
                  isSelected: status == 'absent',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _attendanceStatus[student.id] = 'absent';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusButton(
                  icon: Icons.access_time_rounded,
                  label: 'Late',
                  color: Colors.blue,
                  isSelected: status == 'late',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _attendanceStatus[student.id] = 'late';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusButton(
                  icon: Icons.event_busy_rounded,
                  label: 'Leave',
                  color: AppTheme.warning,
                  isSelected: status == 'leave',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _attendanceStatus[student.id] = 'leave';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusButton(
                  icon: Icons.local_hospital_rounded,
                  label: 'Sick',
                  color: Colors.pink,
                  isSelected: status == 'sick',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _attendanceStatus[student.id] = 'sick';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isSelected ? 1 : 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
