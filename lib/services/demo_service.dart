import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Demo Configuration
class DemoConfig {
  static const String demoEmail = 'demo@edumanager.com';
  static const String demoPassword = 'demo123456';
  static const int demoDurationMinutes = 5; // 5 minutes demo
}

/// Demo Service - Manages demo mode with time-based restrictions
class DemoService extends ChangeNotifier {
  static const String _demoStartTimeKey = 'demo_start_time';
  static const String _demoUsedKey = 'demo_used';

  bool _isDemoUser = false;
  DateTime? _demoStartTime;
  Timer? _demoTimer;
  int _remainingSeconds = DemoConfig.demoDurationMinutes * 60;
  bool _demoExpired = false;

  // Callback when demo time expires
  VoidCallback? onDemoTimeExpired;

  bool get isDemoUser => _isDemoUser && _isCurrentUserDemo();
  bool get demoExpired => _demoExpired;
  int get remainingSeconds => _remainingSeconds;

  String get remainingTimeFormatted {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if the currently logged in user is the demo user
  bool _isCurrentUserDemo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.email?.toLowerCase() == DemoConfig.demoEmail.toLowerCase();
  }

  /// Check if demo credentials
  bool isDemoCredentials(String email, String password) {
    return email.toLowerCase() == DemoConfig.demoEmail.toLowerCase() &&
           password == DemoConfig.demoPassword;
  }

  /// Check if this device has already used demo (5 mins expired)
  Future<bool> isDemoLimitReachedForDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final demoUsed = prefs.getBool(_demoUsedKey) ?? false;

    if (!demoUsed) return false;

    // Check if there's remaining time
    final startTimeMs = prefs.getInt(_demoStartTimeKey);
    if (startTimeMs == null) return true;

    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
    final elapsed = DateTime.now().difference(startTime);
    final totalSeconds = DemoConfig.demoDurationMinutes * 60;

    return elapsed.inSeconds >= totalSeconds;
  }

  /// Start demo session
  Future<void> startDemoSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if resuming an existing session
    final existingStartTime = prefs.getInt(_demoStartTimeKey);

    if (existingStartTime != null) {
      // Resume existing session
      _demoStartTime = DateTime.fromMillisecondsSinceEpoch(existingStartTime);
      final elapsed = DateTime.now().difference(_demoStartTime!);
      final totalSeconds = DemoConfig.demoDurationMinutes * 60;
      _remainingSeconds = totalSeconds - elapsed.inSeconds;

      if (_remainingSeconds <= 0) {
        _remainingSeconds = 0;
        _demoExpired = true;
        _isDemoUser = true;
        notifyListeners();
        return;
      }
    } else {
      // New session
      _demoStartTime = DateTime.now();
      await prefs.setInt(_demoStartTimeKey, _demoStartTime!.millisecondsSinceEpoch);
      await prefs.setBool(_demoUsedKey, true);
      _remainingSeconds = DemoConfig.demoDurationMinutes * 60;
    }

    _isDemoUser = true;
    _demoExpired = false;
    _startTimer();
    notifyListeners();
  }

  /// Start the countdown timer
  void _startTimer() {
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();

        if (_remainingSeconds <= 0) {
          _demoExpired = true;
          timer.cancel();
          onDemoTimeExpired?.call();
          notifyListeners();
        }
      }
    });
  }

  /// Check if user can perform actions (not expired)
  bool canPerformAction() {
    if (!_isDemoUser) return true;
    return !_demoExpired && _remainingSeconds > 0;
  }

  /// Clear demo session (on logout)
  void clearDemoSession() {
    _demoTimer?.cancel();
    _isDemoUser = false;
    _demoStartTime = null;
    _demoExpired = false;
    _remainingSeconds = DemoConfig.demoDurationMinutes * 60;
    notifyListeners();
  }

  /// Get message for restricted action
  String getRestrictionMessage() {
    return 'Demo time has expired. Please register to continue using Edu Manager.';
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    super.dispose();
  }
}
