import 'package:flutter/material.dart';
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

class _LoginScreenState extends State<LoginScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometric();
  }

  // Load saved credentials if Remember Me was enabled
  Future<void> _loadSavedCredentials() async {
    final rememberMe = await _secureStorage.read(key: 'remember_me');
    if (rememberMe == 'true') {
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');

      if (email != null && password != null) {
        setState(() {
          _emailController.text = email;
          _passwordController.text = password;
          _rememberMe = true;
        });
      }
    }
  }

  // Save credentials when Remember Me is checked
  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      await _secureStorage.write(key: 'remember_me', value: 'true');
      await _secureStorage.write(key: 'saved_email', value: _emailController.text.trim());
      await _secureStorage.write(key: 'saved_password', value: _passwordController.text);
    } else {
      await _secureStorage.delete(key: 'remember_me');
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
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
    super.dispose();
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Save credentials if Remember Me is checked
    await _saveCredentials();

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (error == null) {
        // Ask to enable biometric if available and not enabled
        if (_biometricAvailable && !_biometricEnabled) {
          _showEnableBiometricDialog();
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        _showSnackBar(error, AppTheme.error);
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
      _showSnackBar('Biometric authentication failed', AppTheme.error);
      return;
    }

    final credentials = await _biometricService.getCredentials();
    final email = credentials['email'];
    final password = credentials['password'];

    if (!mounted) return;

    if (email == null || password == null) {
      setState(() => _isLoading = false);
      _showSnackBar('No saved credentials found', AppTheme.error);
      return;
    }

    // Get authService before any async gaps
    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showSnackBar(error, AppTheme.error);
    }
  }

  void _showEnableBiometricDialog() {
    final navigatorContext = context; // Capture parent context
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enable Biometric Login?'),
        content: Text(
          'Would you like to use ${_biometricService.getBiometricTypeName(_availableBiometrics)} for faster login?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(navigatorContext, '/home');
            },
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () async {
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
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email first', AppTheme.warning);
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.resetPassword(_emailController.text.trim());

    if (mounted) {
      _showSnackBar(
        error ?? 'Password reset email sent!',
        error == null ? AppTheme.success : AppTheme.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.lightPurple,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 60,
                      color: AppTheme.primaryPurple,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing32),

                  // Welcome Text
                  Text(
                    'Welcome Back!',
                    style: AppTheme.heading1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'Sign in to continue',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textGrey),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppTheme.spacing32),

                  // Email Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppTheme.primaryPurple,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.cardWhite,
                      ),
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
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // Password Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppTheme.primaryPurple,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.textGrey,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.cardWhite,
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
                  ),

                  const SizedBox(height: AppTheme.spacing12),

                  // Remember Me & Forgot Password Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Remember Me Checkbox
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() => _rememberMe = value ?? false);
                              },
                              activeColor: AppTheme.primaryPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember Me',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      // Forgot Password
                      TextButton(
                        onPressed: _resetPassword,
                        child: Text(
                          'Forgot Password?',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // Login Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        elevation: 0,
                        shadowColor: AppTheme.primaryPurple.withOpacity(0.3),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : Text(
                        'Sign In',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Biometric Login Button - show when biometric is available and enabled
                  if (_biometricAvailable && _biometricEnabled) ...[
                    const SizedBox(height: AppTheme.spacing16),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginWithBiometric,
                        icon: Icon(
                          _availableBiometrics.contains(BiometricType.face)
                              ? Icons.face
                              : Icons.fingerprint,
                          color: AppTheme.primaryPurple,
                          size: 28,
                        ),
                        label: Text(
                          'Login with ${_biometricService.getBiometricTypeName(_availableBiometrics)}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                      ),
                    ),
                  ]
                  // Show hint about biometric availability if not enabled yet
                  else if (_biometricAvailable && !_biometricEnabled) ...[
                    const SizedBox(height: AppTheme.spacing12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _availableBiometrics.contains(BiometricType.face)
                              ? Icons.face
                              : Icons.fingerprint,
                          color: AppTheme.textGrey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_biometricService.getBiometricTypeName(_availableBiometrics)} login available after sign in',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppTheme.spacing24),

                  // Divider with OR
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppTheme.borderGrey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.textGrey),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppTheme.borderGrey)),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: Text(
                          'Sign Up',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
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
}