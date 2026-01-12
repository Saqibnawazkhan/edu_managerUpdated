import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../services/class_service.dart';
import '../services/student_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_bottom_nav.dart';
import 'attendance_calendar_screen.dart';
import 'statistics_selection_screen.dart';
import 'home_screen_new.dart';

class AttendanceSelectionScreen extends StatefulWidget {
  const AttendanceSelectionScreen({super.key});

  @override
  State<AttendanceSelectionScreen> createState() => _AttendanceSelectionScreenState();
}

class _AttendanceSelectionScreenState extends State<AttendanceSelectionScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classService = Provider.of<ClassService>(context);
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance',
                          style: AppTheme.heading1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a class to mark attendance',
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
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
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
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
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

            // Classes Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Class', style: AppTheme.heading3),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing12),

            // Class Grid (Same as Home Screen)
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
                          Text(
                            'Create a class to mark attendance',
                            style: AppTheme.bodySmall,
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
                              page: AttendanceCalendarScreen(classItem: classItem),
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
                                        Icons.calendar_today_rounded,
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
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            // Go to Home - clear stack
            Navigator.pushAndRemoveUntil(
              context,
              FastFadeRoute(page: const HomeScreenNew()),
                  (route) => false,
            );
          } else if (index == 1) {
            // Already on attendance selection
          } else if (index == 2) {
            // Go to Statistics - replace current
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