import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Check if biometric is available
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric authentication error: ${e.code} - ${e.message}');

      // Handle specific error codes
      if (e.code == 'NotAvailable') {
        print('Biometric not available');
      } else if (e.code == 'NotEnrolled') {
        print('No biometrics enrolled');
      } else if (e.code == 'LockedOut') {
        print('Too many failed attempts');
      } else if (e.code == 'PermanentlyLockedOut') {
        print('Biometric permanently locked');
      }

      return false;
    } catch (e) {
      print('Unexpected biometric error: $e');
      return false;
    }
  }

  // Save credentials securely
  Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: 'email', value: email);
    await _secureStorage.write(key: 'password', value: password);
    await _secureStorage.write(key: 'biometric_enabled', value: 'true');
  }

  // Get saved credentials
  Future<Map<String, String?>> getCredentials() async {
    final email = await _secureStorage.read(key: 'email');
    final password = await _secureStorage.read(key: 'password');
    return {'email': email, 'password': password};
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: 'biometric_enabled');
    return enabled == 'true';
  }

  // Enable biometric
  Future<void> enableBiometric() async {
    await _secureStorage.write(key: 'biometric_enabled', value: 'true');
  }

  // Disable biometric
  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: 'email');
    await _secureStorage.delete(key: 'password');
    await _secureStorage.delete(key: 'biometric_enabled');
  }

  // Get biometric type name
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face Recognition';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }
}