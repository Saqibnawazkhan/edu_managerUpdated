import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/student_service.dart';
import '../services/marks_service.dart';
import '../utils/app_theme.dart';

class MarksManagementScreen extends StatefulWidget {
  final ClassModel classItem;

  const MarksManagementScreen({super.key, required this.classItem});

  @override
  State<MarksManagementScreen> createState() => _MarksManagementScreenState();
}

class _MarksManagementScreenState extends State<MarksManagementScreen> {
  final _assessmentNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalMarksController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedAssessmentType = 'mock'; // Default to mock
  final Map<String, double> _studentMarks = {};

  @override
  void dispose() {
    _assessmentNameController.dispose();
    _descriptionController.dispose();
    _totalMarksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveAllMarks() async {
    if (_assessmentNameController.text.isEmpty ||
        _totalMarksController.text.isEmpty ||
        _studentMarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields and enter marks for at least one student'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final marksService = Provider.of<MarksService>(context, listen: false);
    final totalMarks = double.parse(_totalMarksController.text);
    final dateString = DateFormat('dd/MM/yyyy').format(_selectedDate);

    try {
      for (var entry in _studentMarks.entries) {
        await marksService.addMarks(
          classId: widget.classItem.id,
          studentId: entry.key,
          assessmentName: _assessmentNameController.text,
          assessmentType: _selectedAssessmentType,
          description: _descriptionController.text,
          obtainedMarks: entry.value,
          totalMarks: totalMarks,
          date: dateString,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_assessmentNameController.text} marks saved for ${_studentMarks.length} students!'),
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
            content: Text('Error saving marks: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showMarksDialog(String studentId, String studentName) {
    String marksValue = _studentMarks[studentId]?.toString() ?? '';
    final marksController = TextEditingController(text: marksValue);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                    child: Text(
                      studentName.isNotEmpty ? studentName.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: AppTheme.heading3,
                        ),
                        Text(
                          'Enter ${_selectedAssessmentType == 'mock' ? 'Mock' : 'Assignment'} Marks',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_totalMarksController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.grade, color: AppTheme.primaryPurple),
                          const SizedBox(width: 8),
                          Text(
                            'Total Marks: ${_totalMarksController.text}',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Obtained Marks',
                      hintText: 'Enter marks',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.edit),
                    ),
                    controller: marksController,
                    onChanged: (value) {
                      marksValue = value;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    marksController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (marksValue.isNotEmpty) {
                      final marks = double.tryParse(marksValue);
                      if (marks != null) {
                        setState(() {
                          _studentMarks[studentId] = marks;
                        });
                        marksController.dispose();
                        Navigator.pop(dialogContext);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Ensure controller is disposed if dialog is dismissed by back button
      if (marksController.hasListeners) {
        marksController.dispose();
      }
    });
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
                          widget.classItem.name,
                          style: AppTheme.heading2,
                        ),
                        Text(
                          'Manage Marks',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Assessment Type Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAssessmentType = 'mock';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedAssessmentType == 'mock'
                                ? AppTheme.primaryPurple
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                color: _selectedAssessmentType == 'mock'
                                    ? Colors.white
                                    : AppTheme.textGrey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mock',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: _selectedAssessmentType == 'mock'
                                      ? Colors.white
                                      : AppTheme.textGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAssessmentType = 'assignment';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedAssessmentType == 'assignment'
                                ? AppTheme.primaryBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                color: _selectedAssessmentType == 'assignment'
                                    ? Colors.white
                                    : AppTheme.textGrey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Assignment',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: _selectedAssessmentType == 'assignment'
                                      ? Colors.white
                                      : AppTheme.textGrey,
                                  fontWeight: FontWeight.w600,
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
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Assessment Details Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _selectedAssessmentType == 'mock'
                        ? [AppTheme.primaryPurple, AppTheme.primaryPurple.withOpacity(0.7)]
                        : [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    // Assessment Name
                    TextField(
                      controller: _assessmentNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _selectedAssessmentType == 'mock'
                            ? 'Mock Name (e.g., Mock 1)'
                            : 'Assignment Name (e.g., Assignment 1)',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(
                          _selectedAssessmentType == 'mock'
                              ? Icons.quiz_outlined
                              : Icons.assignment_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Description (optional)',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.description_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Total Marks and Date Row
                    Row(
                      children: [
                        // Total Marks
                        Expanded(
                          child: TextField(
                            controller: _totalMarksController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Total Marks',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.grade,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Date Picker
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd/MM/yy').format(_selectedDate),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Students List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Students',
                    style: AppTheme.heading3,
                  ),
                  if (_studentMarks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_studentMarks.length} marked',
                        style: AppTheme.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing12),

            // Students List
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

                  final students = snapshot.data!;
                  students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final hasMark = _studentMarks.containsKey(student.id);
                      final marks = _studentMarks[student.id];

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardWhite,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.cardShadow,
                          border: Border.all(
                            color: hasMark
                                ? AppTheme.success.withOpacity(0.5)
                                : AppTheme.borderGrey,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(AppTheme.spacing12),
                          leading: CircleAvatar(
                            backgroundColor: _selectedAssessmentType == 'mock'
                                ? AppTheme.primaryPurple.withOpacity(0.1)
                                : AppTheme.primaryBlue.withOpacity(0.1),
                            child: Text(
                              student.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: _selectedAssessmentType == 'mock'
                                    ? AppTheme.primaryPurple
                                    : AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            student.name,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: hasMark
                              ? Text(
                            'Marks: ${marks?.toStringAsFixed(0)}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                              : Text(
                            'Tap to enter marks',
                            style: AppTheme.bodySmall,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: hasMark
                                  ? AppTheme.success
                                  : (_selectedAssessmentType == 'mock'
                                  ? AppTheme.primaryPurple
                                  : AppTheme.primaryBlue),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              hasMark ? 'Edit' : 'Enter',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () => _showMarksDialog(student.id, student.name),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Save Button
            if (_studentMarks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveAllMarks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedAssessmentType == 'mock'
                          ? AppTheme.primaryPurple
                          : AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save),
                        const SizedBox(width: 8),
                        Text(
                          'Save All Marks (${_studentMarks.length})',
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
}