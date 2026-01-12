import 'package:flutter/material.dart';
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

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  String _searchQuery = '';
  int _totalStudents = 0;
  List<StudentModel> _currentStudents = [];
  final StudentExportService _exportService = StudentExportService();

  void _showAddStudentDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController fatherPhoneController = TextEditingController();
    final TextEditingController motherPhoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Add New Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Student Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fatherPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Father Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motherPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mother Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_iphone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Student "${nameController.text}" added successfully'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    } else if (error == 'DUPLICATE_STUDENT') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Student "${nameController.text.trim()}" already exists in this class'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $error'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditStudentDialog(StudentModel student) {
    final TextEditingController nameController = TextEditingController(text: student.name);
    final TextEditingController phoneController = TextEditingController(text: student.phoneNo);
    final TextEditingController fatherPhoneController = TextEditingController(text: student.fatherPhNo);
    final TextEditingController motherPhoneController = TextEditingController(text: student.motherPhNo);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Edit Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Student Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fatherPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Father Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motherPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mother Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_iphone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final studentService = Provider.of<StudentService>(context, listen: false);
                  final error = await studentService.updateStudent(
                    studentId: student.id,
                    name: nameController.text.trim(),
                    phoneNo: phoneController.text.trim(),
                    fatherPhNo: fatherPhoneController.text.trim(),
                    motherPhNo: motherPhoneController.text.trim(),
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Student updated successfully'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $error'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(StudentModel student) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete Student'),
          content: Text('Are you sure you want to delete ${student.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Close dialog immediately for responsiveness
                Navigator.pop(context);

                // Show immediate feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleting ${student.name}...'),
                    backgroundColor: AppTheme.primaryPurple,
                    duration: const Duration(seconds: 1),
                  ),
                );

                // Delete in background
                final studentService = Provider.of<StudentService>(context, listen: false);
                studentService.deleteStudent(student.id).then((error) {
                  if (mounted) {
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $error'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteClassConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete Class'),
          content: Text('Are you sure you want to delete "${widget.classItem.name}"? This will also delete all students in this class.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final classService = Provider.of<ClassService>(context, listen: false);
                final error = await classService.deleteClass(widget.classItem.id);

                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  if (error == null) {
                    Navigator.pop(context); // Go back to home
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.classItem.name} deleted successfully'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $error'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showStudentDetails(StudentModel student) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              CircleAvatar(
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
              Expanded(
                child: Text(
                  student.name,
                  style: AppTheme.heading3,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (student.phoneNo.isNotEmpty) ...[
                _buildInfoRow(Icons.phone, 'Student Phone', student.phoneNo),
                const SizedBox(height: 12),
              ],
              if (student.fatherPhNo.isNotEmpty) ...[
                _buildInfoRow(Icons.phone_android, 'Father Phone', student.fatherPhNo),
                const SizedBox(height: 12),
              ],
              if (student.motherPhNo.isNotEmpty) ...[
                _buildInfoRow(Icons.phone_iphone, 'Mother Phone', student.motherPhNo),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryPurple),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.caption.copyWith(color: AppTheme.textGrey),
            ),
            Text(
              value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  void _showExportImportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Import / Export Students',
                  style: AppTheme.heading3,
                ),
                const SizedBox(height: 20),

                // Export to PDF
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: AppTheme.error),
                  ),
                  title: const Text('Export to PDF'),
                  subtitle: const Text('Save student list as PDF'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (_currentStudents.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No students to export'),
                          backgroundColor: AppTheme.warning,
                        ),
                      );
                      return;
                    }
                    await _exportService.exportStudentsToPdf(
                      classItem: widget.classItem,
                      students: _currentStudents,
                    );
                  },
                ),

                // Export to Excel
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart, color: AppTheme.success),
                  ),
                  title: const Text('Export to Excel'),
                  subtitle: const Text('Save student list as Excel file'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (_currentStudents.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No students to export'),
                          backgroundColor: AppTheme.warning,
                        ),
                      );
                      return;
                    }
                    await _exportService.exportStudentsToExcel(
                      classItem: widget.classItem,
                      students: _currentStudents,
                    );
                  },
                ),

                const Divider(),

                // Import from Excel
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.upload_file, color: AppTheme.primaryPurple),
                  ),
                  title: const Text('Import from Excel'),
                  subtitle: const Text('Add students from Excel file'),
                  onTap: () {
                    Navigator.pop(context);
                    _importStudentsFromExcel();
                  },
                ),

                // Download Template
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download, color: AppTheme.info),
                  ),
                  title: const Text('Download Template'),
                  subtitle: const Text('Get sample Excel template'),
                  onTap: () async {
                    Navigator.pop(context);
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

  Future<void> _importStudentsFromExcel() async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('Reading file...'),
            ],
          ),
          backgroundColor: AppTheme.primaryPurple,
          duration: Duration(seconds: 10),
        ),
      );
    }

    final result = await _exportService.importStudentsFromExcel();

    // Dismiss loading snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'No students found in file'),
            backgroundColor: AppTheme.warning,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Show confirmation dialog with preview
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
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.upload_file, color: AppTheme.primaryPurple),
              const SizedBox(width: 12),
              Text('Import ${students.length} Students'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview:',
                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: students.length > 10 ? 10 : students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                          child: Text(
                            student['name']!.isNotEmpty
                                ? student['name']!.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          student['name'] ?? '',
                          style: AppTheme.bodyMedium,
                        ),
                        subtitle: student['phone']?.isNotEmpty == true
                            ? Text(student['phone']!, style: AppTheme.caption)
                            : null,
                      );
                    },
                  ),
                ),
                if (students.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... and ${students.length - 10} more students',
                      style: AppTheme.caption,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
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

    // Show progress
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importing ${students.length} students...'),
        backgroundColor: AppTheme.primaryPurple,
        duration: const Duration(seconds: 1),
      ),
    );

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
      String message = 'Imported $successCount students';
      if (duplicateCount > 0) {
        message += ' ($duplicateCount duplicates skipped)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentService = Provider.of<StudentService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.classItem.name),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
        actions: [
          // Import/Export button
          IconButton(
            icon: const Icon(Icons.import_export),
            onPressed: _showExportImportOptions,
            tooltip: 'Import/Export',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _showDeleteClassConfirmation,
            tooltip: 'Delete Class',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar and Total Strength
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                // Search Bar
                Expanded(
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
                const SizedBox(width: AppTheme.spacing12),
                // Total Strength
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_totalStudents',
                        style: AppTheme.heading2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total',
                        style: AppTheme.caption.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Students List
          Expanded(
            child: StreamBuilder<List<StudentModel>>(
              stream: studentService.getStudents(widget.classItem.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Update total count and store students for export
                final allStudents = snapshot.data ?? [];
                final newCount = allStudents.length;
                if (_totalStudents != newCount || _currentStudents.length != newCount) {
                  // Schedule microtask to update after build completes
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
                          'No students yet',
                          style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        ElevatedButton.icon(
                          onPressed: _showAddStudentDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Student'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var students = snapshot.data!;

                // Sort alphabetically
                students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                // Filter by search
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
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                          child: Text(
                            student.name.isNotEmpty ? student.name.substring(0, 1).toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          student.name,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: student.phoneNo.isNotEmpty
                            ? Text(
                          student.phoneNo,
                          style: AppTheme.bodySmall,
                        )
                            : null,
                        onTap: () => _showStudentDetails(student),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditStudentDialog(student),
                              color: AppTheme.primaryPurple,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _showDeleteConfirmation(student),
                              color: AppTheme.error,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        backgroundColor: AppTheme.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}