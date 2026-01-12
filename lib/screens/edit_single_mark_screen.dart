import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/marks_model.dart';
import '../models/student_model.dart';
import '../services/marks_service.dart';
import '../utils/app_theme.dart';

class EditSingleMarkScreen extends StatefulWidget {
  final ClassModel classItem;
  final MarksModel markToEdit;
  final String studentName;

  const EditSingleMarkScreen({
    super.key,
    required this.classItem,
    required this.markToEdit,
    required this.studentName,
  });

  @override
  State<EditSingleMarkScreen> createState() => _EditSingleMarkScreenState();
}

class _EditSingleMarkScreenState extends State<EditSingleMarkScreen> {
  final _assessmentNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalMarksController = TextEditingController();
  final _obtainedMarksController = TextEditingController();
  
  String _selectedAssessmentType = 'mock';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Populate fields with existing mark data
    _assessmentNameController.text = widget.markToEdit.assessmentName;
    _descriptionController.text = widget.markToEdit.description ?? '';
    _totalMarksController.text = widget.markToEdit.totalMarks.toStringAsFixed(0);
    _obtainedMarksController.text = widget.markToEdit.obtainedMarks.toStringAsFixed(0);
    _selectedAssessmentType = widget.markToEdit.assessmentType;
    
    // Parse date from DD/MM/YYYY format
    try {
      _selectedDate = DateFormat('dd/MM/yyyy').parse(widget.markToEdit.date);
    } catch (e) {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _assessmentNameController.dispose();
    _descriptionController.dispose();
    _totalMarksController.dispose();
    _obtainedMarksController.dispose();
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

  bool _isObtainedMarksValid() {
    if (_obtainedMarksController.text.isEmpty || _totalMarksController.text.isEmpty) {
      return true;
    }
    try {
      final obtained = double.parse(_obtainedMarksController.text);
      final total = double.parse(_totalMarksController.text);
      return obtained <= total;
    } catch (e) {
      return true;
    }
  }

  Future<void> _saveMarks() async {
    // Validate
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

    if (_obtainedMarksController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter obtained marks')),
      );
      return;
    }

    // Validate obtained marks
    if (!_isObtainedMarksValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obtained marks cannot be greater than total marks'),
          backgroundColor: Colors.red,
        ),
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

    final error = await marksService.updateMarks(
      marksId: widget.markToEdit.id,
      assessmentName: _assessmentNameController.text,
      assessmentType: _selectedAssessmentType,
      description: _descriptionController.text,
      obtainedMarks: double.parse(_obtainedMarksController.text),
      totalMarks: double.parse(_totalMarksController.text),
      date: dateString,
    );

    Navigator.pop(context); // Close loading

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } else {
      Navigator.pop(context); // Close screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marks updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInvalid = !_isObtainedMarksValid();

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
                          widget.studentName,
                          style: AppTheme.heading2,
                        ),
                        const Text(
                          'Edit Marks',
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
              child: SingleChildScrollView(
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

                    // Total Marks and Obtained Marks
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _totalMarksController,
                            keyboardType: TextInputType.number,
                            onChanged: (value) => setState(() {}),
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
                        Expanded(
                          child: TextField(
                            controller: _obtainedMarksController,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              if (!_isObtainedMarksValid()) {
                                HapticFeedback.heavyImpact();
                              }
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              labelText: 'Obtained Marks',
                              errorText: isInvalid ? 'Too high!' : null,
                              errorStyle: const TextStyle(fontSize: 10, height: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: isInvalid ? Colors.red : AppTheme.borderGrey,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: isInvalid ? Colors.red : AppTheme.borderGrey,
                                  width: isInvalid ? 2 : 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: isInvalid ? Colors.red : AppTheme.primaryPurple,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: const BorderSide(color: Colors.red, width: 2),
                              ),
                              filled: true,
                              fillColor: isInvalid
                                  ? Colors.red.withOpacity(0.05)
                                  : AppTheme.cardWhite,
                              prefixIcon: Icon(
                                Icons.check_circle_outline,
                                color: isInvalid ? Colors.red : AppTheme.primaryPurple,
                              ),
                            ),
                            style: TextStyle(
                              color: isInvalid ? Colors.red : AppTheme.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    // Date Picker
                    GestureDetector(
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
                            const Icon(Icons.calendar_today, color: AppTheme.primaryPurple),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                        'Save Changes',
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
}
