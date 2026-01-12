import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/marks_model.dart';
import '../models/student_model.dart';
import '../services/marks_service.dart';
import '../services/student_service.dart';
import '../utils/app_theme.dart';
import 'add_marks_screen.dart';

class MarksReportScreen extends StatefulWidget {
  final ClassModel classItem;

  const MarksReportScreen({super.key, required this.classItem});

  @override
  State<MarksReportScreen> createState() => _MarksReportScreenState();
}

class _MarksReportScreenState extends State<MarksReportScreen> {
  String _selectedFilter = 'all'; // all, mock, assignment
  String _searchQuery = '';
  Map<String, String> _studentNames = {}; // studentId -> studentName

  @override
  void initState() {
    super.initState();
    _loadStudentNames();
  }

  Future<void> _loadStudentNames() async {
    final studentService = Provider.of<StudentService>(context, listen: false);
    final students = await studentService.getStudents(widget.classItem.id).first;

    setState(() {
      _studentNames = {
        for (var student in students) student.id: student.name
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final marksService = Provider.of<MarksService>(context);

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
                        const Text(
                          'Assessments Report',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.push(
                          context,
                          SmoothPageRoute(
                            page: AddMarksScreenBulk(
                              classItem: widget.classItem,
                            ),
                          ),
                        );
                      },
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ],
              ),
            ),

            // Filter Tabs
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
                    _buildFilterTab('all', 'All', Icons.list),
                    const SizedBox(width: 8),
                    _buildFilterTab('mock', 'Mocks', Icons.quiz_outlined),
                    const SizedBox(width: 8),
                    _buildFilterTab('assignment', 'Assignments', Icons.assignment_outlined),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing12),

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
                    hintText: 'Search assessments...',
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

            // Assessments List
            Expanded(
              child: FutureBuilder<List<MarksModel>>(
                future: marksService.getClassMarks(widget.classItem.id).first,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 80,
                            color: AppTheme.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            'No assessments yet',
                            style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to add marks',
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  var allMarks = snapshot.data!;

                  // Filter by assessment type
                  if (_selectedFilter != 'all') {
                    allMarks = allMarks
                        .where((mark) => mark.assessmentType == _selectedFilter)
                        .toList();
                  }

                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    allMarks = allMarks
                        .where((mark) => mark.assessmentName.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  // Group by assessment name and date
                  Map<String, List<MarksModel>> groupedMarks = {};
                  for (var mark in allMarks) {
                    String key = '${mark.assessmentName}_${mark.date}';
                    if (!groupedMarks.containsKey(key)) {
                      groupedMarks[key] = [];
                    }
                    groupedMarks[key]!.add(mark);
                  }

                  // Sort by date (newest first)
                  var sortedKeys = groupedMarks.keys.toList()
                    ..sort((a, b) {
                      try {
                        var dateA = DateFormat('dd/MM/yyyy').parse(groupedMarks[a]![0].date);
                        var dateB = DateFormat('dd/MM/yyyy').parse(groupedMarks[b]![0].date);
                        return dateB.compareTo(dateA);
                      } catch (e) {
                        return 0;
                      }
                    });

                  if (sortedKeys.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.filter_alt_off,
                            size: 80,
                            color: AppTheme.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No assessments found for "$_searchQuery"'
                                : 'No ${_selectedFilter == 'mock' ? 'mocks' : 'assignments'} found',
                            style: AppTheme.heading3.copyWith(color: AppTheme.textGrey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      itemCount: sortedKeys.length,
                      itemBuilder: (context, index) {
                        String key = sortedKeys[index];
                        List<MarksModel> marks = groupedMarks[key]!;
                        MarksModel firstMark = marks[0];

                        // Calculate statistics
                        double totalObtained = 0;
                        double totalMax = 0;
                        for (var mark in marks) {
                          totalObtained += mark.obtainedMarks;
                          totalMax += mark.totalMarks;
                        }
                        double classAverage = totalMax > 0 ? (totalObtained / totalMax * 100) : 0;

                        Color cardColor;
                        switch (firstMark.assessmentType) {
                          case 'mock':
                            cardColor = AppTheme.lightPurple;
                            break;
                          case 'assignment':
                            cardColor = AppTheme.lightBlue;
                            break;
                          default:
                            cardColor = AppTheme.lightGreen;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              onTap: () {
                                _showAssessmentDetails(context, firstMark, marks, classAverage);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.spacing16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: firstMark.assessmentType == 'mock'
                                                ? AppTheme.primaryPurple.withOpacity(0.1)
                                                : AppTheme.primaryBlue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            firstMark.assessmentType == 'mock'
                                                ? Icons.quiz_outlined
                                                : Icons.assignment_outlined,
                                            color: firstMark.assessmentType == 'mock'
                                                ? AppTheme.primaryPurple
                                                : AppTheme.primaryBlue,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                firstMark.assessmentName,
                                                style: AppTheme.heading3,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color: AppTheme.textGrey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    firstMark.date,
                                                    style: AppTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Edit Button
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            // Navigate to bulk add screen with existing marks for editing
                                            Navigator.push(
                                              context,
                                              SmoothPageRoute(
                                                page: AddMarksScreenBulk(
                                                  classItem: widget.classItem,
                                                  assessmentToEdit: firstMark,
                                                  existingMarks: marks,
                                                ),
                                              ),
                                            ).then((_) {
                                              // Refresh data after any changes
                                              setState(() {});
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.edit,
                                              size: 18,
                                              color: firstMark.assessmentType == 'mock'
                                                  ? AppTheme.primaryPurple
                                                  : AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ),
                                        // Delete Button
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () async {
                                            // Show confirmation dialog
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text('Delete Assessment'),
                                                  content: Text(
                                                    'Are you sure you want to delete "${firstMark.assessmentName}"?\n\nThis will delete marks for all ${marks.length} students.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: AppTheme.error,
                                                      ),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );

                                            if (confirm == true) {
                                              // Show loading
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                              );

                                              try {
                                                final marksService = Provider.of<MarksService>(context, listen: false);

                                                // Delete all marks for this assessment with timeout
                                                int deleted = 0;
                                                List<String> errors = [];

                                                for (var mark in marks) {
                                                  // Add timeout to prevent hanging
                                                  final error = await marksService.deleteMarks(mark.id)
                                                      .timeout(
                                                    const Duration(seconds: 10),
                                                    onTimeout: () => 'Timeout: Could not delete mark',
                                                  );

                                                  if (error == null) {
                                                    deleted++;
                                                  } else {
                                                    errors.add(error);
                                                  }
                                                }

                                                if (mounted) {
                                                  Navigator.pop(context); // Close loading

                                                  // Refresh data
                                                  setState(() {});

                                                  // Show result message
                                                  if (errors.isEmpty) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Deleted $deleted marks for "${firstMark.assessmentName}"'),
                                                        backgroundColor: AppTheme.success,
                                                        behavior: SnackBarBehavior.floating,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Deleted $deleted marks, ${errors.length} failed'),
                                                        backgroundColor: AppTheme.warning,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  Navigator.pop(context); // Close loading
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Error: ${e.toString()}'),
                                                      backgroundColor: AppTheme.error,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: AppTheme.error,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: classAverage >= 75
                                                ? AppTheme.success
                                                : classAverage >= 50
                                                ? AppTheme.warning
                                                : AppTheme.error,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${classAverage.toStringAsFixed(1)}%',
                                            style: AppTheme.bodyMedium.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatItem(
                                            '${marks.length}',
                                            'Students',
                                            Icons.people,
                                          ),
                                          Container(
                                            width: 1,
                                            height: 30,
                                            color: AppTheme.borderGrey,
                                          ),
                                          _buildStatItem(
                                            firstMark.totalMarks.toStringAsFixed(0),
                                            'Total Marks',
                                            Icons.grade,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String value, String label, IconData icon) {
    bool isSelected = _selectedFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppTheme.textGrey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: isSelected ? Colors.white : AppTheme.textGrey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryPurple),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: AppTheme.textGrey,
          ),
        ),
      ],
    );
  }

  void _showAssessmentDetails(
      BuildContext context,
      MarksModel assessment,
      List<MarksModel> studentMarks,
      double classAverage,
      ) {
    // Sort student marks alphabetically by student name
    final sortedMarks = List<MarksModel>.from(studentMarks);
    sortedMarks.sort((a, b) {
      final nameA = _studentNames[a.studentId] ?? '';
      final nameB = _studentNames[b.studentId] ?? '';
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      assessment.assessmentName,
                      style: AppTheme.heading2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assessment.date,
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: classAverage >= 75
                            ? AppTheme.success
                            : classAverage >= 50
                            ? AppTheme.warning
                            : AppTheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Class Average: ${classAverage.toStringAsFixed(1)}%',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Student list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedMarks.length,
                  itemBuilder: (context, index) {
                    var mark = sortedMarks[index];
                    double percentage = (mark.obtainedMarks / mark.totalMarks) * 100;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _studentNames[mark.studentId] ?? 'Student ${index + 1}',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${mark.obtainedMarks.toStringAsFixed(0)}/${mark.totalMarks.toStringAsFixed(0)}',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: percentage >= 75
                                  ? AppTheme.success
                                  : percentage >= 50
                                  ? AppTheme.warning
                                  : AppTheme.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}