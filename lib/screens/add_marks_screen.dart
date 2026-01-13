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

class _AddMarksScreenBulkState extends State<AddMarksScreenBulk>
    with TickerProviderStateMixin {
  final _assessmentNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalMarksController = TextEditingController();

  String _selectedAssessmentType = 'mock';
  DateTime _selectedDate = DateTime.now();

  List<StudentModel> _students = [];
  Map<String, TextEditingController> _marksControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;

  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonScale;

  @override
  void initState() {
    super.initState();

    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _saveButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeInOut),
    );

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

    students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      _students = students;
      for (var student in students) {
        _marksControllers[student.id] = TextEditingController();

        if (widget.existingMarks != null) {
          final studentMark = widget.existingMarks!.firstWhere(
            (mark) => mark.studentId == student.id,
            orElse: () => widget.existingMarks!.first,
          );
          if (studentMark.studentId == student.id) {
            _marksControllers[student.id]!.text = studentMark.obtainedMarks.toStringAsFixed(0);
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
    _saveButtonController.dispose();
    for (var controller in _marksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
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
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      HapticFeedback.lightImpact();
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _saveMarks() async {
    if (_assessmentNameController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showSnackBar('Please enter assessment name', Colors.red);
      return;
    }

    if (_totalMarksController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showSnackBar('Please enter total marks', Colors.red);
      return;
    }

    final totalMarks = double.parse(_totalMarksController.text);

    List<Map<String, dynamic>> studentsWithMarks = [];
    for (var student in _students) {
      final marksText = _marksControllers[student.id]!.text;

      if (marksText.isEmpty) continue;

      final obtainedMarks = double.parse(marksText);

      if (obtainedMarks < 0) {
        HapticFeedback.heavyImpact();
        _showSnackBar('${student.name}: Marks cannot be negative', Colors.red);
        return;
      }

      if (obtainedMarks > totalMarks) {
        HapticFeedback.heavyImpact();
        _showSnackBar('${student.name}: Marks cannot exceed $totalMarks', Colors.red);
        return;
      }

      studentsWithMarks.add({
        'student': student,
        'obtainedMarks': obtainedMarks,
      });
    }

    if (studentsWithMarks.isEmpty) {
      HapticFeedback.heavyImpact();
      _showSnackBar('Please enter marks for at least one student', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final marksService = Provider.of<MarksService>(context, listen: false);
    final dateString = DateFormat('dd/MM/yyyy').format(_selectedDate);

    bool isEditMode = widget.existingMarks != null && widget.existingMarks!.isNotEmpty;

    for (var item in studentsWithMarks) {
      final student = item['student'] as StudentModel;
      final obtainedMarks = item['obtainedMarks'] as double;

      String? error;

      if (isEditMode) {
        final existingMark = widget.existingMarks!.firstWhere(
          (mark) => mark.studentId == student.id,
          orElse: () => widget.existingMarks!.first,
        );

        if (existingMark.studentId == student.id) {
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
        setState(() => _isSaving = false);
        HapticFeedback.heavyImpact();
        _showSnackBar('Error saving marks for ${student.name}', Colors.red);
        return;
      }
    }

    setState(() => _isSaving = false);

    if (!mounted) return;

    HapticFeedback.lightImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(isEditMode
                ? 'Marks updated for ${studentsWithMarks.length} students'
                : 'Marks saved for ${studentsWithMarks.length} students'),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAssessmentTypeToggle(),
                          const SizedBox(height: 20),
                          _buildAssessmentDetailsCard(),
                          const SizedBox(height: 20),
                          _buildStudentsHeader(),
                          const SizedBox(height: 12),
                          ..._students.map((student) => _buildStudentRow(student)),
                        ],
                      ),
                    ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTapDown: (_) => HapticFeedback.selectionClick(),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.classItem.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.assessmentToEdit != null ? 'Edit Marks' : 'Add Marks',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(6),
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
      child: Row(
        children: [
          Expanded(child: _buildTypeButton('mock', 'Mock', Icons.quiz_rounded)),
          Expanded(child: _buildTypeButton('assignment', 'Assignment', Icons.assignment_rounded)),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon) {
    final isSelected = _selectedAssessmentType == type;
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () {
        if (!isSelected) {
          HapticFeedback.lightImpact();
          setState(() => _selectedAssessmentType = type);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assessment Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 16),

          // Assessment Name
          _buildInputField(
            controller: _assessmentNameController,
            label: _selectedAssessmentType == 'mock' ? 'Mock Name' : 'Assignment Name',
            hint: _selectedAssessmentType == 'mock' ? 'e.g., Mock 1' : 'e.g., Assignment 1',
            icon: _selectedAssessmentType == 'mock' ? Icons.quiz_rounded : Icons.assignment_rounded,
          ),

          const SizedBox(height: 14),

          // Total Marks and Date Row
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _totalMarksController,
                  label: 'Total Marks',
                  hint: '100',
                  icon: Icons.stars_rounded,
                  iconColor: const Color(0xFFFFB300),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => HapticFeedback.selectionClick(),
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF2196F3),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                              Text(
                                DateFormat('dd MMM').format(_selectedDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Description (Optional)
          _buildInputField(
            controller: _descriptionController,
            label: 'Notes (Optional)',
            hint: 'Add any notes...',
            icon: Icons.note_rounded,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color? iconColor,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryPurple).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor ?? AppTheme.primaryPurple, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Students',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.lightPurple,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_students.length}',
            style: const TextStyle(
              color: AppTheme.primaryPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentRow(StudentModel student) {
    bool isInvalid = false;
    String? errorMessage;
    final marksText = _marksControllers[student.id]!.text;
    final totalMarksText = _totalMarksController.text;

    if (marksText.isNotEmpty) {
      try {
        final obtainedMarks = double.parse(marksText);
        if (obtainedMarks < 0) {
          isInvalid = true;
          errorMessage = 'Negative';
        } else if (totalMarksText.isNotEmpty) {
          final totalMarks = double.parse(totalMarksText);
          if (obtainedMarks > totalMarks) {
            isInvalid = true;
            errorMessage = 'Max: $totalMarksText';
          }
        }
      } catch (e) {
        // Invalid format
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isInvalid ? Border.all(color: Colors.red, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isInvalid
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isInvalid
                  ? Colors.red.withValues(alpha: 0.1)
                  : AppTheme.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isInvalid ? Colors.red : AppTheme.primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              student.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isInvalid ? Colors.red : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Marks Input
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isInvalid ? Colors.red.withValues(alpha: 0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isInvalid ? Colors.red : Colors.grey[300]!,
                      width: isInvalid ? 2 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _marksControllers[student.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isInvalid ? Colors.red : AppTheme.textDark,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && totalMarksText.isNotEmpty) {
                        try {
                          final obtained = double.parse(value);
                          final total = double.parse(totalMarksText);
                          if (obtained > total || obtained < 0) {
                            HapticFeedback.heavyImpact();
                          }
                        } catch (e) {
                          // Ignore
                        }
                      }
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: '—',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                  ),
                ),
                if (isInvalid && errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _saveButtonController.forward();
        },
        onTapUp: (_) => _saveButtonController.reverse(),
        onTapCancel: () => _saveButtonController.reverse(),
        onTap: _isSaving ? null : _saveMarks,
        child: AnimatedBuilder(
          animation: _saveButtonScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _saveButtonScale.value,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryPurple,
                      AppTheme.primaryPurple.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              widget.assessmentToEdit != null ? 'Update Marks' : 'Save Marks',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
