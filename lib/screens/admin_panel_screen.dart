import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../utils/app_theme.dart';
import '../services/auth_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
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
                  Tab(text: 'Solo Users'),
                  Tab(text: 'Organizations'),
                  Tab(text: 'Pending'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSoloUsersList(),
          _buildOrganizationsList(),
          _buildPendingRequests(),
        ],
      ),
    );
  }

  // Solo Users - users who are not part of any organization
  Widget _buildSoloUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
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
          return _buildEmptyState('No solo users found');
        }

        // Filter only solo users (not organization admins or teachers)
        var soloUsers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isOrgAdmin = data['isOrganizationAdmin'] == true;
          final isOrgTeacher = data['organizationId'] != null && data['isOrganizationAdmin'] != true;
          final isAdmin = data['isAdmin'] == true;
          return !isOrgAdmin && !isOrgTeacher && !isAdmin;
        }).toList();

        if (soloUsers.isEmpty) {
          return _buildEmptyState('No solo users found');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: soloUsers.length,
          itemBuilder: (context, index) => _buildSoloUserCard(soloUsers[index]),
        );
      },
    );
  }

  // Organizations list - grouped by organization
  Widget _buildOrganizationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('organizations').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, orgSnapshot) {
        if (orgSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orgSnapshot.hasError) {
          return Center(
            child: Text('Error: ${orgSnapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        if (!orgSnapshot.hasData || orgSnapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No organizations found');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orgSnapshot.data!.docs.length,
          itemBuilder: (context, index) => _buildOrganizationCard(orgSnapshot.data!.docs[index]),
        );
      },
    );
  }

  Widget _buildOrganizationCard(QueryDocumentSnapshot orgDoc) {
    final orgData = orgDoc.data() as Map<String, dynamic>;
    final orgName = orgData['name'] ?? 'Unknown Organization';
    final adminName = orgData['adminName'] ?? 'Unknown Admin';
    final adminEmail = orgData['adminEmail'] ?? '';
    final devices = orgData['devices'] ?? 0;
    final package = orgData['package'] ?? '';
    final status = orgData['status'] ?? 'active';
    final createdAt = orgData['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Organization header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withOpacity(0.1),
                  AppTheme.primaryPurple.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
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
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryPurple, Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orgName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'ORGANIZATION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: status == 'active' ? AppTheme.success : Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.devices, size: 16, color: AppTheme.primaryPurple),
                            const SizedBox(width: 6),
                            Text(
                              '$devices Devices',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.card_membership, size: 16, color: AppTheme.primaryPurple),
                            const SizedBox(width: 6),
                            Text(
                              package,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (createdAt != null) ...[
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey[300],
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryPurple),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd MMM yy').format(createdAt.toDate()),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Admin info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 18, color: AppTheme.primaryPurple),
                    const SizedBox(width: 8),
                    const Text(
                      'Organization Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
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
                            adminName.isNotEmpty ? adminName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
                              adminName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                            Text(
                              adminEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user, size: 14, color: AppTheme.primaryPurple),
                            SizedBox(width: 4),
                            Text(
                              'ADMIN',
                              style: TextStyle(
                                color: AppTheme.primaryPurple,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Teachers list
                _buildOrganizationTeachers(orgDoc.id),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    // Disable/Enable organization button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleOrganizationStatus(orgDoc.id, orgName, status),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: status == 'disabled' ? AppTheme.success : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: status == 'disabled' ? AppTheme.success : Colors.orange,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                status == 'disabled' ? Icons.check_circle : Icons.block,
                                color: status == 'disabled' ? Colors.white : Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                status == 'disabled' ? 'Enable' : 'Disable',
                                style: TextStyle(
                                  color: status == 'disabled' ? Colors.white : Colors.orange,
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
                    // Delete organization button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _deleteOrganization(orgDoc.id, orgName, adminEmail),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_forever, color: Colors.red, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red,
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
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationTeachers(String organizationId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  'No teachers added yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          );
        }

        // Filter out organization admins - only show teachers
        final teachers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isOrganizationAdmin'] != true;
        }).toList();

        // Sort teachers by name with natural sorting (a1, a2, a10 instead of a1, a10, a2)
        teachers.sort((a, b) {
          final nameA = ((a.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
          final nameB = ((b.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
          return _naturalCompare(nameA, nameB);
        });

        if (teachers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  'No teachers added yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          );
        }

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            initiallyExpanded: false,
            leading: const Icon(Icons.people, size: 18, color: AppTheme.primaryBlue),
            title: Text(
              'Teachers (${teachers.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primaryBlue,
              ),
            ),
            children: teachers.map((teacherDoc) {
              final teacherData = teacherDoc.data() as Map<String, dynamic>;
              final teacherName = teacherData['name'] ?? 'Unknown';
              final teacherEmail = teacherData['email'] ?? '';
              final isDisabled = teacherData['isDisabled'] == true;
              final subscriptionStatus = teacherData['subscriptionStatus'] ?? 'none';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDisabled ? Colors.red.withOpacity(0.05) : AppTheme.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDisabled ? Colors.red.withOpacity(0.2) : AppTheme.primaryBlue.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDisabled ? Colors.red.withOpacity(0.1) : AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          teacherName.isNotEmpty ? teacherName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: isDisabled ? Colors.red : AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacherName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            teacherEmail,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? Colors.red.withOpacity(0.1)
                            : subscriptionStatus == 'active'
                                ? AppTheme.success.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDisabled ? 'DISABLED' : subscriptionStatus == 'active' ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: isDisabled
                              ? Colors.red
                              : subscriptionStatus == 'active'
                                  ? AppTheme.success
                                  : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Solo user card (individual users not part of organization)
  Widget _buildSoloUserCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final subscriptionStatus = data['subscriptionStatus'] ?? 'none';
    final subscriptionPackage = data['subscriptionPackage'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final isDisabled = data['isDisabled'] == true;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isDisabled) {
      statusColor = Colors.red;
      statusText = 'Disabled';
      statusIcon = Icons.block;
    } else if (subscriptionStatus == 'active') {
      statusColor = AppTheme.success;
      statusText = 'Active';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusText = 'No Subscription';
      statusIcon = Icons.warning;
    }

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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: statusColor,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SOLO',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subscriptionPackage.isNotEmpty || createdAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (subscriptionPackage.isNotEmpty) ...[
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.card_membership, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 6),
                          Text(
                            subscriptionPackage,
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
                  if (createdAt != null) ...[
                    if (subscriptionPackage.isNotEmpty)
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy').format(createdAt.toDate()),
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
                ],
              ),
            ),
          ],
          // Action buttons
          const SizedBox(height: 12),
          Row(
            children: [
              // Reactivate subscription button (only show if no active subscription)
              if (subscriptionStatus != 'active' && !isDisabled)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showReactivateDialog(doc.id, name, email),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.success, Color(0xFF45B869)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Reactivate',
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
              if (subscriptionStatus != 'active' && !isDisabled) const SizedBox(width: 8),
              // Change package button (only show if has active subscription)
              if (subscriptionStatus == 'active' && !isDisabled)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showChangePackageDialog(doc.id, name, email, subscriptionPackage),
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
                          Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Change Package',
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
              if (subscriptionStatus == 'active' && !isDisabled) const SizedBox(width: 8),
              // Disable/Enable account button
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleAccountStatus(doc.id, isDisabled, name),
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
          const SizedBox(height: 8),
          // Delete button row
          GestureDetector(
            onTap: () => _deleteUser(doc.id, email, name),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever, color: Colors.red, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('payment_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
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
          return _buildEmptyState('No pending requests');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return _buildPendingRequestCard(snapshot.data!.docs[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _showReactivateDialog(String userId, String name, String email) async {
    final package = await showDialog<String>(
      context: context,
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
              child: const Icon(Icons.refresh, color: AppTheme.success),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Reactivate Subscription')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reactivate subscription for $name?'),
            const SizedBox(height: 16),
            const Text(
              'Choose Package:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildPackageOption('Monthly', 'PKR 500 / month', Colors.blue),
            const SizedBox(height: 8),
            _buildPackageOption('Yearly', 'PKR 5000 / year', AppTheme.primaryPurple),
            const SizedBox(height: 8),
            _buildPackageOption('Lifetime', 'PKR 15000 / one-time', AppTheme.primaryBlue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (package != null) {
      await _reactivateSubscription(userId, email, package);
    }
  }

  Widget _buildPackageOption(String package, String price, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, package),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.card_membership, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _reactivateSubscription(String userId, String email, String package) async {
    HapticFeedback.mediumImpact();

    try {
      // Calculate expiry date
      DateTime? expiryDate;
      final now = DateTime.now();
      switch (package) {
        case 'Monthly':
          expiryDate = DateTime(now.year, now.month + 1, now.day);
          break;
        case 'Yearly':
          expiryDate = DateTime(now.year + 1, now.month, now.day);
          break;
        case 'Lifetime':
          expiryDate = null;
          break;
      }

      // Create subscription
      await _firestore.collection('subscriptions').add({
        'userId': userId,
        'userEmail': email,
        'package': package,
        'amount': package == 'Monthly' ? 500 : package == 'Yearly' ? 5000 : 15000,
        'startDate': FieldValue.serverTimestamp(),
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'status': 'active',
        'paymentMethod': 'Admin Reactivation',
        'transactionId': 'ADMIN-${DateTime.now().millisecondsSinceEpoch}',
        'activatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await _firestore.collection('users').doc(userId).set({
        'subscriptionPackage': package,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      }, SetOptions(merge: true));

      _showSnackBar('Subscription reactivated successfully!', AppTheme.success);
    } catch (e) {
      debugPrint('Error reactivating subscription: $e');
      _showSnackBar('Failed to reactivate subscription', AppTheme.error);
    }
  }

  Future<void> _showChangePackageDialog(
    String userId,
    String name,
    String email,
    String currentPackage,
  ) async {
    final newPackage = await showDialog<String>(
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
              child: const Icon(Icons.swap_horiz, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Change Package')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change subscription package for $name?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryPurple, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current: $currentPackage',
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select New Package:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildPackageOption('Monthly', 'PKR 500 / month', Colors.blue),
            const SizedBox(height: 8),
            _buildPackageOption('Yearly', 'PKR 5000 / year', AppTheme.primaryPurple),
            const SizedBox(height: 8),
            _buildPackageOption('Lifetime', 'PKR 15000 / one-time', AppTheme.primaryBlue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newPackage != null && newPackage != currentPackage) {
      await _changePackage(userId, email, newPackage);
    } else if (newPackage == currentPackage) {
      _showSnackBar('User already has $currentPackage package', Colors.orange);
    }
  }

  Future<void> _changePackage(String userId, String email, String newPackage) async {
    HapticFeedback.mediumImpact();

    try {
      // Calculate new expiry date
      DateTime? expiryDate;
      final now = DateTime.now();
      switch (newPackage) {
        case 'Monthly':
          expiryDate = DateTime(now.year, now.month + 1, now.day);
          break;
        case 'Yearly':
          expiryDate = DateTime(now.year + 1, now.month, now.day);
          break;
        case 'Lifetime':
          expiryDate = null;
          break;
      }

      // Find the current active subscription
      final subscriptionQuery = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('startDate', descending: true)
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isNotEmpty) {
        // Mark old subscription as changed
        await _firestore.collection('subscriptions').doc(subscriptionQuery.docs.first.id).update({
          'status': 'changed',
          'changedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create new subscription with updated package
      await _firestore.collection('subscriptions').add({
        'userId': userId,
        'userEmail': email,
        'package': newPackage,
        'amount': newPackage == 'Monthly' ? 500 : newPackage == 'Yearly' ? 5000 : 15000,
        'startDate': FieldValue.serverTimestamp(),
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'status': 'active',
        'paymentMethod': 'Admin Package Change',
        'transactionId': 'PACKAGE-CHANGE-${DateTime.now().millisecondsSinceEpoch}',
        'activatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await _firestore.collection('users').doc(userId).set({
        'subscriptionPackage': newPackage,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      }, SetOptions(merge: true));

      _showSnackBar('Package changed to $newPackage successfully!', AppTheme.success);
    } catch (e) {
      debugPrint('Error changing package: $e');
      _showSnackBar('Failed to change package', AppTheme.error);
    }
  }

  Future<void> _toggleAccountStatus(String userId, bool currentlyDisabled, String name) async {
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
            Text('${action[0].toUpperCase()}${action.substring(1)} Account'),
          ],
        ),
        content: Text('Are you sure you want to $action account for $name?'),
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
        await _firestore.collection('users').doc(userId).update({
          'isDisabled': !currentlyDisabled,
        });
        _showSnackBar(
          'Account ${currentlyDisabled ? "enabled" : "disabled"} successfully',
          currentlyDisabled ? AppTheme.success : AppTheme.error,
        );
      } catch (e) {
        debugPrint('Error toggling account status: $e');
        _showSnackBar('Failed to update account status', AppTheme.error);
      }
    }
  }

  Future<void> _deleteUser(String userId, String email, String name) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete the account for $name?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All user data will be permanently deleted.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // 1. Delete all subscriptions for this user
        final subscriptionsQuery = await _firestore
            .collection('subscriptions')
            .where('userId', isEqualTo: userId)
            .get();

        for (var doc in subscriptionsQuery.docs) {
          await doc.reference.delete();
        }

        // 2. Delete all payment requests for this user
        final paymentsQuery = await _firestore
            .collection('payment_requests')
            .where('email', isEqualTo: email)
            .get();

        for (var doc in paymentsQuery.docs) {
          await doc.reference.delete();
        }

        // 3. Delete user document from Firestore
        await _firestore.collection('users').doc(userId).delete();

        // 4. Delete from Firebase Authentication
        // Note: We cannot directly delete other users from Firebase Auth without Admin SDK
        // The user document deletion from Firestore is sufficient to prevent login
        // The Firebase Auth account will remain until manually deleted from Firebase Console

        Navigator.pop(context); // Close loading dialog

        _showSnackBar(
          'Account and all related data deleted successfully',
          AppTheme.success,
        );
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        debugPrint('Error deleting user: $e');
        _showSnackBar('Failed to delete account: ${e.toString()}', AppTheme.error);
      }
    }
  }

  Widget _buildPendingRequestCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final phone = data['phone'] ?? '';
    final package = data['package'] ?? '';
    final amount = data['amount'] ?? 0;
    final paymentMethod = data['paymentMethod'] ?? '';
    final transactionId = data['transactionId'] ?? '';
    final submittedAt = data['submittedAt'] as Timestamp?;
    final accountType = data['accountType'] ?? 'solo';
    final organizationName = data['organizationName'] ?? '';
    final devices = data['devices'] ?? 1;
    final requestType = data['type'] ?? 'subscription'; // 'subscription' or 'teacher_slots'
    final additionalSlots = data['additionalSlots'] ?? 0;
    final currentMaxDevices = data['currentMaxDevices'] ?? 0;
    final newMaxDevices = data['newMaxDevices'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.orange,
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
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textDark,
                      ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending, color: Colors.orange, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Teacher Slots Request Header
          if (requestType == 'teacher_slots') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.1),
                    AppTheme.primaryBlue.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_shopping_cart, color: AppTheme.primaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Teacher Slots Purchase',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        if (organizationName.isNotEmpty)
                          Text(
                            organizationName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (accountType == 'organization') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withOpacity(0.1),
                    AppTheme.primaryPurple.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, color: AppTheme.primaryPurple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organization Account',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                        if (organizationName.isNotEmpty)
                          Text(
                            organizationName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // Teacher Slots specific info
                if (requestType == 'teacher_slots') ...[
                  _buildInfoRow(Icons.add_circle, 'Additional Slots', '$additionalSlots slots'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.people_outline, 'Current Limit', '$currentMaxDevices teachers'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.people, 'New Limit', '$newMaxDevices teachers'),
                  const SizedBox(height: 8),
                ] else ...[
                  if (accountType == 'organization') ...[
                    _buildInfoRow(Icons.devices, 'Devices', '$devices devices'),
                    const SizedBox(height: 8),
                  ],
                  _buildInfoRow(Icons.card_membership, 'Package', package),
                  const SizedBox(height: 8),
                ],
                _buildInfoRow(Icons.attach_money, 'Amount', 'PKR ${_formatPrice(amount)}'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.payment, 'Method', paymentMethod),
                if (transactionId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.receipt, 'Transaction ID', transactionId),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.phone, 'Phone', phone),
                ],
                if (submittedAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today, 'Submitted',
                      DateFormat('dd MMM yyyy, HH:mm').format(submittedAt.toDate())),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _approveRequest(doc.id, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.success, Color(0xFF45B869)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Approve',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _rejectRequest(doc.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error, width: 2),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel, color: AppTheme.error, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Reject',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _generatePassword() {
    const length = 10;
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _approveRequest(String requestId, Map<String, dynamic> data) async {
    HapticFeedback.mediumImpact();

    try {
      final requestType = data['type'] ?? 'subscription';

      // Handle Teacher Slots purchase request
      if (requestType == 'teacher_slots') {
        await _approveTeacherSlotsRequest(requestId, data);
        return;
      }

      // Handle regular subscription request
      final email = data['email'];
      final name = data['name'] ?? 'User';
      final phone = data['phone'] ?? '';
      final package = data['package'] ?? 'Monthly';
      final amount = data['amount'] ?? 0;
      final accountType = data['accountType'] ?? 'solo';
      final organizationName = data['organizationName'] ?? '';
      final devices = data['devices'] ?? 1;

      // Check if user already exists
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      String userId;
      String password = '';

      if (userQuery.docs.isEmpty) {
        // User doesn't exist - create new account
        password = _generatePassword();

        // Create user account using secondary Firebase app to avoid logging out admin
        FirebaseApp? secondaryApp;
        try {
          // Try to get existing secondary app
          secondaryApp = Firebase.app('SecondaryApp');
        } catch (e) {
          // Create secondary app if it doesn't exist
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

        userId = userCredential.user!.uid;

        // Update display name
        await userCredential.user!.updateDisplayName(name);

        // Create user document in Firestore
        Map<String, dynamic> userData = {
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'isAdmin': false,
        };

        // Add organization-specific fields
        if (accountType == 'organization') {
          // Create organization document first
          final orgDoc = await _firestore.collection('organizations').add({
            'name': organizationName,
            'adminId': userId,
            'adminEmail': email,
            'adminName': name,
            'devices': devices,
            'package': package,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

          userData['isOrganizationAdmin'] = true;
          userData['organizationId'] = orgDoc.id;
          userData['organizationName'] = organizationName;
          userData['maxDevices'] = devices;
        }

        await _firestore.collection('users').doc(userId).set(userData);

        // Sign out from secondary app
        await secondaryAuth.signOut();
      } else {
        // User already exists
        userId = userQuery.docs.first.id;
        password = ''; // Don't reset password for existing users
      }

      // Calculate expiry date
      DateTime? expiryDate;
      final now = DateTime.now();
      switch (package) {
        case 'Monthly':
          expiryDate = DateTime(now.year, now.month + 1, now.day);
          break;
        case 'Yearly':
          expiryDate = DateTime(now.year + 1, now.month, now.day);
          break;
        case 'Lifetime':
          expiryDate = null;
          break;
      }

      // Create subscription
      await _firestore.collection('subscriptions').add({
        'userId': userId,
        'userEmail': email,
        'package': package,
        'amount': amount,
        'startDate': FieldValue.serverTimestamp(),
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'status': 'active',
        'paymentMethod': data['paymentMethod'] ?? '',
        'transactionId': data['transactionId'] ?? '',
        'activatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await _firestore.collection('users').doc(userId).set({
        'subscriptionPackage': package,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      }, SetOptions(merge: true));

      // Update payment request status
      await _firestore.collection('payment_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Subscription activated successfully!', AppTheme.success);

      // Show credentials dialog if password was generated
      if (password.isNotEmpty) {
        _showCredentialsDialogWithActions(
          name,
          email,
          password,
          accountType,
          organizationName,
          package,
          phone,
        );
      }
    } catch (e) {
      debugPrint('Error approving request: $e');
      _showSnackBar('Failed to approve request: ${e.toString()}', AppTheme.error);
    }
  }

  Future<void> _approveTeacherSlotsRequest(String requestId, Map<String, dynamic> data) async {
    try {
      final organizationId = data['organizationId'] ?? '';
      final organizationName = data['organizationName'] ?? '';
      final newMaxDevices = data['newMaxDevices'] ?? 0;
      final additionalSlots = data['additionalSlots'] ?? 0;
      final amount = data['amount'] ?? 0;

      if (organizationId.isEmpty) {
        _showSnackBar('Organization ID not found', AppTheme.error);
        return;
      }

      // Update all organization admins with new maxDevices
      final adminDocs = await _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .where('isOrganizationAdmin', isEqualTo: true)
          .get();

      for (final doc in adminDocs.docs) {
        await doc.reference.update({
          'maxDevices': newMaxDevices,
        });
      }

      // Update organization document with new device limit
      await _firestore.collection('organizations').doc(organizationId).update({
        'devices': newMaxDevices,
      });

      // Create a record of the purchase
      await _firestore.collection('slot_purchases').add({
        'organizationId': organizationId,
        'organizationName': organizationName,
        'additionalSlots': additionalSlots,
        'amount': amount,
        'previousMaxDevices': data['currentMaxDevices'] ?? 0,
        'newMaxDevices': newMaxDevices,
        'paymentMethod': data['paymentMethod'] ?? '',
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Update payment request status
      await _firestore.collection('payment_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar(
        '$additionalSlots teacher slot(s) added to $organizationName!',
        AppTheme.success,
      );
    } catch (e) {
      debugPrint('Error approving teacher slots request: $e');
      _showSnackBar('Failed to approve request: ${e.toString()}', AppTheme.error);
    }
  }

  Future<void> _sendCredentialsViaWhatsApp(
    String name,
    String email,
    String password,
    String phone,
    String package, {
    String accountType = 'solo',
    String organizationName = '',
  }) async {
    // Clean phone number - remove all non-digit characters
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Ensure it has country code (92 for Pakistan)
    // Remove leading 0 if present and add country code
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '92${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('92')) {
      cleanPhone = '92$cleanPhone';
    }

    String message;
    if (accountType == 'organization') {
      message = '''
*Welcome to Edu Manager!* 🎓🏢

Hi $name,

Your organization payment has been verified and your **ADMIN ACCOUNT** is now active!

*Organization:* $organizationName

*Admin Login Credentials:*
📧 Email: $email
🔑 Password: $password

*Subscription:* $package

*Admin Features:*
✅ Create & manage teacher accounts
✅ Monitor all teachers
✅ Full organization control
✅ Access to all reports

Please login and start adding your teachers!
''';
    } else {
      message = '''
*Welcome to Edu Manager!* 🎓

Hi $name,

Your payment has been verified and your account is now active!

*Login Credentials:*
📧 Email: $email
🔑 Password: $password

*Subscription:* $package

Download the app and login with these credentials.

*Important:* Please change your password after first login from Profile Settings.

Thank you for choosing Edu Manager!
''';
    }

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    debugPrint('Opening WhatsApp for: $cleanPhone');
    debugPrint('WhatsApp URL: $whatsappUrl');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showSnackBar('Could not open WhatsApp. Phone: $cleanPhone', Colors.orange);
        }
      }
    } catch (e) {
      debugPrint('WhatsApp error: $e');
      if (mounted) {
        _showSnackBar('WhatsApp error: $e', AppTheme.error);
      }
    }
  }

  Future<void> _sendCredentialsViaEmail(
    String name,
    String email,
    String password,
    String package, {
    String accountType = 'solo',
    String organizationName = '',
  }) async {
    String subject;
    String body;

    if (accountType == 'organization') {
      subject = Uri.encodeComponent('Welcome to Edu Manager - Organization Admin Account Created!');
      body = Uri.encodeComponent('''Dear $name,

Congratulations! Your organization payment has been verified and your ADMIN ACCOUNT is now active!

Organization: $organizationName

LOGIN CREDENTIALS:
Email: $email
Password: $password

Subscription Package: $package

ADMIN FEATURES:
✓ Create & manage teacher accounts
✓ Monitor all teachers
✓ Full organization control
✓ Access to all reports

NEXT STEPS:
1. Download the Edu Manager app
2. Login with your credentials
3. Start adding your teachers from the Organization Admin panel

IMPORTANT: Please change your password after first login from Profile Settings for security.

If you have any questions or need assistance, please don't hesitate to contact us.

Best regards,
Edu Manager Team''');
    } else {
      subject = Uri.encodeComponent('Welcome to Edu Manager - Your Account is Active!');
      body = Uri.encodeComponent('''Dear $name,

Welcome to Edu Manager! Your payment has been verified and your account is now active.

LOGIN CREDENTIALS:
Email: $email
Password: $password

Subscription Package: $package

You can now login to the Edu Manager app using these credentials.

IMPORTANT: Please change your password after first login from Profile Settings for security.

Thank you for choosing Edu Manager!

Best regards,
Edu Manager Team''');
    }

    final mailtoUrl = Uri.parse('mailto:$email?subject=$subject&body=$body');

    debugPrint('Sending email to: $email');

    try {
      if (await canLaunchUrl(mailtoUrl)) {
        await launchUrl(mailtoUrl, mode: LaunchMode.externalApplication);
        if (mounted) {
          _showSnackBar('Email client opened. Please send the email.', AppTheme.success);
        }
      } else {
        if (mounted) {
          _showSnackBar('Could not open email client. Please copy and send credentials manually.', AppTheme.error);
        }
      }
    } catch (e) {
      debugPrint('Email error: $e');
      if (mounted) {
        _showSnackBar('Email error. Please copy and send credentials manually.', AppTheme.error);
      }
    }
  }

  void _showCredentialsDialog(
    String name,
    String email,
    String password,
    String accountType,
    String organizationName,
    String package,
  ) {
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
            const Expanded(child: Text('Account Created!')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                accountType == 'organization'
                    ? 'Organization admin account created for $name'
                    : 'Account created for $name',
              ),
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
                    if (accountType == 'organization' && organizationName.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.business, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Organization: $organizationName')),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(email)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: email));
                            _showSnackBar('Email copied', AppTheme.success);
                          },
                        ),
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
                            _showSnackBar('Password copied', AppTheme.success);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.card_membership, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Package: $package')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please save these credentials and manually send them to the user via email or message.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy full credentials to clipboard
              final credentials = '''
Email: $email
Password: $password
Package: $package
${accountType == 'organization' && organizationName.isNotEmpty ? 'Organization: $organizationName' : ''}
''';
              Clipboard.setData(ClipboardData(text: credentials));
              _showSnackBar('All credentials copied to clipboard', AppTheme.success);
            },
            child: const Text('Copy All'),
          ),
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

  void _showCredentialsDialogWithActions(
    String name,
    String email,
    String password,
    String accountType,
    String organizationName,
    String package,
    String phone,
  ) {
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
            const Expanded(child: Text('Account Created!')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                accountType == 'organization'
                    ? 'Organization admin account created for $name'
                    : 'Account created for $name',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key, color: AppTheme.primaryPurple, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Login Credentials',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (accountType == 'organization' && organizationName.isNotEmpty) ...[
                      _buildCredentialRow(
                        icon: Icons.business,
                        label: 'Organization',
                        value: organizationName,
                        canCopy: false,
                      ),
                      const Divider(height: 16),
                    ],
                    _buildCredentialRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: email,
                      canCopy: true,
                    ),
                    const Divider(height: 16),
                    _buildCredentialRow(
                      icon: Icons.lock,
                      label: 'Password',
                      value: password,
                      canCopy: true,
                      isPassword: true,
                    ),
                    const Divider(height: 16),
                    _buildCredentialRow(
                      icon: Icons.card_membership,
                      label: 'Package',
                      value: package,
                      canCopy: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Send these credentials to the user using the buttons below.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Send via Email button
          TextButton.icon(
            onPressed: () {
              _sendCredentialsViaEmail(
                name,
                email,
                password,
                package,
                accountType: accountType,
                organizationName: organizationName,
              );
            },
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
            ),
          ),
          // Send via WhatsApp button
          if (phone.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _sendCredentialsViaWhatsApp(
                  name,
                  email,
                  password,
                  phone,
                  package,
                  accountType: accountType,
                  organizationName: organizationName,
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.success,
              ),
            ),
          // Copy All button
          TextButton.icon(
            onPressed: () {
              final credentials = '''
Email: $email
Password: $password
Package: $package
${accountType == 'organization' && organizationName.isNotEmpty ? 'Organization: $organizationName' : ''}
''';
              Clipboard.setData(ClipboardData(text: credentials));
              _showSnackBar('All credentials copied to clipboard', AppTheme.success);
            },
            icon: const Icon(Icons.copy_all),
            label: const Text('Copy All'),
          ),
          // Done button
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

  Widget _buildCredentialRow({
    required IconData icon,
    required String label,
    required String value,
    required bool canCopy,
    bool isPassword = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textGrey.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isPassword ? FontWeight.bold : FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              _showSnackBar('$label copied', AppTheme.success);
            },
            color: AppTheme.primaryPurple,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Future<void> _rejectRequest(String requestId) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AppTheme.error),
            SizedBox(width: 12),
            Text('Reject Request'),
          ],
        ),
        content: const Text('Are you sure you want to reject this payment request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('payment_requests').doc(requestId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
        _showSnackBar('Request rejected', AppTheme.error);
      } catch (e) {
        debugPrint('Error rejecting request: $e');
        _showSnackBar('Failed to reject request', AppTheme.error);
      }
    }
  }

  Future<void> _toggleOrganizationStatus(String orgId, String orgName, String currentStatus) async {
    HapticFeedback.mediumImpact();

    final isDisabled = currentStatus == 'disabled';
    final action = isDisabled ? 'enable' : 'disable';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isDisabled ? Icons.check_circle : Icons.block,
              color: isDisabled ? AppTheme.success : Colors.orange,
            ),
            const SizedBox(width: 12),
            Text('${action[0].toUpperCase()}${action.substring(1)} Organization'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to $action "$orgName"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDisabled
                          ? 'This will enable the organization admin and all teachers under this organization.'
                          : 'This will disable the organization admin and all teachers under this organization.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled ? AppTheme.success : Colors.orange,
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
        final newStatus = isDisabled ? 'active' : 'disabled';

        // Update organization status
        await _firestore.collection('organizations').doc(orgId).update({
          'status': newStatus,
        });

        // Disable/Enable all users under this organization (admin + teachers)
        final orgUsers = await _firestore
            .collection('users')
            .where('organizationId', isEqualTo: orgId)
            .get();

        for (final doc in orgUsers.docs) {
          await doc.reference.update({
            'isDisabled': !isDisabled,
          });
        }

        _showSnackBar(
          'Organization "${orgName}" ${isDisabled ? "enabled" : "disabled"} successfully',
          isDisabled ? AppTheme.success : Colors.orange,
        );
      } catch (e) {
        debugPrint('Error toggling organization status: $e');
        _showSnackBar('Failed to update organization status', AppTheme.error);
      }
    }
  }

  Future<void> _deleteOrganization(String orgId, String orgName, String adminEmail) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Delete Organization')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete "$orgName"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will permanently delete:\n'
                      '- The organization\n'
                      '- Organization admin account\n'
                      '- All teacher accounts\n'
                      '- All related subscriptions\n\n'
                      'This action cannot be undone!',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // 1. Get all users under this organization
        final orgUsers = await _firestore
            .collection('users')
            .where('organizationId', isEqualTo: orgId)
            .get();

        // 2. Delete subscriptions for all org users
        for (final userDoc in orgUsers.docs) {
          final subsQuery = await _firestore
              .collection('subscriptions')
              .where('userId', isEqualTo: userDoc.id)
              .get();
          for (final subDoc in subsQuery.docs) {
            await subDoc.reference.delete();
          }
        }

        // 3. Delete payment requests for org users
        for (final userDoc in orgUsers.docs) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userEmail = userData['email'] ?? '';
          if (userEmail.isNotEmpty) {
            final paymentsQuery = await _firestore
                .collection('payment_requests')
                .where('email', isEqualTo: userEmail)
                .get();
            for (final payDoc in paymentsQuery.docs) {
              await payDoc.reference.delete();
            }
          }
        }

        // 4. Delete slot purchases for this organization
        final slotPurchases = await _firestore
            .collection('slot_purchases')
            .where('organizationId', isEqualTo: orgId)
            .get();
        for (final doc in slotPurchases.docs) {
          await doc.reference.delete();
        }

        // 5. Delete all user documents under this organization
        for (final userDoc in orgUsers.docs) {
          await userDoc.reference.delete();
        }

        // 6. Delete the organization document
        await _firestore.collection('organizations').doc(orgId).delete();

        Navigator.pop(context); // Close loading dialog

        _showSnackBar(
          'Organization "$orgName" and all related data deleted successfully',
          AppTheme.success,
        );
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        debugPrint('Error deleting organization: $e');
        _showSnackBar('Failed to delete organization: ${e.toString()}', AppTheme.error);
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
        content: const Text('Are you sure you want to logout from Admin Panel?'),
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
}
