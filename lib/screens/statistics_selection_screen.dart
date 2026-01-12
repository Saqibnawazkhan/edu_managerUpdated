import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../services/class_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_bottom_nav.dart';
import 'statistics_screen.dart';
import 'home_screen_new.dart';
import 'attendance_selection_screen.dart';

class StatisticsSelectionScreen extends StatefulWidget {
  const StatisticsSelectionScreen({super.key});

  @override
  State<StatisticsSelectionScreen> createState() => _StatisticsSelectionScreenState();
}

class _StatisticsSelectionScreenState extends State<StatisticsSelectionScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final classService = Provider.of<ClassService>(context);

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
                          'Statistics',
                          style: AppTheme.heading1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a class to view statistics',
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

            // Classes Grid
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
                          // Use regular push - don't remove routes
                          Navigator.push(
                            context,
                            SmoothPageRoute(
                              page: StatisticsScreen(classItem: classItem),
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
                              Padding(
                                padding: const EdgeInsets.all(AppTheme.spacing16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.bar_chart_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
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
                                        Text(
                                          'View Statistics',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: Colors.white.withOpacity(0.9),
                                          ),
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
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              FastFadeRoute(page: const HomeScreenNew()),
                  (route) => false,
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              FastFadeRoute(page: const AttendanceSelectionScreen()),
            );
          } else if (index == 2) {
            // Already on Statistics Selection - do nothing
          }
        },
      ),
    );
  }
}