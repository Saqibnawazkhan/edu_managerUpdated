import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/marks_model.dart';
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

class _EditSingleMarkScreenState extends State<EditSingleMarkScreen>
    with TickerProviderStateMixin {
  final _assessmentNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalMarksController = TextEditingController();
  final _obtainedMarksController = TextEditingController();

  String _selectedAssessmentType = 'mock';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  // Animation controllers for 3D touch
  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonScale;

  @override
  void initState() {
    super.initState();
    _assessmentNameController.text = widget.markToEdit.assessmentName;
    _descriptionController.text = widget.markToEdit.description ?? '';
    _totalMarksController.text = widget.markToEdit.totalMarks.toStringAsFixed(0);
    _obtainedMarksController.text = widget.markToEdit.obtainedMarks.toStringAsFixed(0);
    _selectedAssessmentType = widget.markToEdit.assessmentType;

    try {
      _selectedDate = DateFormat('dd/MM/yyyy').parse(widget.markToEdit.date);
    } catch (e) {
      _selectedDate = DateTime.now();
    }

    // Initialize save button animation
    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _saveButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _assessmentNameController.dispose();
    _descriptionController.dispose();
    _totalMarksController.dispose();
    _obtainedMarksController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  bool _isObtainedMarksValid() {
    if (_obtainedMarksController.text.isEmpty || _totalMarksController.text.isEmpty) {
      return true;
    }
    try {
      final obtained = double.parse(_obtainedMarksController.text);
      final total = double.parse(_totalMarksController.text);
      return obtained >= 0 && obtained <= total;
    } catch (e) {
      return true;
    }
  }

  double get _percentage {
    if (_obtainedMarksController.text.isEmpty || _totalMarksController.text.isEmpty) {
      return 0;
    }
    try {
      final obtained = double.parse(_obtainedMarksController.text);
      final total = double.parse(_totalMarksController.text);
      if (total == 0) return 0;
      return (obtained / total * 100).clamp(0, 100);
    } catch (e) {
      return 0;
    }
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveMarks() async {
    // Validate
    if (_assessmentNameController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar('Please enter assessment name');
      return;
    }

    if (_totalMarksController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar('Please enter total marks');
      return;
    }

    if (_obtainedMarksController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar('Please enter obtained marks');
      return;
    }

    if (!_isObtainedMarksValid()) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar('Obtained marks cannot exceed total marks');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

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

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (error != null) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar('Error: $error');
    } else {
      HapticFeedback.lightImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Marks updated successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInvalid = !_isObtainedMarksValid();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    // Score Card with circular progress
                    _buildScoreCard(),

                    const SizedBox(height: 24),

                    // Assessment Type Toggle
                    _buildAssessmentTypeToggle(),

                    const SizedBox(height: 20),

                    // Assessment Name Card
                    _build3DCard(
                      child: _buildTextField(
                        controller: _assessmentNameController,
                        label: _selectedAssessmentType == 'mock' ? 'Mock Name' : 'Assignment Name',
                        hint: _selectedAssessmentType == 'mock' ? 'e.g., Mock 1' : 'e.g., Assignment 1',
                        icon: _selectedAssessmentType == 'mock'
                            ? Icons.quiz_rounded
                            : Icons.assignment_rounded,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Marks Input Row
                    Row(
                      children: [
                        Expanded(
                          child: _build3DCard(
                            child: _buildMarksField(
                              controller: _totalMarksController,
                              label: 'Total',
                              icon: Icons.stars_rounded,
                              iconColor: const Color(0xFFFFB300),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _build3DCard(
                            isError: isInvalid,
                            child: _buildMarksField(
                              controller: _obtainedMarksController,
                              label: 'Obtained',
                              icon: Icons.check_circle_rounded,
                              iconColor: isInvalid ? Colors.red : const Color(0xFF4CAF50),
                              isError: isInvalid,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date Picker Card
                    _buildDateCard(),

                    const SizedBox(height: 16),

                    // Description Card (Optional)
                    _build3DCard(
                      child: _buildTextField(
                        controller: _descriptionController,
                        label: 'Notes',
                        hint: 'Add any notes (optional)',
                        icon: Icons.note_rounded,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Save Button
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
          _buildBackButton(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Edit ${_selectedAssessmentType == 'mock' ? 'Mock' : 'Assignment'} Marks',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
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
        child: const Icon(
          Icons.arrow_back_rounded,
          color: AppTheme.textDark,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple,
            AppTheme.primaryPurple.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _percentage / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isObtainedMarksValid() ? Colors.white : Colors.red[300]!,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_percentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Score',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Score Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _assessmentNameController.text.isEmpty
                      ? 'Assessment'
                      : _assessmentNameController.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildScoreBadge(
                      _obtainedMarksController.text.isEmpty
                          ? '0'
                          : _obtainedMarksController.text,
                      'Obtained',
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '/',
                      style: TextStyle(color: Colors.white54, fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    _buildScoreBadge(
                      _totalMarksController.text.isEmpty
                          ? '0'
                          : _totalMarksController.text,
                      'Total',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
      ],
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
          Expanded(
            child: _buildTypeToggleButton('mock', 'Mock', Icons.quiz_rounded),
          ),
          Expanded(
            child: _buildTypeToggleButton('assignment', 'Assignment', Icons.assignment_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggleButton(String type, String label, IconData icon) {
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
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
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

  Widget _build3DCard({required Widget child, bool isError = false}) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isError ? Border.all(color: Colors.red, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: isError
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.lightPurple,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryPurple, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarksField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    bool isError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isError ? Colors.red : AppTheme.textDark,
          ),
          onChanged: (value) {
            if (!_isObtainedMarksValid()) {
              HapticFeedback.heavyImpact();
            }
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: Colors.grey[300], fontSize: 32),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (isError)
          Text(
            'Max: ${_totalMarksController.text}',
            style: const TextStyle(color: Colors.red, fontSize: 11),
          ),
      ],
    );
  }

  Widget _buildDateCard() {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF2196F3),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM, yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Save Changes',
                              style: TextStyle(
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
