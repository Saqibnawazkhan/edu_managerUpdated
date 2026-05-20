import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

/// Device Service - Manages single device login enforcement
class DeviceService extends ChangeNotifier {
  static const String _deviceIdKey = 'device_unique_id';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _deviceId;
  StreamSubscription<DocumentSnapshot>? _deviceListener;

  // Callback when device mismatch detected (logged in from another device)
  VoidCallback? onDeviceMismatch;

  String? get deviceId => _deviceId;

  /// Initialize and get/create device ID
  Future<String> getOrCreateDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString(_deviceIdKey);

    if (storedId == null) {
      // Generate new unique device ID
      storedId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, storedId);
    }

    _deviceId = storedId;
    return _deviceId!;
  }

  /// Save device ID to Firestore on login
  Future<void> saveDeviceToFirestore(String userId) async {
    final deviceId = await getOrCreateDeviceId();

    await _firestore.collection('users').doc(userId).set({
      'activeDeviceId': deviceId,
      'lastDeviceLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Start listening for device changes
  void startDeviceListener(String userId) {
    _deviceListener?.cancel();

    _deviceListener = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final activeDeviceId = data['activeDeviceId'] as String?;
      final currentDeviceId = await getOrCreateDeviceId();

      // If device ID doesn't match, another device logged in
      if (activeDeviceId != null && activeDeviceId != currentDeviceId) {
        debugPrint('Device mismatch detected. Current: $currentDeviceId, Active: $activeDeviceId');
        onDeviceMismatch?.call();
      }
    });
  }

  /// Stop listening for device changes
  void stopDeviceListener() {
    _deviceListener?.cancel();
    _deviceListener = null;
  }

  /// Check if current device matches the active device in Firestore
  Future<bool> isCurrentDeviceActive(String userId) async {
    final deviceId = await getOrCreateDeviceId();

    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return true; // No data yet, allow

    final data = doc.data();
    if (data == null) return true;

    final activeDeviceId = data['activeDeviceId'] as String?;
    if (activeDeviceId == null) return true; // No device registered yet

    return activeDeviceId == deviceId;
  }

  @override
  void dispose() {
    _deviceListener?.cancel();
    super.dispose();
  }
}
