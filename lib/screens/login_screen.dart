import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _biometricService = BiometricService();
  final _secureStorage = const FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  late AnimationController _loginButtonController;
  late Animation<double> _loginButtonScale;
  late AnimationController _biometricButtonController;
  late Animation<double> _biometricButtonScale;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometric();

    _loginButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _loginButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _loginButtonController, curve: Curves.easeInOut),
    );

    _biometricButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _biometricButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _biometricButtonController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSavedCredentials() async {
    final rememberMe = await _secureStorage.read(key: 'remember_me');
    if (rememberMe == 'true') {
      final email = await _secureStorage.read(key: 'saved_email');

      if (email != null) {
        setState(() {
          _emailController.text = email;
          _rememberMe = true;
        });
      }
    }
    // Clean up any previously saved password
    await _secureStorage.delete(key: 'saved_password');
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      await _secureStorage.write(key: 'remember_me', value: 'true');
      await _secureStorage.write(
          key: 'saved_email', value: _emailController.text.trim());
    } else {
      await _secureStorage.delete(key: 'remember_me');
      await _secureStorage.delete(key: 'saved_email');
    }
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
    // Don't auto-trigger biometric - let user tap the button manually
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loginButtonController.dispose();
    _biometricButtonController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isLoading = true);

    await _saveCredentials();

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (error == null) {
        HapticFeedback.lightImpact();
        if (_biometricAvailable && !_biometricEnabled) {
          _showEnableBiometricDialog();
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        HapticFeedback.heavyImpact();
        _showSnackBar(error, AppTheme.error, isError: true);
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final authenticated = await _biometricService.authenticateWithBiometrics();

    if (!mounted) return;

    if (!authenticated) {
      setState(() => _isLoading = false);
      HapticFeedback.heavyImpact();
      _showSnackBar('Biometric authentication failed', AppTheme.error,
          isError: true);
      return;
    }

    final credentials = await _biometricService.getCredentials();
    final email = credentials['email'];
    final password = credentials['password'];

    if (!mounted) return;

    if (email == null || password == null) {
      setState(() => _isLoading = false);
      HapticFeedback.heavyImpact();
      _showSnackBar('No saved credentials found', AppTheme.error, isError: true);
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error == null) {
      HapticFeedback.lightImpact();
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      HapticFeedback.heavyImpact();
      _showSnackBar(error, AppTheme.error, isError: true);
    }
  }

  void _showEnableBiometricDialog() {
    final navigatorContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple,
                    AppTheme.primaryPurple.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _availableBiometrics.contains(BiometricType.face)
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Enable Biometric?'),
          ],
        ),
        content: Text(
          'Would you like to use ${_biometricService.getBiometricTypeName(_availableBiometrics)} for faster login?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(navigatorContext, '/home');
            },
            child: Text(
              'Not Now',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await _biometricService.saveCredentials(
                _emailController.text.trim(),
                _passwordController.text,
              );
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(navigatorContext, '/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _showSnackBar('Please enter your email first', AppTheme.warning,
          isError: true);
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final error =
        await authService.resetPassword(_emailController.text.trim());

    if (mounted) {
      if (error == null) {
        HapticFeedback.lightImpact();
        _showSnackBar('Password reset email sent!', AppTheme.success);
      } else {
        HapticFeedback.heavyImpact();
        _showSnackBar(error, AppTheme.error, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon with gradient
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryPurple,
                            AppTheme.primaryPurple.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textGrey.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Email Field
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password Field
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppTheme.textGrey,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Remember Me & Forgot Password Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _rememberMe = !_rememberMe);
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _rememberMe
                                    ? AppTheme.primaryPurple
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _rememberMe
                                      ? AppTheme.primaryPurple
                                      : AppTheme.borderGrey,
                                  width: 2,
                                ),
                              ),
                              child: _rememberMe
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Remember Me',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (_) => HapticFeedback.selectionClick(),
                        onTap: _resetPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Login Button with 3D touch
                  GestureDetector(
                    onTapDown: (_) {
                      HapticFeedback.selectionClick();
                      _loginButtonController.forward();
                    },
                    onTapUp: (_) => _loginButtonController.reverse(),
                    onTapCancel: () => _loginButtonController.reverse(),
                    onTap: _isLoading ? null : _login,
                    child: AnimatedBuilder(
                      animation: _loginButtonScale,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _loginButtonScale.value,
                          child: Container(
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
                                  color: AppTheme.primaryPurple
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Biometric Login Button
                  if (_biometricAvailable && _biometricEnabled) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTapDown: (_) {
                        HapticFeedback.selectionClick();
                        _biometricButtonController.forward();
                      },
                      onTapUp: (_) => _biometricButtonController.reverse(),
                      onTapCancel: () => _biometricButtonController.reverse(),
                      onTap: _isLoading ? null : _loginWithBiometric,
                      child: AnimatedBuilder(
                        animation: _biometricButtonScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _biometricButtonScale.value,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryPurple,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryPurple
                                        .withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _availableBiometrics
                                            .contains(BiometricType.face)
                                        ? Icons.face_rounded
                                        : Icons.fingerprint_rounded,
                                    color: AppTheme.primaryPurple,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Login with ${_biometricService.getBiometricTypeName(_availableBiometrics)}',
                                    style: const TextStyle(
                                      color: AppTheme.primaryPurple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (_biometricAvailable && !_biometricEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _availableBiometrics.contains(BiometricType.face)
                              ? Icons.face_rounded
                              : Icons.fingerprint_rounded,
                          color: AppTheme.textGrey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_biometricService.getBiometricTypeName(_availableBiometrics)} login available after sign in',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Divider with OR
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.borderGrey.withValues(alpha: 0.5),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: AppTheme.textGrey.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.borderGrey.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: AppTheme.textGrey.withValues(alpha: 0.8),
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (_) => HapticFeedback.selectionClick(),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
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
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onTap: () => HapticFeedback.selectionClick(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: AppTheme.primaryPurple),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          errorStyle: const TextStyle(
            color: AppTheme.error,
            fontSize: 12,
          ),
        ),
        validator: validator,
      ),
    );
  }
}
