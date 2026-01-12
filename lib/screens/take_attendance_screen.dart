// COMPLETE TAKE_ATTENDANCE_SCREEN.DART WITH TIME PICKER
// Replace your existing file with this complete version

import 'package:flutter/material.dart';
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
  final List<dynamic>? existingSessionRecords;  // For edit mode
  final String? existingTime;                    // For edit mode
  final String? existingSessionName;             // For edit mode

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

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final Map<String, String> _attendanceStatus = {};
  final _notesController = TextEditingController();
  final _sessionNameController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSaving = false;
  String _searchQuery = '';
  List<StudentModel> _students = [];
  bool _isLoading = true;

  // NEW: Time picker
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _initializeEditMode();
    _loadStudents();
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
    // If editing existing session, pre-fill data
    if (widget.existingSessionRecords != null && widget.existingSessionRecords!.isNotEmpty) {
      // Parse time
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
          // If parsing fails, use current time
          _selectedTime = TimeOfDay.now();
        }
      }

      // Set session name
      if (widget.existingSessionName != null) {
        _sessionNameController.text = widget.existingSessionName!;
      }

      // Pre-fill attendance status
      for (var record in widget.existingSessionRecords!) {
        if (record.studentId != null && record.status != null) {
          _attendanceStatus[record.studentId] = record.status;
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _sessionNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveAttendance() async {
    // Check if all students have attendance marked
    final unmarkedCount = _students.length - _attendanceStatus.length;

    if (unmarkedCount > 0) {
      // Find unmarked student names
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final attendanceService = Provider.of<AttendanceService>(context, listen: false);

    try {
      // Save all attendance records in parallel for faster performance
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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance saved for ${_attendanceStatus.length} students at ${_selectedTime.format(context)}',
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          widget.existingSessionRecords != null
                              ? 'Edit Attendance'
                              : 'Take Attendance',
                          style: AppTheme.heading2,
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(widget.selectedDate),
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // NEW: Time and Session Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Time Picker
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.access_time,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      title: const Text(
                        'Session Time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _selectedTime.format(context),
                        style: const TextStyle(
                          color: AppTheme.primaryPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.edit, color: AppTheme.primaryPurple),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.primaryPurple,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setState(() {
                            _selectedTime = time;
                          });
                        }
                      },
                    ),

                    const Divider(height: 1),

                    // Session Name Input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _sessionNameController,
                        decoration: InputDecoration(
                          labelText: 'Session Name (Optional)',
                          hintText: 'e.g., Morning Session, Lab Class',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderGrey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

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
                      _searchQuery = value.toLowerCase();
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

            // Student List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                      ),
                    )
                  : _students.isEmpty
                      ? Center(
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
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            final status = _attendanceStatus[student.id];

                            return Card(
                              margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing16,
                                  vertical: AppTheme.spacing12,
                                ),
                                child: Row(
                                  children: [
                                    // Avatar with first letter
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                      child: Text(
                                        student.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppTheme.primaryPurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacing12),
                                    // Student name
                                    Expanded(
                                      child: Text(
                                        student.name,
                                        style: AppTheme.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    // Status icons
                                    _buildCircularStatusButton(
                                      icon: Icons.check_circle,
                                      color: AppTheme.success,
                                      statusValue: 'present',
                                      isSelected: status == 'present',
                                      onTap: () {
                                        setState(() {
                                          _attendanceStatus[student.id] = 'present';
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    _buildCircularStatusButton(
                                      icon: Icons.cancel,
                                      color: AppTheme.error,
                                      statusValue: 'absent',
                                      isSelected: status == 'absent',
                                      onTap: () {
                                        setState(() {
                                          _attendanceStatus[student.id] = 'absent';
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    _buildCircularStatusButton(
                                      icon: Icons.access_time,
                                      color: Colors.blue,
                                      statusValue: 'late',
                                      isSelected: status == 'late',
                                      onTap: () {
                                        setState(() {
                                          _attendanceStatus[student.id] = 'late';
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    _buildCircularStatusButton(
                                      icon: Icons.event_busy,
                                      color: AppTheme.warning,
                                      statusValue: 'leave',
                                      isSelected: status == 'leave',
                                      onTap: () {
                                        setState(() {
                                          _attendanceStatus[student.id] = 'leave';
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    _buildCircularStatusButton(
                                      icon: Icons.local_hospital,
                                      color: Colors.pink,
                                      statusValue: 'sick',
                                      isSelected: status == 'sick',
                                      onTap: () {
                                        setState(() {
                                          _attendanceStatus[student.id] = 'sick';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Save Attendance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularStatusButton({
    required IconData icon,
    required Color color,
    required String statusValue,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? color : Colors.white,
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ]
              : [],
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : color,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}