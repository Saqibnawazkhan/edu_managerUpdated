import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../utils/app_theme.dart';
import '../services/auth_service.dart';
import 'teacher_activities_screen.dart';

class OrganizationAdminScreen extends StatefulWidget {
  const OrganizationAdminScreen({super.key});

  @override
  State<OrganizationAdminScreen> createState() => _OrganizationAdminScreenState();
}

class _OrganizationAdminScreenState extends State<OrganizationAdminScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  String? _organizationId;
  String? _organizationName;
  int _maxDevices = 0;
  int _activeTeachers = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrganizationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizationData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          setState(() {
            _organizationId = data['organizationId'];
            _organizationName = data['organizationName'];
            _maxDevices = data['maxDevices'] ?? 0;
          });

          // Count active teachers
          if (_organizationId != null) {
            final teachersSnapshot = await _firestore
                .collection('users')
                .where('organizationId', isEqualTo: _organizationId)
                .get();
            // Filter out organization admins in code
            final teachers = teachersSnapshot.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isOrganizationAdmin'] != true;
            }).toList();
            setState(() {
              _activeTeachers = teachers.length;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading organization data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Organization Admin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              if (_organizationName != null)
                Text(
                  _organizationName!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        centerTitle: false,
        toolbarHeight: 90,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'add_admin':
                  _showAddAdminDialog();
                  break;
                case 'reset_password':
                  _showResetPasswordDialog();
                  break;
                case 'logout':
                  _showLogoutDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppTheme.primaryPurple),
                    SizedBox(width: 12),
                    Text('Add Admin'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset_password',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset, color: AppTheme.primaryBlue),
                    SizedBox(width: 12),
                    Text('Reset Password'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppTheme.error),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(160),
          child: Column(
            children: [
              // Stats Cards - Real-time update
              _organizationId == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .where('organizationId', isEqualTo: _organizationId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        // Calculate real-time teacher count
                        int teacherCount = 0;
                        int activeCount = 0;

                        if (snapshot.hasData) {
                          final teachers = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['isOrganizationAdmin'] != true;
                          }).toList();

                          teacherCount = teachers.length;
                          activeCount = teachers.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['isDisabled'] != true;
                          }).length;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.people, color: Colors.white, size: 32),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$teacherCount / $_maxDevices',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'Teachers',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white, size: 32),
                                      const SizedBox(height: 8),
                                      Text(
                                        activeCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'Active',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 8),
              // Tab Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppTheme.primaryPurple,
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Teachers'),
                      Tab(text: 'Analytics'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeachersList(),
          _buildAnalytics(),
        ],
      ),
      floatingActionButton: _organizationId == null
          ? null
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('organizationId', isEqualTo: _organizationId)
                  .snapshots(),
              builder: (context, snapshot) {
                int teacherCount = 0;
                if (snapshot.hasData) {
                  final teachers = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['isOrganizationAdmin'] != true;
                  }).toList();
                  teacherCount = teachers.length;
                }

                // Show different button based on whether limit is reached
                if (teacherCount < _maxDevices) {
                  return FloatingActionButton.extended(
                    onPressed: _showAddTeacherDialog,
                    backgroundColor: AppTheme.primaryPurple,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Teacher'),
                  );
                } else {
                  // Limit reached - show buy more option
                  return FloatingActionButton.extended(
                    onPressed: _showBuyMoreSlotsDialog,
                    backgroundColor: AppTheme.primaryBlue,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Buy More Slots'),
                  );
                }
              },
            ),
    );
  }

  Widget _buildTeachersList() {
    if (_organizationId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('organizationId', isEqualTo: _organizationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Filter out organization admins in code
        final teachers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isOrganizationAdmin'] != true;
        }).toList();

        if (teachers.isEmpty) {
          return _buildEmptyState();
        }

        // Sort teachers by name with natural sorting (handles numbers correctly)
        teachers.sort((a, b) {
          final nameA = ((a.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
          final nameB = ((b.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
          return _naturalCompare(nameA, nameB);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            return _buildTeacherCard(teachers[index]);
          },
        );
      },
    );
  }

  // Natural comparison for sorting names with numbers correctly (a1, a2, a10 instead of a1, a10, a2)
  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(a).toList();
    final matchesB = regExp.allMatches(b).toList();

    for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
      final partA = matchesA[i].group(0)!;
      final partB = matchesB[i].group(0)!;

      // Check if both parts are numeric
      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      int result;
      if (numA != null && numB != null) {
        result = numA.compareTo(numB);
      } else {
        result = partA.compareTo(partB);
      }

      if (result != 0) return result;
    }

    return matchesA.length.compareTo(matchesB.length);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No teachers added yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first teacher',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final createdAt = data['createdAt'] as Timestamp?;
    final isDisabled = data['isDisabled'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.red.withOpacity(0.1)
                      : AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isDisabled ? Colors.red : AppTheme.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        if (isDisabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Disabled',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Joined: ${DateFormat('dd MMM yyyy').format(createdAt.toDate())}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewTeacherDetails(doc.id, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryBlue, Color(0xFF5B9FED)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'View Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleTeacherStatus(doc.id, isDisabled, name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isDisabled ? AppTheme.success : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDisabled ? AppTheme.success : AppTheme.error,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDisabled ? Icons.check_circle : Icons.block,
                          color: isDisabled ? Colors.white : AppTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDisabled ? 'Enable' : 'Disable',
                          style: TextStyle(
                            color: isDisabled ? Colors.white : AppTheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics() {
    if (_organizationId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('organizationId', isEqualTo: _organizationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        // Filter out organization admins in code
        final teachers = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isOrganizationAdmin'] != true;
        }).toList();
        final activeTeachers = teachers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isDisabled'] != true;
        }).length;
        final disabledTeachers = teachers.length - activeTeachers;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAnalyticsCard(
                'Total Teachers',
                teachers.length.toString(),
                Icons.people,
                AppTheme.primaryPurple,
              ),
              const SizedBox(height: 12),
              _buildAnalyticsCard(
                'Active Teachers',
                activeTeachers.toString(),
                Icons.check_circle,
                AppTheme.success,
              ),
              const SizedBox(height: 12),
              _buildAnalyticsCard(
                'Disabled Teachers',
                disabledTeachers.toString(),
                Icons.block,
                AppTheme.error,
              ),
              const SizedBox(height: 12),
              _buildAnalyticsCard(
                'Available Slots',
                '${_maxDevices - teachers.length}',
                Icons.add_circle,
                AppTheme.primaryBlue,
              ),
              const SizedBox(height: 24),
              if (teachers.isNotEmpty) ...[
                const Text(
                  'Recent Teachers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                ...teachers.take(5).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown';
                  final email = data['email'] ?? 'No email';
                  final createdAt = data['createdAt'] as Timestamp?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            DateFormat('dd MMM').format(createdAt.toDate()),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTeacherDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add, color: AppTheme.primaryPurple),
            ),
            const SizedBox(width: 12),
            const Text('Add New Teacher'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Teacher Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                Navigator.pop(context);
                _createTeacherAccount(nameController.text, emailController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Teacher', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBuyMoreSlotsDialog() {
    int additionalSlots = 1;
    const int pricePerSlot = 5000;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final totalPrice = additionalSlots * pricePerSlot;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Buy More Teacher Slots', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Limit:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        '$_maxDevices teachers',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Price info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Price per Teacher:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        'Rs. 5,000',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quantity selector
                const Text('Select number of additional slots:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: additionalSlots > 1
                          ? () => setDialogState(() => additionalSlots--)
                          : null,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: additionalSlots > 1
                              ? AppTheme.primaryBlue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.remove,
                          color: additionalSlots > 1 ? AppTheme.primaryBlue : Colors.grey,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$additionalSlots',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: additionalSlots < 50
                          ? () => setDialogState(() => additionalSlots++)
                          : null,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: additionalSlots < 50
                              ? AppTheme.primaryBlue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add,
                          color: additionalSlots < 50 ? AppTheme.primaryBlue : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                      ),
                      Text(
                        'Rs. ${NumberFormat('#,###').format(totalPrice)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // New limit info
                Text(
                  'New limit will be: ${_maxDevices + additionalSlots} teachers',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processPayment(additionalSlots, totalPrice);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processPayment(int additionalSlots, int totalAmount) async {
    // Navigate to payment screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TeacherSlotPaymentScreen(
          additionalSlots: additionalSlots,
          totalAmount: totalAmount,
          organizationId: _organizationId!,
          currentMaxDevices: _maxDevices,
          organizationName: _organizationName ?? 'Unknown Organization',
        ),
      ),
    );

    if (result == true) {
      // Payment successful - reload data
      _loadOrganizationData();
      _showSnackBar('$additionalSlots teacher slot(s) added successfully!', AppTheme.success);
    }
  }

  String _generatePassword() {
    const length = 10;
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _createTeacherAccount(String name, String email) async {
    HapticFeedback.mediumImpact();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Check if teacher limit reached
      if (_activeTeachers >= _maxDevices) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Teacher limit reached. Cannot add more teachers.', AppTheme.error);
        return;
      }

      // Check if user already exists
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('User with this email already exists', AppTheme.error);
        return;
      }

      // Generate password
      final password = _generatePassword();

      // Create user account using secondary Firebase app
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = Firebase.app('SecondaryApp');
      } catch (e) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create the user
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      // Create user document in Firestore
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isAdmin': false,
        'isTeacher': true,
        'organizationId': _organizationId,
        'organizationName': _organizationName,
        'subscriptionStatus': 'active',
        'subscriptionPackage': 'Organization',
      });

      // Sign out from secondary app
      await secondaryAuth.signOut();

      Navigator.pop(context); // Close loading dialog

      // Send credentials via email
      await _sendCredentialsViaEmail(name, email, password);

      // Show success dialog with credentials
      _showCredentialsDialog(name, email, password);

      // Reload organization data
      _loadOrganizationData();
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error creating teacher account: $e');
      _showSnackBar('Failed to create teacher account: ${e.toString()}', AppTheme.error);
    }
  }

  void _showCredentialsDialog(String name, String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.success),
            ),
            const SizedBox(width: 12),
            const Text('Teacher Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teacher account created successfully for $name.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Login Credentials:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(email)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          password,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: password));
                          _showSnackBar('Password copied to clipboard', AppTheme.success);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please save these credentials and share them with the teacher.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCredentialsViaEmail(String name, String email, String password) async {
    final subject = Uri.encodeComponent('Welcome to Edu Manager - Teacher Account Created!');
    final body = Uri.encodeComponent('''Dear $name,

Welcome to Edu Manager! Your teacher account has been created by your organization admin.

Organization: $_organizationName

LOGIN CREDENTIALS:
Email: $email
Password: $password

You can now login to the Edu Manager app using these credentials.

IMPORTANT: Please change your password after first login from Profile Settings for security.

If you have any questions, please contact your organization administrator.

Best regards,
Edu Manager Team''');

    final mailtoUrl = Uri.parse('mailto:$email?subject=$subject&body=$body');

    debugPrint('Sending email to: $email');

    try {
      if (await canLaunchUrl(mailtoUrl)) {
        await launchUrl(mailtoUrl, mode: LaunchMode.externalApplication);
        if (mounted) {
          _showSnackBar('Email client opened. Please send the email.', AppTheme.success);
        }
      } else {
        debugPrint('Could not launch email client');
      }
    } catch (e) {
      debugPrint('Email error: $e');
    }
  }

  Future<void> _viewTeacherDetails(String teacherId, Map<String, dynamic> data) async {
    // Navigate to Teacher Activities Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherActivitiesScreen(
          teacherId: teacherId,
          teacherName: data['name'] ?? 'Unknown',
          teacherEmail: data['email'] ?? '',
          joinedDate: data['createdAt'] as Timestamp?,
          isDisabled: data['isDisabled'] == true,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Future<void> _toggleTeacherStatus(String teacherId, bool currentlyDisabled, String name) async {
    HapticFeedback.mediumImpact();

    final action = currentlyDisabled ? 'enable' : 'disable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              currentlyDisabled ? Icons.check_circle : Icons.block,
              color: currentlyDisabled ? AppTheme.success : AppTheme.error,
            ),
            const SizedBox(width: 12),
            Text('${action[0].toUpperCase()}${action.substring(1)} Teacher'),
          ],
        ),
        content: Text('Are you sure you want to $action $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyDisabled ? AppTheme.success : AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              action[0].toUpperCase() + action.substring(1),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('users').doc(teacherId).update({
          'isDisabled': !currentlyDisabled,
        });
        _showSnackBar(
          'Teacher ${currentlyDisabled ? "enabled" : "disabled"} successfully',
          currentlyDisabled ? AppTheme.success : AppTheme.error,
        );
      } catch (e) {
        debugPrint('Error toggling teacher status: $e');
        _showSnackBar('Failed to update teacher status', AppTheme.error);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showResetPasswordDialog() {
    final emailController = TextEditingController();
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentEmail = authService.currentUser?.email ?? '';
    emailController.text = currentEmail;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_reset, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 12),
            const Text('Reset Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We will send a password reset link to your email address.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              readOnly: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: emailController.text.trim(),
                );
                _showSnackBar(
                  'Password reset email sent! Check your inbox.',
                  AppTheme.success,
                );
              } catch (e) {
                _showSnackBar(
                  'Failed to send reset email: ${e.toString()}',
                  AppTheme.error,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Send Reset Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAdminDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryPurple),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Add Organization Admin', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add another admin who can manage teachers in this organization.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Admin Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                Navigator.pop(context);
                _createAdminAccount(nameController.text, emailController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Admin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createAdminAccount(String name, String email) async {
    HapticFeedback.mediumImpact();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Check if user already exists
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('User with this email already exists', AppTheme.error);
        return;
      }

      // Generate password
      final password = _generatePassword();

      // Create user account using secondary Firebase app
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = Firebase.app('SecondaryApp');
      } catch (e) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create the user
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      // Create user document in Firestore with admin privileges
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isAdmin': false,
        'isTeacher': false,
        'isOrganizationAdmin': true,
        'organizationId': _organizationId,
        'organizationName': _organizationName,
        'maxDevices': _maxDevices,
        'subscriptionStatus': 'active',
        'subscriptionPackage': 'Organization',
      });

      // Sign out from secondary app
      await secondaryAuth.signOut();

      Navigator.pop(context); // Close loading dialog

      // Send credentials via email
      await _sendAdminCredentialsViaEmail(name, email, password);

      // Show success dialog with credentials
      _showAdminCredentialsDialog(name, email, password);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error creating admin account: $e');
      _showSnackBar('Failed to create admin account: ${e.toString()}', AppTheme.error);
    }
  }

  Future<void> _sendAdminCredentialsViaEmail(String name, String email, String password) async {
    final subject = Uri.encodeComponent('Welcome to Edu Manager - Organization Admin Account Created!');
    final body = Uri.encodeComponent('''Dear $name,

Welcome to Edu Manager! You have been added as an Organization Admin.

Organization: $_organizationName

LOGIN CREDENTIALS:
Email: $email
Password: $password

As an Organization Admin, you can:
- Add and manage teachers
- View organization analytics
- Enable/disable teacher accounts

You can now login to the Edu Manager app using these credentials.

IMPORTANT: Please change your password after first login from Profile Settings for security.

Best regards,
Edu Manager Team''');

    final mailtoUrl = Uri.parse('mailto:$email?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(mailtoUrl)) {
        await launchUrl(mailtoUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Email error: $e');
    }
  }

  void _showAdminCredentialsDialog(String name, String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.success),
            ),
            const SizedBox(width: 12),
            const Text('Admin Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Organization Admin account created successfully for $name.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Login Credentials:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(email)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          password,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: password));
                          _showSnackBar('Password copied to clipboard', AppTheme.success);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please save these credentials and share them with the new admin.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.error),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Payment screen for buying additional teacher slots
class _TeacherSlotPaymentScreen extends StatefulWidget {
  final int additionalSlots;
  final int totalAmount;
  final String organizationId;
  final int currentMaxDevices;
  final String organizationName;

  const _TeacherSlotPaymentScreen({
    required this.additionalSlots,
    required this.totalAmount,
    required this.organizationId,
    required this.currentMaxDevices,
    required this.organizationName,
  });

  @override
  State<_TeacherSlotPaymentScreen> createState() => _TeacherSlotPaymentScreenState();
}

class _TeacherSlotPaymentScreenState extends State<_TeacherSlotPaymentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'bank_transfer';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Additional Teacher Slots', '${widget.additionalSlots}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Price per Slot', 'Rs. 5,000'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Current Limit', '${widget.currentMaxDevices} teachers'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('New Limit', '${widget.currentMaxDevices + widget.additionalSlots} teachers'),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Rs. ${NumberFormat('#,###').format(widget.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Methods
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentOption(
                    'bank_transfer',
                    'Bank Transfer',
                    'Transfer to our bank account',
                    Icons.account_balance,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    'easypaisa',
                    'EasyPaisa',
                    'Pay via EasyPaisa',
                    Icons.phone_android,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    'jazzcash',
                    'JazzCash',
                    'Pay via JazzCash',
                    Icons.phone_android,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedPaymentMethod == 'bank_transfer') ...[
                    _buildDetailRow('Bank Name', 'Allied Bank (ABL)'),
                    _buildDetailRow('Account Title', 'Saqib Nawaz Khan'),
                    _buildDetailRow('IBAN', 'PK60ABPA0010088535210011'),
                  ] else if (_selectedPaymentMethod == 'easypaisa') ...[
                    _buildDetailRow('EasyPaisa Number', '0321-9655055'),
                    _buildDetailRow('Account Title', 'Saqib Nawaz Khan'),
                  ] else if (_selectedPaymentMethod == 'jazzcash') ...[
                    _buildDetailRow('JazzCash Number', '0309-9865055'),
                    _buildDetailRow('Account Title', 'Saqib Nawaz Khan'),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'After payment, click "Confirm Payment" and your slots will be activated within 24 hours after verification.',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Confirm Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Confirm Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPaymentOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withOpacity(0.1) : const Color(0xFFF8F9FE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Row(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied!'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(Icons.copy, size: 16, color: AppTheme.primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Get user details
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      final userEmail = authService.currentUser?.email ?? '';
      final userName = authService.currentUser?.displayName ?? '';

      // Create payment request in Firestore (pending approval)
      await _firestore.collection('payment_requests').add({
        'userId': userId,
        'email': userEmail,
        'name': userName,
        'organizationId': widget.organizationId,
        'organizationName': widget.organizationName,
        'type': 'teacher_slots',
        'additionalSlots': widget.additionalSlots,
        'amount': widget.totalAmount,
        'paymentMethod': _selectedPaymentMethod,
        'currentMaxDevices': widget.currentMaxDevices,
        'newMaxDevices': widget.currentMaxDevices + widget.additionalSlots,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Send WhatsApp notification to admin
      await _sendWhatsAppNotification(userName, userEmail);

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.success),
                ),
                const SizedBox(width: 12),
                const Text('Request Submitted!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your payment request has been submitted successfully!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your additional teacher slots will be activated within 24 hours after payment verification by admin.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        Navigator.pop(context, false); // Return false since slots aren't added yet
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _sendWhatsAppNotification(String userName, String userEmail) async {
    // Admin phone number (your number)
    const String adminPhone = '923219655055'; // Replace with your actual number

    final paymentMethodName = _selectedPaymentMethod == 'bank_transfer'
        ? 'Bank Transfer'
        : _selectedPaymentMethod == 'easypaisa'
            ? 'EasyPaisa'
            : 'JazzCash';

    final message = '''
*New Teacher Slot Purchase Request* 🏢

*Organization:* ${widget.organizationName}
*Requested by:* $userName
*Email:* $userEmail

*Order Details:*
📦 Additional Slots: ${widget.additionalSlots}
💰 Amount: Rs. ${NumberFormat('#,###').format(widget.totalAmount)}
💳 Payment Method: $paymentMethodName

*Current Limit:* ${widget.currentMaxDevices} teachers
*New Limit:* ${widget.currentMaxDevices + widget.additionalSlots} teachers

Please verify the payment and approve the request from Admin Panel.
''';

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse('https://wa.me/$adminPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('WhatsApp error: $e');
    }
  }
}
