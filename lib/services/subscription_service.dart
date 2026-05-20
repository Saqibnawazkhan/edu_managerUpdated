import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Subscription status enum
enum SubscriptionStatus {
  active,
  expiringSoon, // 3 days before expiry
  expired,
  none,
}

/// Subscription model
class Subscription {
  final String orderId;
  final String userId;
  final String package; // Monthly, Yearly, Lifetime
  final int amount;
  final DateTime startDate;
  final DateTime? expiryDate; // null for Lifetime
  final String status; // pending, active, expired
  final String paymentMethod;
  final String transactionId;

  Subscription({
    required this.orderId,
    required this.userId,
    required this.package,
    required this.amount,
    required this.startDate,
    this.expiryDate,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
  });

  factory Subscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Subscription(
      orderId: doc.id,
      userId: data['userId'] ?? '',
      package: data['package'] ?? '',
      amount: data['amount'] ?? 0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'pending',
      paymentMethod: data['paymentMethod'] ?? '',
      transactionId: data['transactionId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'package': package,
      'amount': amount,
      'startDate': Timestamp.fromDate(startDate),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
    };
  }

  bool get isLifetime => package == 'Lifetime' || package == 'Permanent';

  bool get isExpired {
    if (isLifetime) return false;
    if (expiryDate == null) return true;
    return DateTime.now().isAfter(expiryDate!);
  }

  int get daysRemaining {
    if (isLifetime) return -1; // -1 means unlimited
    if (expiryDate == null) return 0;
    final remaining = expiryDate!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isExpiringSoon {
    if (isLifetime) return false;
    return daysRemaining > 0 && daysRemaining <= 3;
  }
}

/// Service to manage user subscriptions
class SubscriptionService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Subscription? _currentSubscription;
  SubscriptionStatus _status = SubscriptionStatus.none;
  bool _isLoading = false;

  Subscription? get currentSubscription => _currentSubscription;
  SubscriptionStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get hasActiveSubscription => _status == SubscriptionStatus.active || _status == SubscriptionStatus.expiringSoon;

  /// Load current user's subscription
  Future<void> loadSubscription() async {
    final userId = _auth.currentUser?.uid;
    final userEmail = _auth.currentUser?.email;

    if (userId == null) {
      _currentSubscription = null;
      _status = SubscriptionStatus.none;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // First, try to find subscription by userId
      var snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('startDate', descending: true)
          .limit(1)
          .get();

      // If not found by userId, try by userEmail (fallback for subscriptions created before userId was properly set)
      if (snapshot.docs.isEmpty && userEmail != null) {
        snapshot = await _firestore
            .collection('subscriptions')
            .where('userEmail', isEqualTo: userEmail)
            .where('status', isEqualTo: 'active')
            .orderBy('startDate', descending: true)
            .limit(1)
            .get();

        // If found by email, update the subscription with the correct userId
        if (snapshot.docs.isNotEmpty) {
          await _firestore.collection('subscriptions').doc(snapshot.docs.first.id).update({
            'userId': userId,
          });
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _currentSubscription = Subscription.fromFirestore(snapshot.docs.first);

        // Update status based on subscription
        if (_currentSubscription!.isExpired) {
          _status = SubscriptionStatus.expired;
          // Mark as expired in Firestore
          await _markSubscriptionExpired(snapshot.docs.first.id);
        } else if (_currentSubscription!.isExpiringSoon) {
          _status = SubscriptionStatus.expiringSoon;
        } else {
          _status = SubscriptionStatus.active;
        }
      } else {
        _currentSubscription = null;
        _status = SubscriptionStatus.none;
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      _currentSubscription = null;
      _status = SubscriptionStatus.none;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mark subscription as expired in Firestore
  Future<void> _markSubscriptionExpired(String subscriptionId) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking subscription expired: $e');
    }
  }

  /// Admin: Activate subscription for a user after payment verification
  /// Call this when you verify a payment request
  Future<String?> activateSubscription({
    required String userId,
    required String userEmail,
    required String package,
    required int amount,
    required String paymentMethod,
    required String transactionId,
  }) async {
    try {
      // Calculate expiry date based on package
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
          expiryDate = null; // No expiry
          break;
      }

      // Create subscription record
      await _firestore.collection('subscriptions').add({
        'userId': userId,
        'userEmail': userEmail,
        'package': package,
        'amount': amount,
        'startDate': FieldValue.serverTimestamp(),
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'status': 'active',
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document with subscription info
      await _firestore.collection('users').doc(userId).set({
        'subscriptionPackage': package,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      }, SetOptions(merge: true));

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  /// Check if user should see expiry warning
  String? getExpiryWarningMessage() {
    if (_currentSubscription == null) return null;

    if (_status == SubscriptionStatus.expired) {
      return 'Your subscription has expired. Please renew to continue using the app.';
    }

    if (_status == SubscriptionStatus.expiringSoon) {
      final days = _currentSubscription!.daysRemaining;
      if (days == 0) {
        return 'Your subscription expires today! Renew now to avoid interruption.';
      } else if (days == 1) {
        return 'Your subscription expires tomorrow! Renew now to avoid interruption.';
      } else {
        return 'Your subscription expires in $days days. Renew now to avoid interruption.';
      }
    }

    return null;
  }

  /// Get subscription info text for display
  String getSubscriptionInfoText() {
    if (_currentSubscription == null) {
      return 'No active subscription';
    }

    final sub = _currentSubscription!;

    if (sub.isLifetime) {
      return 'Lifetime subscription - Never expires';
    }

    if (sub.isExpired) {
      return 'Subscription expired';
    }

    final days = sub.daysRemaining;
    if (days == 0) {
      return '${sub.package} - Expires today';
    } else if (days == 1) {
      return '${sub.package} - Expires tomorrow';
    } else {
      return '${sub.package} - ${days} days remaining';
    }
  }

  /// Clear subscription (on logout)
  void clearSubscription() {
    _currentSubscription = null;
    _status = SubscriptionStatus.none;
    notifyListeners();
  }
}
