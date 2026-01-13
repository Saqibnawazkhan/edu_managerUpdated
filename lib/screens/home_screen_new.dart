import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _HomeScreenNewState extends State<HomeScreenNew>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  final StudentExportService _exportService = StudentExportService();

  // For 3D touch on FAB
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

  void _showAddClassDialog() {
    HapticFeedback.mediumImpact();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_rounded, color: AppTheme.primaryPurple),
              ),
              const SizedBox(width: 12),
              const Text('New Class'),
            ],
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter class name',
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
              prefixIcon: const Icon(Icons.edit_rounded, color: AppTheme.primaryPurple),
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
                  final classService = Provider.of<ClassService>(context, listen: false);
                  final className = nameController.text.trim();
                  final result = await classService.addClass(className);
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    if (result.startsWith('error:')) {
                      HapticFeedback.heavyImpact();
                      _showSnackBar(result.substring(6), Colors.red);
                    } else {
                      HapticFeedback.lightImpact();
                      _showAddStudentsOptionsDialog(result, className);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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

  void _showAddStudentsOptionsDialog(String classId, String className) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF4CAF50),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '"$className" Created!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add students to your class',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              _build3DOptionTile(
                icon: Icons.table_chart_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: 'Import from Excel',
                subtitle: 'Upload student list',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _importStudentsToClass(classId, className);
                },
              ),
              const SizedBox(height: 12),
              _build3DOptionTile(
                icon: Icons.person_add_rounded,
                iconColor: AppTheme.primaryPurple,
                title: 'Add Manually',
                subtitle: 'Enter one by one',
                onTap: () {
                  Navigator.pop(dialogContext);
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
              _build3DOptionTile(
                icon: Icons.download_rounded,
                iconColor: const Color(0xFF2196F3),
                title: 'Download Template',
                subtitle: 'Get Excel format',
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await _exportService.downloadSampleTemplate();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext);
                _showSnackBar('Class "$className" added!', const Color(0xFF4CAF50));
              },
              child: Text('Skip', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        );
      },
    );
  }

  Widget _build3DOptionTile({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _importStudentsToClass(String classId, String className) async {
    _showSnackBar('Reading file...', AppTheme.primaryPurple);

    final result = await _exportService.importStudentsFromExcel();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!result.isSuccess) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSnackBar(result.error ?? 'No students found', Colors.orange);
        _showAddStudentsOptionsDialog(classId, className);
      }
      return;
    }

    if (mounted) {
      final confirmed = await _showImportConfirmationDialog(result.students!);
      if (confirmed == true) {
        await _saveImportedStudents(classId, className, result.students!);
      } else {
        _showAddStudentsOptionsDialog(classId, className);
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
                                student['name']!.isNotEmpty
                                    ? student['name']!.substring(0, 1).toUpperCase()
                                    : '?',
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
                                    student['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  if (student['phone']?.isNotEmpty == true)
                                    Text(
                                      student['phone']!,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
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
                    child: Text(
                      '+ ${students.length - 10} more',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
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

  Future<void> _saveImportedStudents(
    String classId,
    String className,
    List<Map<String, String>> students,
  ) async {
    final studentService = Provider.of<StudentService>(context, listen: false);
    int successCount = 0;
    int duplicateCount = 0;

    _showSnackBar('Importing students...', AppTheme.primaryPurple);

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
      HapticFeedback.lightImpact();
      String message = 'Added $successCount students';
      if (duplicateCount > 0) {
        message += ' ($duplicateCount skipped)';
      }
      _showSnackBar(message, const Color(0xFF4CAF50));

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
    HapticFeedback.mediumImpact();
    final TextEditingController nameController = TextEditingController(text: classItem.name);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
              const Text('Edit Class'),
            ],
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
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
                  final classService = Provider.of<ClassService>(context, listen: false);
                  final error = await classService.updateClass(
                    classItem.id,
                    nameController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    if (error == null) {
                      HapticFeedback.lightImpact();
                      _showSnackBar('Class renamed!', const Color(0xFF4CAF50));
                    } else {
                      HapticFeedback.heavyImpact();
                      _showSnackBar(error, Colors.red);
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
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            _buildHeader(user),

            // Search Bar
            _buildSearchBar(),

            const SizedBox(height: 20),

            // Classes Grid
            Expanded(
              child: _buildClassesGrid(classService, studentService),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onTap: (index) {
          HapticFeedback.lightImpact();
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

  Widget _buildHeader(User? user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user?.displayName?.split(' ').first ?? 'Teacher'}!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your classes',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTapDown: (_) => HapticFeedback.selectionClick(),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                SmoothPageRoute(page: const ProfileScreen()),
              );
            },
            child: Container(
              width: 48,
              height: 48,
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
                Icons.person_outline_rounded,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Search classes...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildClassesGrid(ClassService classService, StudentService studentService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Classes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              StreamBuilder<List<ClassModel>>(
                stream: classService.getClasses(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.lightPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<ClassModel>>(
            stream: classService.getClasses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              var classes = snapshot.data!;
              classes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (_searchQuery.isNotEmpty) {
                classes = classes
                    .where((c) => c.name.toLowerCase().contains(_searchQuery))
                    .toList();
              }

              if (classes.isEmpty) {
                return _buildNoResultsState();
              }

              final colors = [
                const Color(0xFF7C4DFF),
                const Color(0xFF00BFA5),
                const Color(0xFFFF6D00),
                const Color(0xFFE91E63),
                const Color(0xFF2196F3),
              ];

              return GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.95,
                ),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final classItem = classes[index];
                  final color = colors[index % colors.length];
                  return _buildClassCard(classItem, color, studentService);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(ClassModel classItem, Color color, StudentService studentService) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          SmoothPageRoute(page: ClassDetailScreen(classItem: classItem)),
        );
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showEditClassDialog(classItem);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decoration
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  // Class info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classItem.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<int>(
                        future: studentService.getStudentCount(classItem.id),
                        builder: (context, countSnapshot) {
                          final count = countSnapshot.data ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
              Icons.school_rounded,
              size: 60,
              color: AppTheme.primaryPurple.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No classes yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first class',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 60,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No classes found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _fabController.forward();
        },
        onTapUp: (_) => _fabController.reverse(),
        onTapCancel: () => _fabController.reverse(),
        onTap: _showAddClassDialog,
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
                    colors: [
                      AppTheme.primaryPurple,
                      AppTheme.primaryPurple.withValues(alpha: 0.8),
                    ],
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
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
