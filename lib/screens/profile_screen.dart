import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/biometric_service.dart';
import '../utils/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final _biometricService = BiometricService();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  late AnimationController _updateButtonController;
  late Animation<double> _updateButtonScale;
  late AnimationController _logoutButtonController;
  late Animation<double> _logoutButtonScale;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkBiometric();

    _updateButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _updateButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _updateButtonController, curve: Curves.easeInOut),
    );

    _logoutButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _logoutButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _logoutButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _updateButtonController.dispose();
    _logoutButtonController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final profileService = Provider.of<ProfileService>(context, listen: false);
    final data = await profileService.getUserProfile();

    setState(() {
      _profileData = data;
      _nameController.text = data?['name'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _checkBiometric() async {
    final available = await _biometricService.isBiometricAvailable();
    final enabled = await _biometricService.isBiometricEnabled();
    final biometrics = await _biometricService.getAvailableBiometrics();

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _availableBiometrics = biometrics;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.selectionClick();
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      final profileService = Provider.of<ProfileService>(context, listen: false);
      final error = await profileService.uploadProfilePicture(File(image.path));

      if (mounted) {
        if (error == null) {
          HapticFeedback.lightImpact();
          _showSnackBar('Profile picture updated!', AppTheme.success);
          _loadProfile();
        } else {
          HapticFeedback.heavyImpact();
          _showSnackBar(error, AppTheme.error);
        }
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      _showSnackBar('Failed to pick image: $e', AppTheme.error);
    }
  }

  void _showImageSourceDialog() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Photo Source',
              style: AppTheme.heading3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildSourceOption(
              icon: Icons.camera_alt_rounded,
              label: 'Camera',
              color: AppTheme.primaryPurple,
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildSourceOption(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              color: AppTheme.primaryGreen,
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _showSnackBar('Please enter your name', AppTheme.warning);
      return;
    }

    final profileService = Provider.of<ProfileService>(context, listen: false);
    final error = await profileService.updateProfileName(_nameController.text.trim());

    if (mounted) {
      if (error == null) {
        HapticFeedback.lightImpact();
        _showSnackBar('Profile updated!', AppTheme.success);
        _loadProfile();
      } else {
        HapticFeedback.heavyImpact();
        _showSnackBar(error, AppTheme.error);
      }
    }
  }

  void _showPasswordDialogForBiometric() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.lightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_outline, color: AppTheme.primaryPurple, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Verify Password'),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.primaryPurple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF8F9FE),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              passwordController.dispose();
              Navigator.pop(dialogContext);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final authService = Provider.of<AuthService>(context, listen: false);
              final email = authService.currentUser?.email ?? '';

              if (email.isEmpty) {
                Navigator.pop(dialogContext);
                _showSnackBar('No email found', AppTheme.error);
                passwordController.dispose();
                return;
              }

              final error = await authService.signInWithEmail(
                email: email,
                password: passwordController.text,
              );

              if (error == null) {
                await _biometricService.saveCredentials(
                  email,
                  passwordController.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  _checkBiometric();
                  HapticFeedback.lightImpact();
                  _showSnackBar('Biometric login enabled!', AppTheme.success);
                }
              } else {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  HapticFeedback.heavyImpact();
                  _showSnackBar('Incorrect password', AppTheme.error);
                }
              }
              passwordController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppTheme.success
                  ? Icons.check_circle_rounded
                  : color == AppTheme.error
                      ? Icons.error_rounded
                      : Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showLogoutDialog() {
    HapticFeedback.mediumImpact();
    final authService = Provider.of<AuthService>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.lightPink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout from your account?'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(dialogContext);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await authService.signOut();
              if (dialogContext.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileService = Provider.of<ProfileService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading profile...',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textGrey),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Header with gradient background
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryPurple,
                            AppTheme.primaryPurple.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
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
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'My Profile',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Profile Picture
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _showImageSourceDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _profileData?['photoUrl'] != null
                                        ? NetworkImage(_profileData!['photoUrl'])
                                        : null,
                                    child: _profileData?['photoUrl'] == null
                                        ? Text(
                                            _profileData?['name']?.substring(0, 1).toUpperCase() ?? 'T',
                                            style: const TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryPurple,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTapDown: (_) => HapticFeedback.selectionClick(),
                                  onTap: _showImageSourceDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: AppTheme.primaryPurple,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _profileData?['name'] ?? 'Teacher',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profileData?['email'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Personal Information Card
                          _buildInfoCard(
                            title: 'Personal Information',
                            icon: Icons.person_rounded,
                            color: AppTheme.primaryPurple,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  icon: Icons.badge_rounded,
                                  enabled: true,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: TextEditingController(text: _profileData?['email'] ?? ''),
                                  label: 'Email Address',
                                  icon: Icons.email_rounded,
                                  enabled: false,
                                ),
                                const SizedBox(height: 24),
                                // Update Button with 3D touch
                                GestureDetector(
                                  onTapDown: (_) {
                                    HapticFeedback.selectionClick();
                                    _updateButtonController.forward();
                                  },
                                  onTapUp: (_) => _updateButtonController.reverse(),
                                  onTapCancel: () => _updateButtonController.reverse(),
                                  onTap: profileService.isLoading ? null : _updateName,
                                  child: AnimatedBuilder(
                                    animation: _updateButtonScale,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _updateButtonScale.value,
                                        child: Container(
                                          width: double.infinity,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryPurple,
                                                AppTheme.primaryPurple.withValues(alpha: 0.8),
                                              ],
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
                                            child: profileService.isLoading
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(Icons.save_rounded, color: Colors.white),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Update Profile',
                                                        style: AppTheme.bodyLarge.copyWith(
                                                          color: Colors.white,
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
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Security Card
                          if (_biometricAvailable)
                            _buildInfoCard(
                              title: 'Security',
                              icon: Icons.shield_rounded,
                              color: AppTheme.primaryGreen,
                              child: _buildBiometricTile(),
                            ),

                          const SizedBox(height: 20),

                          // Logout Card with 3D touch
                          GestureDetector(
                            onTapDown: (_) {
                              HapticFeedback.selectionClick();
                              _logoutButtonController.forward();
                            },
                            onTapUp: (_) => _logoutButtonController.reverse(),
                            onTapCancel: () => _logoutButtonController.reverse(),
                            onTap: _showLogoutDialog,
                            child: AnimatedBuilder(
                              animation: _logoutButtonScale,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _logoutButtonScale.value,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.error.withValues(alpha: 0.15),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.logout_rounded,
                                            color: AppTheme.error,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Logout',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.error,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'Sign out from your account',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.textGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: AppTheme.error,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF8F9FE) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        onTap: () => HapticFeedback.selectionClick(),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: enabled ? AppTheme.primaryPurple : AppTheme.textGrey,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? const Color(0xFFF8F9FE) : Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildBiometricTile() {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: () async {
        HapticFeedback.mediumImpact();
        if (!_biometricEnabled) {
          final authenticated = await _biometricService.authenticateWithBiometrics();
          if (authenticated && mounted) {
            _showPasswordDialogForBiometric();
          } else {
            HapticFeedback.heavyImpact();
            _showSnackBar('Authentication failed', AppTheme.error);
          }
        } else {
          await _biometricService.disableBiometric();
          _checkBiometric();
          HapticFeedback.lightImpact();
          _showSnackBar('Biometric login disabled', AppTheme.success);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _biometricEnabled
              ? AppTheme.primaryGreen.withValues(alpha: 0.1)
              : const Color(0xFFF8F9FE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _biometricEnabled
                ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _biometricEnabled
                    ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                    : AppTheme.lightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _availableBiometrics.contains(BiometricType.face)
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
                color: _biometricEnabled ? AppTheme.primaryGreen : AppTheme.primaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _biometricService.getBiometricTypeName(_availableBiometrics),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _biometricEnabled ? AppTheme.primaryGreen : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _biometricEnabled
                        ? 'Enabled - Tap to disable'
                        : 'Tap to enable biometric login',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _biometricEnabled
                    ? AppTheme.primaryGreen
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _biometricEnabled ? Icons.check_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
