import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_model.dart';
import '../services/class_service.dart';
import '../services/student_service.dart';
import '../services/student_export_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_bottom_nav.dart';
import 'class_detail_screen.dart';
import 'profile_screen.dart';
import 'attendance_selection_screen.dart';
import 'statistics_selection_screen.dart';

class HomeScreenNew extends StatefulWidget {
  const HomeScreenNew({super.key});

  @override
  State<HomeScreenNew> createState() => _HomeScreenNewState();
}

class _HomeScreenNewState extends State<HomeScreenNew> {
  final _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  final StudentExportService _exportService = StudentExportService();

  void _showAddClassDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Add New Class'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter class name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final classService = Provider.of<ClassService>(context, listen: false);
                  final className = nameController.text.trim();
                  final result = await classService.addClass(className);
                  if (mounted) {
                    Navigator.pop(context);
                    // Check if result is an error
                    if (result.startsWith('error:')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result.substring(6)),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    } else {
                      // Success - result is the class ID
                      _showAddStudentsOptionsDialog(result, className);
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

  void _showAddStudentsOptionsDialog(String classId, String className) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.success,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Class "$className" Created!',
                textAlign: TextAlign.center,
                style: AppTheme.heading3,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How would you like to add students?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Import from Excel option
              _buildOptionTile(
                icon: Icons.table_chart,
                iconColor: AppTheme.success,
                title: 'Import from Excel',
                subtitle: 'Upload Excel file with student list',
                onTap: () {
                  Navigator.pop(context);
                  _importStudentsToClass(classId, className);
                },
              ),

              const SizedBox(height: 12),

              // Add manually option
              _buildOptionTile(
                icon: Icons.person_add,
                iconColor: AppTheme.primaryPurple,
                title: 'Add Manually',
                subtitle: 'Enter students one by one',
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to class detail screen
                  Navigator.push(
                    context,
                    SmoothPageRoute(
                      page: ClassDetailScreen(
                        classItem: ClassModel(
                          id: classId,
                          name: className,
                          teacherId: '',
                          studentCount: 0,
                          createdAt: DateTime.now(),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Download template option
              _buildOptionTile(
                icon: Icons.download,
                iconColor: AppTheme.info,
                title: 'Download Template',
                subtitle: 'Get sample Excel format',
                onTap: () async {
                  await _exportService.downloadSampleTemplate();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Class "$className" added successfully'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
              child: const Text('Skip for Now'),
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderGrey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textGrey),
          ],
        ),
      ),
    );
  }

  Future<void> _importStudentsToClass(String classId, String className) async {
    // Show loading indicator
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
        // Show options again
        _showAddStudentsOptionsDialog(classId, className);
      }
      return;
    }

    // Show confirmation dialog with preview
    if (mounted) {
      final confirmed = await _showImportConfirmationDialog(result.students!);
      if (confirmed == true) {
        await _saveImportedStudents(classId, className, result.students!);
      } else {
        // Show options again if cancelled
        _showAddStudentsOptionsDialog(classId, className);
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

  Future<void> _saveImportedStudents(String classId, String className, List<Map<String, String>> students) async {
    final studentService = Provider.of<StudentService>(context, listen: false);

    int successCount = 0;
    int duplicateCount = 0;

    // Show progress
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importing ${students.length} students...'),
        backgroundColor: AppTheme.primaryPurple,
        duration: const Duration(seconds: 2),
      ),
    );

    for (var studentData in students) {
      final error = await studentService.addStudent(
        classId: classId,
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
      String message = 'Imported $successCount students to "$className"';
      if (duplicateCount > 0) {
        message += ' ($duplicateCount duplicates skipped)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate to class detail screen
      Navigator.push(
        context,
        SmoothPageRoute(
          page: ClassDetailScreen(
            classItem: ClassModel(
              id: classId,
              name: className,
              teacherId: '',
              studentCount: successCount,
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );
    }
  }

  void _showEditClassDialog(ClassModel classItem) {
    final TextEditingController nameController = TextEditingController(text: classItem.name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Edit Class'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final classService = Provider.of<ClassService>(context, listen: false);
                  final error = await classService.updateClass(
                    classItem.id,
                    nameController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Class renamed to "${nameController.text}"'),
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final classService = Provider.of<ClassService>(context);
    final studentService = Provider.of<StudentService>(context);
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.displayName ?? 'Teacher'}!',
                          style: AppTheme.heading1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your classes efficiently',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.person_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          SmoothPageRoute(page: const ProfileScreen()),
                        );
                      },
                      color: AppTheme.textDark,
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
                    hintText: 'Search classes...',
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

            const SizedBox(height: AppTheme.spacing20),

            // Classes Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                    child: Text(
                      'My Classes',
                      style: AppTheme.heading2,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Expanded(
                    child: StreamBuilder<List<ClassModel>>(
                      stream: classService.getClasses(),
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
                                  Icons.class_outlined,
                                  size: 80,
                                  color: AppTheme.textGrey.withOpacity(0.3),
                                ),
                                const SizedBox(height: AppTheme.spacing16),
                                Text(
                                  'No classes yet',
                                  style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                                ),
                                const SizedBox(height: AppTheme.spacing8),
                                ElevatedButton.icon(
                                  onPressed: _showAddClassDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Your First Class'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        var classes = snapshot.data!;

                        // Sort alphabetically
                        classes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                        // Filter by search
                        if (_searchQuery.isNotEmpty) {
                          classes = classes
                              .where((c) => c.name.toLowerCase().contains(_searchQuery))
                              .toList();
                        }

                        if (classes.isEmpty) {
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
                                  'No classes found',
                                  style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                                ),
                              ],
                            ),
                          );
                        }

                        final colors = [
                          AppTheme.primaryPurple,
                          AppTheme.primaryGreen,
                          AppTheme.primaryYellow,
                          AppTheme.primaryPink,
                          AppTheme.primaryBlue,
                        ];

                        return GridView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppTheme.spacing16,
                            mainAxisSpacing: AppTheme.spacing16,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: classes.length,
                          itemBuilder: (context, index) {
                            final classItem = classes[index];
                            final color = colors[index % colors.length];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  SmoothPageRoute(
                                    page: ClassDetailScreen(classItem: classItem),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [color, color.withOpacity(0.7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Background decoration circle
                                    Positioned(
                                      top: -20,
                                      right: -20,
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    // Edit button
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => _showEditClassDialog(classItem),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Content
                                    Padding(
                                      padding: const EdgeInsets.all(AppTheme.spacing16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Icon
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.class_outlined,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          // Class info
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                classItem.name,
                                                style: AppTheme.heading2.copyWith(
                                                  color: Colors.white,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              FutureBuilder<int>(
                                                future: studentService.getStudentCount(classItem.id),
                                                builder: (context, countSnapshot) {
                                                  final count = countSnapshot.data ?? 0;
                                                  return Text(
                                                    '$count student${count != 1 ? 's' : ''}',
                                                    style: AppTheme.bodySmall.copyWith(
                                                      color: Colors.white.withOpacity(0.9),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          onPressed: _showAddClassDialog,
          backgroundColor: AppTheme.primaryPurple,
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              FastFadeRoute(page: const AttendanceSelectionScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              FastFadeRoute(page: const StatisticsSelectionScreen()),
            );
          }
        },
      ),
    );
  }
}