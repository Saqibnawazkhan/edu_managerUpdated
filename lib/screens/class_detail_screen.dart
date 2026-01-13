import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/student_service.dart';
import '../services/class_service.dart';
import '../services/student_export_service.dart';
import '../utils/app_theme.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classItem;

  const ClassDetailScreen({super.key, required this.classItem});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  int _totalStudents = 0;
  List<StudentModel> _currentStudents = [];
  final StudentExportService _exportService = StudentExportService();

  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fabScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
            ],
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

  void _showAddStudentDialog() {
    HapticFeedback.mediumImpact();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final fatherPhoneController = TextEditingController();
    final motherPhoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryPurple),
              ),
              const SizedBox(width: 12),
              const Text('Add Student'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(nameController, 'Student Name', Icons.person_rounded, autofocus: true),
                const SizedBox(height: 12),
                _buildDialogTextField(phoneController, 'Phone Number', Icons.phone_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildDialogTextField(fatherPhoneController, 'Father\'s Phone', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildDialogTextField(motherPhoneController, 'Mother\'s Phone', Icons.phone_iphone_rounded, keyboardType: TextInputType.phone),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  HapticFeedback.mediumImpact();
                  final studentService = Provider.of<StudentService>(context, listen: false);
                  final error = await studentService.addStudent(
                    classId: widget.classItem.id,
                    name: nameController.text.trim(),
                    phoneNo: phoneController.text.trim(),
                    fatherPhNo: fatherPhoneController.text.trim(),
                    motherPhNo: motherPhoneController.text.trim(),
                  );

                  if (mounted) {
                    if (error == null) {
                      Navigator.pop(dialogContext);
                      HapticFeedback.lightImpact();
                      _showSnackBar('Student added!', const Color(0xFF4CAF50), icon: Icons.check_circle);
                    } else if (error == 'DUPLICATE_STUDENT') {
                      HapticFeedback.heavyImpact();
                      _showSnackBar('Student already exists', Colors.orange, icon: Icons.warning);
                    } else {
                      Navigator.pop(dialogContext);
                      HapticFeedback.heavyImpact();
                      _showSnackBar('Error: $error', Colors.red, icon: Icons.error);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool autofocus = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryPurple),
      ),
    );
  }

  void _showEditStudentDialog(StudentModel student) {
    HapticFeedback.mediumImpact();
    final nameController = TextEditingController(text: student.name);
    final phoneController = TextEditingController(text: student.phoneNo);
    final fatherPhoneController = TextEditingController(text: student.fatherPhNo);
    final motherPhoneController = TextEditingController(text: student.motherPhNo);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_rounded, color: AppTheme.primaryPurple),
              ),
              const SizedBox(width: 12),
              const Text('Edit Student'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(nameController, 'Student Name', Icons.person_rounded, autofocus: true),
                const SizedBox(height: 12),
                _buildDialogTextField(phoneController, 'Phone Number', Icons.phone_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildDialogTextField(fatherPhoneController, 'Father\'s Phone', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildDialogTextField(motherPhoneController, 'Mother\'s Phone', Icons.phone_iphone_rounded, keyboardType: TextInputType.phone),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  HapticFeedback.mediumImpact();
                  final studentService = Provider.of<StudentService>(context, listen: false);
                  final error = await studentService.updateStudent(
                    studentId: student.id,
                    name: nameController.text.trim(),
                    phoneNo: phoneController.text.trim(),
                    fatherPhNo: fatherPhoneController.text.trim(),
                    motherPhNo: motherPhoneController.text.trim(),
                  );

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    if (error == null) {
                      HapticFeedback.lightImpact();
                      _showSnackBar('Student updated!', const Color(0xFF4CAF50), icon: Icons.check_circle);
                    } else {
                      HapticFeedback.heavyImpact();
                      _showSnackBar('Error: $error', Colors.red, icon: Icons.error);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(StudentModel student) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('Delete Student'),
            ],
          ),
          content: Text('Are you sure you want to delete ${student.name}?'),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(dialogContext);
                _showSnackBar('Deleting...', AppTheme.primaryPurple);

                final studentService = Provider.of<StudentService>(context, listen: false);
                studentService.deleteStudent(student.id).then((error) {
                  if (mounted) {
                    if (error != null) {
                      HapticFeedback.heavyImpact();
                      _showSnackBar('Error: $error', Colors.red, icon: Icons.error);
                    }
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteClassConfirmation() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('Delete Class'),
            ],
          ),
          content: Text('Are you sure you want to delete "${widget.classItem.name}"? This will delete all students.'),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final classService = Provider.of<ClassService>(context, listen: false);
                final error = await classService.deleteClass(widget.classItem.id);

                if (mounted) {
                  Navigator.pop(dialogContext);
                  if (error == null) {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _showSnackBar('Class deleted!', const Color(0xFF4CAF50), icon: Icons.check_circle);
                  } else {
                    HapticFeedback.heavyImpact();
                    _showSnackBar('Error: $error', Colors.red, icon: Icons.error);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showStudentDetails(StudentModel student) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  student.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (student.phoneNo.isNotEmpty)
                  _buildDetailRow(Icons.phone_rounded, 'Phone', student.phoneNo),
                if (student.fatherPhNo.isNotEmpty)
                  _buildDetailRow(Icons.phone_android_rounded, 'Father', student.fatherPhNo),
                if (student.motherPhNo.isNotEmpty)
                  _buildDetailRow(Icons.phone_iphone_rounded, 'Mother', student.motherPhNo),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExportImportOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Import / Export',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildOptionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: Colors.red,
                  title: 'Export to PDF',
                  subtitle: 'Save as PDF file',
                  onTap: () async {
                    Navigator.pop(context);
                    if (_currentStudents.isEmpty) {
                      _showSnackBar('No students to export', Colors.orange, icon: Icons.warning);
                      return;
                    }
                    await _exportService.exportStudentsToPdf(
                      classItem: widget.classItem,
                      students: _currentStudents,
                    );
                  },
                ),
                _buildOptionTile(
                  icon: Icons.table_chart_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Export to Excel',
                  subtitle: 'Save as Excel file',
                  onTap: () async {
                    Navigator.pop(context);
                    if (_currentStudents.isEmpty) {
                      _showSnackBar('No students to export', Colors.orange, icon: Icons.warning);
                      return;
                    }
                    await _exportService.exportStudentsToExcel(
                      classItem: widget.classItem,
                      students: _currentStudents,
                    );
                  },
                ),
                Divider(color: Colors.grey[200]),
                _buildOptionTile(
                  icon: Icons.upload_file_rounded,
                  iconColor: AppTheme.primaryPurple,
                  title: 'Import from Excel',
                  subtitle: 'Add from file',
                  onTap: () {
                    Navigator.pop(context);
                    _importStudentsFromExcel();
                  },
                ),
                _buildOptionTile(
                  icon: Icons.download_rounded,
                  iconColor: const Color(0xFF2196F3),
                  title: 'Download Template',
                  subtitle: 'Get Excel format',
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    await _exportService.downloadSampleTemplate();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _importStudentsFromExcel() async {
    _showSnackBar('Reading file...', AppTheme.primaryPurple);

    final result = await _exportService.importStudentsFromExcel();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!result.isSuccess) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSnackBar(result.error ?? 'No students found', Colors.orange, icon: Icons.warning);
      }
      return;
    }

    if (mounted) {
      final confirmed = await _showImportConfirmationDialog(result.students!);
      if (confirmed == true) {
        await _saveImportedStudents(result.students!);
      }
    }
  }

  Future<bool?> _showImportConfirmationDialog(List<Map<String, String>> students) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_rounded, color: AppTheme.primaryPurple),
              ),
              const SizedBox(width: 12),
              Text('${students.length} Students'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: students.length > 10 ? 10 : students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                              child: Text(
                                student['name']!.isNotEmpty ? student['name']![0].toUpperCase() : '?',
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
                                  Text(student['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (student['phone']?.isNotEmpty == true)
                                    Text(student['phone']!, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (students.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('+ ${students.length - 10} more', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext, false);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Import All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveImportedStudents(List<Map<String, String>> students) async {
    final studentService = Provider.of<StudentService>(context, listen: false);
    int successCount = 0;
    int duplicateCount = 0;

    _showSnackBar('Importing...', AppTheme.primaryPurple);

    for (var studentData in students) {
      final error = await studentService.addStudent(
        classId: widget.classItem.id,
        name: studentData['name'] ?? '',
        phoneNo: studentData['phone'] ?? '',
        fatherPhNo: studentData['fatherPhone'] ?? '',
        motherPhNo: studentData['motherPhone'] ?? '',
      );

      if (error == null) {
        successCount++;
      } else if (error == 'DUPLICATE_STUDENT') {
        duplicateCount++;
      }
    }

    if (mounted) {
      HapticFeedback.lightImpact();
      String message = 'Imported $successCount students';
      if (duplicateCount > 0) {
        message += ' ($duplicateCount skipped)';
      }
      _showSnackBar(message, const Color(0xFF4CAF50), icon: Icons.check_circle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentService = Provider.of<StudentService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildStudentsHeader(),
            const SizedBox(height: 12),
            Expanded(child: _buildStudentsList(studentService)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
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
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 2),
                Text('$_totalStudents students', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          GestureDetector(
            onTapDown: (_) => HapticFeedback.selectionClick(),
            onTap: _showExportImportOptions,
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
              child: const Icon(Icons.import_export_rounded, color: AppTheme.primaryPurple, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTapDown: (_) => HapticFeedback.selectionClick(),
            onTap: _showDeleteClassConfirmation,
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
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search students...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Students',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.lightPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_totalStudents',
              style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(StudentService studentService) {
    return StreamBuilder<List<StudentModel>>(
      stream: studentService.getStudents(widget.classItem.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
        }

        final allStudents = snapshot.data ?? [];
        final newCount = allStudents.length;
        if (_totalStudents != newCount || _currentStudents.length != newCount) {
          Future.microtask(() {
            if (mounted) {
              setState(() {
                _totalStudents = newCount;
                _currentStudents = allStudents;
              });
            }
          });
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        var students = snapshot.data!;
        students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (_searchQuery.isNotEmpty) {
          students = students.where((s) => s.name.toLowerCase().contains(_searchQuery)).toList();
        }

        if (students.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: students.length,
          itemBuilder: (context, index) => _buildStudentCard(students[index]),
        );
      },
    );
  }

  Widget _buildStudentCard(StudentModel student) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () => _showStudentDetails(student),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  if (student.phoneNo.isNotEmpty)
                    Text(
                      student.phoneNo,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showEditStudentDialog(student),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, color: AppTheme.primaryPurple, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showDeleteConfirmation(student),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.lightPurple,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_rounded,
              size: 60,
              color: AppTheme.primaryPurple.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No students yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          Text('Tap + to add your first student', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No students found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _fabController.forward();
      },
      onTapUp: (_) => _fabController.reverse(),
      onTapCancel: () => _fabController.reverse(),
      onTap: _showAddStudentDialog,
      child: AnimatedBuilder(
        animation: _fabScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScale.value,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 28),
            ),
          );
        },
      ),
    );
  }
}
