import 'dart:io';
import 'package:flutter/material.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final _biometricService = BiometricService();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkBiometric();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          _showSnackBar('Profile picture updated!', AppTheme.success);
          _loadProfile();
        } else {
          _showSnackBar(error, AppTheme.error);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', AppTheme.error);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Photo Source',
              style: AppTheme.heading3,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: AppTheme.primaryPurple),
              ),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: AppTheme.primaryGreen),
              ),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name', AppTheme.warning);
      return;
    }

    final profileService = Provider.of<ProfileService>(context, listen: false);
    final error = await profileService.updateProfileName(_nameController.text.trim());

    if (mounted) {
      if (error == null) {
        _showSnackBar('Profile updated!', AppTheme.success);
        _loadProfile();
      } else {
        _showSnackBar(error, AppTheme.error);
      }
    }
  }

  void _showPasswordDialogForBiometric() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verify Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              passwordController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final email = authService.currentUser?.email ?? '';

              if (email.isEmpty) {
                Navigator.pop(context);
                _showSnackBar('No email found', AppTheme.error);
                passwordController.dispose();
                return;
              }

              // Try to sign in with password to verify
              final error = await authService.signInWithEmail(
                email: email,
                password: passwordController.text,
              );

              if (error == null) {
                await _biometricService.saveCredentials(
                  email,
                  passwordController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _checkBiometric();
                  _showSnackBar('Biometric login enabled!', AppTheme.success);
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Incorrect password', AppTheme.error);
                }
              }
              passwordController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
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
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final profileService = Provider.of<ProfileService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            children: [
              // Header
              Row(
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
                  Text(
                    'My Profile',
                    style: AppTheme.heading2,
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing32),

              // Profile Picture
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: AppTheme.lightPurple,
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
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing32),

              // Profile Info Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing20),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: AppTheme.heading3,
                    ),
                    const SizedBox(height: AppTheme.spacing20),

                    // Name Field
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryPurple),
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // Email Field (Read-only)
                    TextField(
                      controller: TextEditingController(text: _profileData?['email'] ?? ''),
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textGrey),
                        filled: true,
                        fillColor: AppTheme.borderGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing24),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: profileService.isLoading ? null : _updateName,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        child: profileService.isLoading
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : Text(
                          'Update Profile',
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing20),

              // Biometric Settings Card
              if (_biometricAvailable)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security',
                        style: AppTheme.heading3,
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.lightPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _availableBiometrics.contains(BiometricType.face)
                                ? Icons.face
                                : Icons.fingerprint,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                        title: Text(
                          _biometricService.getBiometricTypeName(_availableBiometrics),
                          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _biometricEnabled
                              ? 'Enabled - Login faster with biometrics'
                              : 'Enable biometric authentication',
                          style: AppTheme.bodySmall,
                        ),
                        value: _biometricEnabled,
                        activeColor: AppTheme.primaryPurple,
                        onChanged: (value) async {
                          if (value) {
                            // Enable biometric
                            final authenticated = await _biometricService.authenticateWithBiometrics();
                            if (authenticated && mounted) {
                              _showPasswordDialogForBiometric();
                            } else {
                              _showSnackBar('Authentication failed', AppTheme.error);
                            }
                          } else {
                            // Disable biometric
                            await _biometricService.disableBiometric();
                            _checkBiometric();
                            _showSnackBar('Biometric login disabled', AppTheme.success);
                          }
                        },
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppTheme.spacing20),

              // Logout Card
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightPink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout, color: AppTheme.error),
                  ),
                  title: const Text('Logout'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () async {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await authService.signOut();
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(context, '/login');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.white),
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