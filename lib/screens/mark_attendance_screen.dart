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

  const TakeAttendanceScreen({
    super.key,
    required this.classItem,
    required this.selectedDate,
  });

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final Map<String, String> _attendanceStatus = {};
  final _notesController = TextEditingController();
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveAttendance() async {
    if (_attendanceStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please mark attendance for at least one student'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final attendanceService = Provider.of<AttendanceService>(context, listen: false);
    final studentService = Provider.of<StudentService>(context, listen: false);

    try {
      final students = await studentService.getStudents(widget.classItem.id).first;

      for (var entry in _attendanceStatus.entries) {
        final studentId = entry.key;
        final status = entry.value;
        final student = students.firstWhere((s) => s.id == studentId);

        await attendanceService.markAttendance(
          classId: widget.classItem.id,
          studentId: studentId,
          studentName: student.name,
          status: status,
          date: widget.selectedDate,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance saved for ${_attendanceStatus.length} students'),
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentService = Provider.of<StudentService>(context);

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
                          'Take Attendance',
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

            // Notes Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)',
                    hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textGrey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.cardWhite,
                    contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Student List
            Expanded(
              child: StreamBuilder<List<StudentModel>>(
                stream: studentService.getStudents(widget.classItem.id),
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
                    );
                  }

                  var students = snapshot.data!;

                  // Sort alphabetically
                  students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    students = students
                        .where((s) => s.name.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  if (students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: AppTheme.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            'No students found',
                            style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final currentStatus = _attendanceStatus[student.id];

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                        padding: const EdgeInsets.all(AppTheme.spacing12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardWhite,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.cardShadow,
                          border: Border.all(
                            color: currentStatus != null
                                ? _getStatusColor(currentStatus).withOpacity(0.5)
                                : AppTheme.borderGrey,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Student Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                              child: Text(
                                student.name.isNotEmpty ? student.name.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Student Name
                            Expanded(
                              child: Text(
                                student.name,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Attendance Status Icons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatusIcon(
                                  icon: Icons.check_circle,
                                  color: AppTheme.success,
                                  status: 'present',
                                  studentId: student.id,
                                  currentStatus: currentStatus,
                                ),
                                const SizedBox(width: 4),
                                _buildStatusIcon(
                                  icon: Icons.cancel,
                                  color: AppTheme.error,
                                  status: 'absent',
                                  studentId: student.id,
                                  currentStatus: currentStatus,
                                ),
                                const SizedBox(width: 4),
                                _buildStatusIcon(
                                  icon: Icons.access_time,
                                  color: AppTheme.info,
                                  status: 'late',
                                  studentId: student.id,
                                  currentStatus: currentStatus,
                                ),
                                const SizedBox(width: 4),
                                _buildStatusIcon(
                                  icon: Icons.local_hospital,
                                  color: AppTheme.warning,
                                  status: 'sick',
                                  studentId: student.id,
                                  currentStatus: currentStatus,
                                ),
                                const SizedBox(width: 4),
                                _buildStatusIcon(
                                  icon: Icons.exit_to_app,
                                  color: AppTheme.primaryYellow,
                                  status: 'short_leave',
                                  studentId: student.id,
                                  currentStatus: currentStatus,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save),
                      const SizedBox(width: 8),
                      Text(
                        _attendanceStatus.isEmpty
                            ? 'Save Attendance'
                            : 'Save Attendance (${_attendanceStatus.length})',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
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

  Widget _buildStatusIcon({
    required IconData icon,
    required Color color,
    required String status,
    required String studentId,
    String? currentStatus,
  }) {
    final isSelected = currentStatus == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceStatus[studentId] = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : color,
        ),
      ),
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
        return AppTheme.borderGrey;
    }
  }
}