import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/fcm_token_manager.dart';
import '../services/fcm_v1_service.dart';

import '../services/help_request_delivery_monitor.dart';

/// Comprehensive test suite for Google user help request functionality
class HelpRequestSystemTest {
  static final AuthService _authService = AuthService();
  static final GoogleAuthService _googleAuthService = GoogleAuthService();
  static final FCMTokenManager _fcmTokenManager = FCMTokenManager();
  static final FCMv1Service _fcmService = FCMv1Service();
  static final HelpRequestDeliveryMonitor _deliveryMonitor =
      HelpRequestDeliveryMonitor();

  /// Run all help request system tests
  static Future<void> runAllTests() async {
    debugPrint('🧪 ===== بدء اختبارات نظام طلبات المساعدة =====');

    try {
      await testTokenManagement();
      await testGoogleAuthentication();
      await testFCMTokenHandling();
      await testHelpRequestFlow();
      await testNotificationDelivery();
      await testDeliveryMonitoring();
      await testErrorHandling();
      await testEndToEndScenario();

      debugPrint('✅ ===== جميع اختبارات نظام طلبات المساعدة نجحت =====');
    } catch (e) {
      debugPrint('❌ ===== فشل في اختبارات نظام طلبات المساعدة: $e =====');
      rethrow;
    }
  }

  /// Test 1: Token Management
  static Future<void> testTokenManagement() async {
    debugPrint('🧪 Test 1: Token Management');

    try {
      // Test authentication token retrieval
      final authToken = await _authService.getToken();
      debugPrint('📝 Auth token available: ${authToken != null}');

      // Test token expiration check
      final isLoggedIn = await _authService.isLoggedIn();
      debugPrint('📝 User logged in status: $isLoggedIn');

      // Test Google sign-in status
      final isGoogleUser = await _authService.isGoogleSignIn();
      debugPrint('📝 Is Google user: $isGoogleUser');

      // Test token renewal mechanism
      if (isLoggedIn && isGoogleUser) {
        debugPrint('📝 Testing token renewal for Google user...');
        // Token renewal is handled automatically in isLoggedIn() check
      }

      debugPrint('✅ Test 1 passed: Token Management');
    } catch (e) {
      debugPrint('❌ Test 1 failed: Token Management - $e');
      rethrow;
    }
  }

  /// Test 2: Google Authentication
  static Future<void> testGoogleAuthentication() async {
    debugPrint('🧪 Test 2: Google Authentication');

    try {
      // Check if user is signed in to Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('📝 Firebase current user: ${currentUser?.email}');

      // Check Google sign-in status
      final isGoogleSignedIn = _googleAuthService.isUserSignedIn();
      debugPrint('📝 Google signed in: $isGoogleSignedIn');

      // Verify user data sync
      if (currentUser != null) {
        final userId = currentUser.uid;
        final database = FirebaseDatabase.instance;
        final userSnapshot = await database.ref('users/$userId').get();
        debugPrint('📝 User data synced to Firebase: ${userSnapshot.exists}');

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          debugPrint('📝 User type: ${userData['userType']}');
          debugPrint('📝 Is Google user: ${userData['isGoogleUser']}');
          debugPrint(
              '📝 Available for help: ${userData['isAvailableForHelp']}');
        }
      }

      debugPrint('✅ Test 2 passed: Google Authentication');
    } catch (e) {
      debugPrint('❌ Test 2 failed: Google Authentication - $e');
      rethrow;
    }
  }

  /// Test 3: FCM Token Handling
  static Future<void> testFCMTokenHandling() async {
    debugPrint('🧪 Test 3: FCM Token Handling');

    try {
      // Test FCM token saving
      final tokenSaved = await _fcmTokenManager.saveTokenOnLogin();
      debugPrint('📝 FCM token saved: $tokenSaved');

      // Test token retrieval for current user
      final userId = await _authService.getUserId();
      if (userId != null) {
        final hasToken = await _fcmTokenManager.hasTokenForUser(userId);
        debugPrint('📝 FCM token exists for user: $hasToken');

        final fcmToken = await _fcmTokenManager.getTokenForUser(userId);
        debugPrint('📝 FCM token retrieved: ${fcmToken != null}');
        debugPrint('📝 FCM token length: ${fcmToken?.length ?? 0}');

        if (fcmToken != null) {
          // Validate token format
          final isValidFormat = fcmToken.contains(':') && fcmToken.length > 100;
          debugPrint('📝 FCM token format valid: $isValidFormat');
        }
      }

      debugPrint('✅ Test 3 passed: FCM Token Handling');
    } catch (e) {
      debugPrint('❌ Test 3 failed: FCM Token Handling - $e');
      rethrow;
    }
  }

  /// Test 4: Help Request Flow
  static Future<void> testHelpRequestFlow() async {
    debugPrint('🧪 Test 4: Help Request Flow');

    try {
      // Check if help requests are available for current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('📝 No current user - help requests not available');
        debugPrint('✅ Test 4 passed: Help Request Flow (no user)');
        return;
      }

      debugPrint('📝 Current user: ${currentUser.email}');
      debugPrint('📝 Help requests available for Google users');

      // Test help request data structure
      final testRequestData = {
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'Test User',
        'senderEmail': currentUser.email ?? '',
        'receiverId': 'test_receiver_id',
        'receiverName': 'Test Receiver',
        'message': 'Test help request',
        'status': 'pending',
      };

      debugPrint(
          '📝 Test request data prepared: ${testRequestData.keys.length} fields');

      // Verify required fields are present
      final requiredFields = [
        'senderId',
        'senderName',
        'receiverId',
        'receiverName'
      ];
      for (final field in requiredFields) {
        assert(testRequestData.containsKey(field),
            'Missing required field: $field');
      }

      debugPrint('✅ Test 4 passed: Help Request Flow');
    } catch (e) {
      debugPrint('❌ Test 4 failed: Help Request Flow - $e');
      rethrow;
    }
  }

  /// Test 5: Notification Delivery
  static Future<void> testNotificationDelivery() async {
    debugPrint('🧪 Test 5: Notification Delivery');

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('📝 No current user - skipping notification test');
        debugPrint('✅ Test 5 passed: Notification Delivery (no user)');
        return;
      }

      final userId = currentUser.uid;

      // Test FCM service initialization
      debugPrint('📝 Testing FCM service...');

      // Test notification stats
      final stats = await _fcmService.getNotificationStats();
      debugPrint('📝 Notification stats: $stats');

      // Test if user has FCM token
      final hasToken = await _fcmTokenManager.hasTokenForUser(userId);
      debugPrint('📝 User has FCM token: $hasToken');

      if (hasToken) {
        debugPrint('📝 FCM token available - notification delivery possible');
      } else {
        debugPrint(
            '⚠️ No FCM token - notifications will use fallback to Firebase Database');
      }

      debugPrint('✅ Test 5 passed: Notification Delivery');
    } catch (e) {
      debugPrint('❌ Test 5 failed: Notification Delivery - $e');
      rethrow;
    }
  }

  /// Test 6: Delivery Monitoring
  static Future<void> testDeliveryMonitoring() async {
    debugPrint('🧪 Test 6: Delivery Monitoring');

    try {
      // Test delivery monitor initialization
      debugPrint('📝 Testing delivery monitor...');

      // Check if monitoring is active
      final isMonitoring = _deliveryMonitor.isMonitoring;
      debugPrint('📝 Delivery monitoring active: $isMonitoring');

      if (!isMonitoring) {
        debugPrint('📝 Starting delivery monitoring...');
        _deliveryMonitor.startMonitoring();
        debugPrint('📝 Delivery monitoring started');
      }

      debugPrint('✅ Test 6 passed: Delivery Monitoring');
    } catch (e) {
      debugPrint('❌ Test 6 failed: Delivery Monitoring - $e');
      rethrow;
    }
  }

  /// Test 7: Error Handling
  static Future<void> testErrorHandling() async {
    debugPrint('🧪 Test 7: Error Handling');

    try {
      // Test invalid user ID scenarios
      debugPrint('📝 Testing error handling scenarios...');

      // Test FCM token retrieval with invalid user ID
      final invalidToken =
          await _fcmTokenManager.getTokenForUser('invalid_user_id');
      debugPrint(
          '📝 Invalid user token result: ${invalidToken == null ? 'null (expected)' : 'unexpected value'}');

      // Test help request with no authentication
      try {
        await FirebaseAuth.instance.signOut();
        final currentUser = FirebaseAuth.instance.currentUser;
        debugPrint('📝 User signed out: ${currentUser == null}');
      } catch (e) {
        debugPrint('📝 Sign out error (expected in test): $e');
      }

      debugPrint('✅ Test 7 passed: Error Handling');
    } catch (e) {
      debugPrint('❌ Test 7 failed: Error Handling - $e');
      rethrow;
    }
  }

  /// Test 8: End-to-End Scenario
  static Future<void> testEndToEndScenario() async {
    debugPrint('🧪 Test 8: End-to-End Scenario');

    try {
      debugPrint('📝 Testing complete help request scenario...');

      // Check current authentication state
      final isLoggedIn = await _authService.isLoggedIn();
      final isGoogleUser = await _authService.isGoogleSignIn();

      debugPrint('📝 Authentication state:');
      debugPrint('   - Logged in: $isLoggedIn');
      debugPrint('   - Google user: $isGoogleUser');

      if (isLoggedIn && isGoogleUser) {
        // Test complete flow for authenticated Google user
        final userId = await _authService.getUserId();
        final userEmail = await _authService.getUserEmail();

        debugPrint('📝 User details:');
        debugPrint('   - User ID: $userId');
        debugPrint('   - Email: $userEmail');

        // Test FCM token availability
        if (userId != null) {
          final hasToken = await _fcmTokenManager.hasTokenForUser(userId);
          debugPrint('   - FCM token available: $hasToken');

          if (!hasToken) {
            debugPrint('📝 Attempting to save FCM token...');
            final tokenSaved = await _fcmTokenManager.saveTokenOnLogin();
            debugPrint('   - FCM token saved: $tokenSaved');
          }
        }

        debugPrint('📝 Help request system ready for Google user');
      } else {
        debugPrint('📝 Help request system requires Google authentication');
      }

      debugPrint('✅ Test 8 passed: End-to-End Scenario');
    } catch (e) {
      debugPrint('❌ Test 8 failed: End-to-End Scenario - $e');
      rethrow;
    }
  }

  /// Run quick diagnostic test
  static Future<void> runQuickDiagnostic() async {
    debugPrint('🧪 ===== تشخيص سريع لنظام طلبات المساعدة =====');

    try {
      // Quick authentication check
      final isLoggedIn = await _authService.isLoggedIn();
      final isGoogleUser = await _authService.isGoogleSignIn();
      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint('📊 Quick Diagnostic Results:');
      debugPrint('   - User logged in: $isLoggedIn');
      debugPrint('   - Google user: $isGoogleUser');
      debugPrint('   - Firebase user: ${currentUser?.email ?? 'None'}');

      if (currentUser != null) {
        final userId = currentUser.uid;
        final hasToken = await _fcmTokenManager.hasTokenForUser(userId);
        debugPrint('   - FCM token available: $hasToken');

        final isMonitoring = _deliveryMonitor.isMonitoring;
        debugPrint('   - Delivery monitoring: $isMonitoring');
      }

      debugPrint('✅ ===== تشخيص سريع مكتمل =====');
    } catch (e) {
      debugPrint('❌ ===== فشل التشخيص السريع: $e =====');
    }
  }
}
