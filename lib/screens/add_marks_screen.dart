import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/marks_model.dart';
import '../services/student_service.dart';
import '../services/marks_service.dart';
import '../utils/app_theme.dart';

class AddMarksScreenBulk extends StatefulWidget {
  final ClassModel classItem;
  final MarksModel? assessmentToEdit;
  final List<MarksModel>? existingMarks;

  const AddMarksScreenBulk({
    super.key,
    required this.classItem,
    this.assessmentToEdit,
    this.existingMarks,
  });

  @override
  State<AddMarksScreenBulk> createState() => _AddMarksScreenBulkState();
}

class _AddMarksScreenBulkState extends State<AddMarksScreenBulk> {
  final _assessmentNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalMarksController = TextEditingController();

  String _selectedAssessmentType = 'mock';
  DateTime _selectedDate = DateTime.now();

  List<StudentModel> _students = [];
  Map<String, TextEditingController> _marksControllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // If editing, pre-fill fields
    if (widget.assessmentToEdit != null) {
      _assessmentNameController.text = widget.assessmentToEdit!.assessmentName;
      _descriptionController.text = widget.assessmentToEdit!.description ?? '';
      _totalMarksController.text = widget.assessmentToEdit!.totalMarks.toStringAsFixed(0);
      _selectedAssessmentType = widget.assessmentToEdit!.assessmentType;

      try {
        _selectedDate = DateFormat('dd/MM/yyyy').parse(widget.assessmentToEdit!.date);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    }

    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final studentService = Provider.of<StudentService>(context, listen: false);
    final students = await studentService.getStudents(widget.classItem.id).first;

    // Sort students alphabetically by name
    students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      _students = students;
      for (var student in students) {
        _marksControllers[student.id] = TextEditingController();

        // If editing, pre-fill marks for each student
        if (widget.existingMarks != null) {
          final studentMark = widget.existingMarks!.firstWhere(
                (mark) => mark.studentId == student.id,
            orElse: () => widget.existingMarks!.first, // Fallback
          );
          if (studentMark.studentId == student.id) {
            _marksControllers[student.id]!.text =
                studentMark.obtainedMarks.toStringAsFixed(0);
          }
        }
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _assessmentNameController.dispose();
    _descriptionController.dispose();
    _totalMarksController.dispose();
    for (var controller in _marksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveMarks() async {
    // Validate common fields
    if (_assessmentNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter assessment name')),
      );
      return;
    }

    if (_totalMarksController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter total marks')),
      );
      return;
    }

    final totalMarks = double.parse(_totalMarksController.text);

    // Get all students with marks (no selection, all required)
    List<Map<String, dynamic>> studentsWithMarks = [];
    for (var student in _students) {
      final marksText = _marksControllers[student.id]!.text;

      // Skip if empty (allow optional entry)
      if (marksText.isEmpty) {
        continue;
      }

      final obtainedMarks = double.parse(marksText);

      // Validate: obtained marks cannot be negative
      if (obtainedMarks < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student.name}: Marks cannot be negative',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate: obtained marks cannot be greater than total marks
      if (obtainedMarks > totalMarks) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student.name}: Marks cannot be greater than total marks ($totalMarks)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      studentsWithMarks.add({
        'student': student,
        'obtainedMarks': obtainedMarks,
      });
    }

    if (studentsWithMarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter marks for at least one student')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final marksService = Provider.of<MarksService>(context, listen: false);
    final dateString = DateFormat('dd/MM/yyyy').format(_selectedDate);

    // Save or update marks for each student with entered marks
    bool isEditMode = widget.existingMarks != null && widget.existingMarks!.isNotEmpty;

    for (var item in studentsWithMarks) {
      final student = item['student'] as StudentModel;
      final obtainedMarks = item['obtainedMarks'] as double;

      String? error;

      if (isEditMode) {
        // Find existing mark for this student
        final existingMark = widget.existingMarks!.firstWhere(
              (mark) => mark.studentId == student.id,
          orElse: () => widget.existingMarks!.first,
        );

        if (existingMark.studentId == student.id) {
          // Update existing mark
          error = await marksService.updateMarks(
            marksId: existingMark.id,
            assessmentName: _assessmentNameController.text,
            assessmentType: _selectedAssessmentType,
            description: _descriptionController.text,
            obtainedMarks: obtainedMarks,
            totalMarks: totalMarks,
            date: dateString,
          );
        } else {
          // Student didn't have mark before, add new
          error = await marksService.addMarks(
            classId: widget.classItem.id,
            studentId: student.id,
            assessmentName: _assessmentNameController.text,
            assessmentType: _selectedAssessmentType,
            description: _descriptionController.text,
            obtainedMarks: obtainedMarks,
            totalMarks: totalMarks,
            date: dateString,
          );
        }
      } else {
        // Add new mark
        error = await marksService.addMarks(
          classId: widget.classItem.id,
          studentId: student.id,
          assessmentName: _assessmentNameController.text,
          assessmentType: _selectedAssessmentType,
          description: _descriptionController.text,
          obtainedMarks: obtainedMarks,
          totalMarks: totalMarks,
          date: dateString,
        );
      }

      if (error != null) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving marks for ${student.name}: $error')),
        );
        return;
      }
    }

    Navigator.pop(context); // Close loading
    Navigator.pop(context); // Close screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditMode
            ? 'Marks updated for ${studentsWithMarks.length} students'
            : 'Marks saved for ${studentsWithMarks.length} students'),
      ),
    );
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
                          widget.classItem.name,
                          style: AppTheme.heading2,
                        ),
                        Text(
                          widget.assessmentToEdit != null ? 'Edit Marks' : 'Add Marks',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryPurple,
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Assessment Type Selector
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeButton('mock', 'Mock', Icons.quiz_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTypeButton('assignment', 'Assignment', Icons.assignment_outlined),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Assessment Details
                    Text(
                      'Assessment Details',
                      style: AppTheme.heading3,
                    ),
                    const SizedBox(height: AppTheme.spacing12),

                    // Assessment Name
                    TextField(
                      controller: _assessmentNameController,
                      decoration: InputDecoration(
                        labelText: _selectedAssessmentType == 'mock'
                            ? 'Mock Name (e.g., Mock 1)'
                            : 'Assignment Name (e.g., Assignment 1)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: const BorderSide(color: AppTheme.borderGrey, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: const BorderSide(color: AppTheme.borderGrey, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardWhite,
                        prefixIcon: Icon(
                          _selectedAssessmentType == 'mock'
                              ? Icons.quiz_outlined
                              : Icons.assignment_outlined,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: const BorderSide(color: AppTheme.borderGrey, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: const BorderSide(color: AppTheme.borderGrey, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardWhite,
                        prefixIcon: const Icon(
                          Icons.description_outlined,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    // Total Marks and Date
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _totalMarksController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Total Marks',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: const BorderSide(color: AppTheme.borderGrey, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: const BorderSide(color: AppTheme.borderGrey, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                              ),
                              filled: true,
                              fillColor: AppTheme.cardWhite,
                              prefixIcon: const Icon(
                                Icons.grade,
                                color: AppTheme.primaryPurple,
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
                                color: AppTheme.cardWhite,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(
                                  color: AppTheme.borderGrey,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: AppTheme.primaryPurple, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Students List Header
                    Text(
                      'Students (${_students.length})',
                      style: AppTheme.heading3,
                    ),
                    const SizedBox(height: 12),

                    // Students List
                    ..._students.map((student) => _buildStudentRow(student)).toList(),
                  ],
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveMarks,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Save Marks',
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

  Widget _buildTypeButton(String type, String label, IconData icon) {
    final isSelected = _selectedAssessmentType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAssessmentType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPurple : AppTheme.borderGrey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.primaryPurple,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRow(StudentModel student) {
    // Check if marks are invalid (negative or exceed total marks)
    bool isInvalid = false;
    String? errorMessage;
    final marksText = _marksControllers[student.id]!.text;
    final totalMarksText = _totalMarksController.text;

    if (marksText.isNotEmpty) {
      try {
        final obtainedMarks = double.parse(marksText);

        // Check for negative marks
        if (obtainedMarks < 0) {
          isInvalid = true;
          errorMessage = 'Cannot be negative';
        }
        // Check if exceeds total marks
        else if (totalMarksText.isNotEmpty) {
          final totalMarks = double.parse(totalMarksText);
          if (obtainedMarks > totalMarks) {
            isInvalid = true;
            errorMessage = 'Exceeds total';
          }
        }
      } catch (e) {
        // Invalid number format
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInvalid ? Colors.red.withOpacity(0.05) : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInvalid ? Colors.red : AppTheme.borderGrey,
          width: isInvalid ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          // Student Name
          Expanded(
            flex: 2,
            child: Text(
              student.name,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isInvalid ? Colors.red : AppTheme.textDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Marks Input
          Expanded(
            child: TextField(
              controller: _marksControllers[student.id],
              keyboardType: TextInputType.number,
              onChanged: (value) {
                // Check if value is invalid (negative or exceeds total marks)
                if (value.isNotEmpty) {
                  try {
                    final obtainedMarks = double.parse(value);
                    // Check for negative or exceeding total marks
                    if (obtainedMarks < 0) {
                      HapticFeedback.heavyImpact();
                    } else if (_totalMarksController.text.isNotEmpty) {
                      final totalMarks = double.parse(_totalMarksController.text);
                      if (obtainedMarks > totalMarks) {
                        HapticFeedback.heavyImpact();
                      }
                    }
                  } catch (e) {
                    // Invalid number format
                  }
                }
                // Trigger rebuild to update border color
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Marks',
                errorText: isInvalid ? errorMessage : null,
                errorStyle: const TextStyle(fontSize: 10, height: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isInvalid ? Colors.red : AppTheme.borderGrey,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isInvalid ? Colors.red : AppTheme.borderGrey,
                    width: isInvalid ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isInvalid ? Colors.red : AppTheme.primaryPurple,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                filled: true,
                fillColor: isInvalid
                    ? Colors.red.withOpacity(0.05)
                    : AppTheme.cardWhite,
              ),
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isInvalid ? Colors.red : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}