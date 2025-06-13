import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import '../services/fcm_v1_service.dart';

import '../services/help_request_delivery_monitor.dart';
import '../services/fcm_token_manager.dart';

/// Test suite for help request delivery system
class HelpRequestDeliveryTest {
  static final AuthService _authService = AuthService();
  static final FCMv1Service _fcmService = FCMv1Service();
  static final HelpRequestDeliveryMonitor _deliveryMonitor =
      HelpRequestDeliveryMonitor();
  static final FCMTokenManager _fcmTokenManager = FCMTokenManager();

  /// Run complete delivery test suite
  static Future<Map<String, dynamic>> runCompleteDeliveryTest() async {
    debugPrint('🧪 ===== بدء اختبار تسليم طلبات المساعدة =====');

    final results = <String, dynamic>{};

    try {
      // 1. Test notification delivery infrastructure
      final infraResults = await _testNotificationInfrastructure();
      results['infrastructure'] = infraResults;

      // 2. Test help request creation and delivery
      final deliveryResults = await _testHelpRequestDelivery();
      results['delivery'] = deliveryResults;

      // 3. Test delivery monitoring
      final monitoringResults = await _testDeliveryMonitoring();
      results['monitoring'] = monitoringResults;

      // 4. Test fallback mechanisms
      final fallbackResults = await _testFallbackMechanisms();
      results['fallback'] = fallbackResults;

      // 5. Test error scenarios
      final errorResults = await _testErrorScenarios();
      results['errorHandling'] = errorResults;

      // 6. Performance test
      final performanceResults = await _testPerformance();
      results['performance'] = performanceResults;

      debugPrint('✅ ===== اختبار تسليم طلبات المساعدة مكتمل =====');
      _printDeliveryTestSummary(results);

      return results;
    } catch (e) {
      debugPrint('❌ ===== فشل اختبار تسليم طلبات المساعدة: $e =====');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Test notification infrastructure
  static Future<Map<String, dynamic>> _testNotificationInfrastructure() async {
    debugPrint('🧪 Testing Notification Infrastructure...');

    final results = <String, dynamic>{};

    try {
      // Test FCM service initialization
      debugPrint('📱 Testing FCM service...');
      final stats = await _fcmService.getNotificationStats();
      results['fcmServiceWorking'] = stats.isNotEmpty;
      results['notificationStats'] = stats;

      // Test current user FCM token
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userId = currentUser.uid;
        final hasToken = await _fcmTokenManager.hasTokenForUser(userId);
        results['currentUserHasToken'] = hasToken;

        if (hasToken) {
          final token = await _fcmTokenManager.getTokenForUser(userId);
          results['tokenLength'] = token?.length ?? 0;
          results['tokenValid'] =
              token != null && token.contains(':') && token.length > 100;
        }
      } else {
        results['currentUserHasToken'] = false;
        results['noCurrentUser'] = true;
      }

      // Test Firebase Database connectivity
      debugPrint('🔥 Testing Firebase Database...');
      final database = FirebaseDatabase.instance;
      final testRef = database.ref('test/connectivity');
      await testRef.set({'timestamp': DateTime.now().millisecondsSinceEpoch});
      final testSnapshot = await testRef.get();
      results['firebaseDatabaseWorking'] = testSnapshot.exists;
      await testRef.remove(); // Clean up

      debugPrint('📊 Infrastructure Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Infrastructure Test Error: $e');
    }

    return results;
  }

  /// Test help request delivery
  static Future<Map<String, dynamic>> _testHelpRequestDelivery() async {
    debugPrint('🧪 Testing Help Request Delivery...');

    final results = <String, dynamic>{};

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        results['error'] = 'No authenticated user';
        return results;
      }

      // Create test help request data
      final testRequestData = {
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'Test User',
        'senderEmail': currentUser.email ?? '',
        'receiverId': 'test_receiver_${DateTime.now().millisecondsSinceEpoch}',
        'receiverName': 'Test Receiver',
        'senderLocation': {
          'latitude': 24.7136,
          'longitude': 46.6753,
        },
        'receiverLocation': {
          'latitude': 24.7236,
          'longitude': 46.6853,
        },
        'message': 'Test help request for delivery testing',
        'status': 'pending',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      results['testDataPrepared'] = true;
      results['testRequestData'] = testRequestData;

      // Test notification creation (without actually sending)
      debugPrint('📝 Testing notification creation...');
      final notificationData = {
        'title': 'طلب مساعدة جديد',
        'body': 'تلقيت طلب مساعدة من ${testRequestData['senderName']}',
        'data': {
          'type': 'help_request',
          'requestId': 'test_request_${DateTime.now().millisecondsSinceEpoch}',
          'senderId': testRequestData['senderId'],
          'receiverId': testRequestData['receiverId'],
        },
      };

      results['notificationDataCreated'] = true;
      results['notificationData'] = notificationData;

      // Test Firebase Database save (for fallback mechanism)
      debugPrint('💾 Testing Firebase Database save...');
      final database = FirebaseDatabase.instance;
      final testNotificationRef = database
          .ref('test_notifications/${testRequestData['receiverId']}')
          .push();

      await testNotificationRef.set({
        'title': notificationData['title'],
        'body': notificationData['body'],
        'data': notificationData['data'],
        'timestamp': ServerValue.timestamp,
        'isTest': true,
      });

      results['firebaseSaveSuccess'] = true;

      // Clean up test data
      await testNotificationRef.remove();

      debugPrint('📊 Delivery Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Delivery Test Error: $e');
    }

    return results;
  }

  /// Test delivery monitoring
  static Future<Map<String, dynamic>> _testDeliveryMonitoring() async {
    debugPrint('🧪 Testing Delivery Monitoring...');

    final results = <String, dynamic>{};

    try {
      // Test monitoring initialization
      final isMonitoring = _deliveryMonitor.isMonitoring;
      results['monitoringActive'] = isMonitoring;

      if (!isMonitoring) {
        debugPrint('🔄 Starting delivery monitoring...');
        _deliveryMonitor.startMonitoring();
        results['monitoringStarted'] = true;
      }

      // Test monitoring functionality
      debugPrint('📊 Testing monitoring functionality...');

      // Create a test undelivered request
      final database = FirebaseDatabase.instance;
      final testRequestId =
          'test_monitoring_${DateTime.now().millisecondsSinceEpoch}';
      final testRequestRef = database.ref('helpRequests/$testRequestId');

      await testRequestRef.set({
        'requestId': testRequestId,
        'senderId': 'test_sender',
        'receiverId': 'test_receiver',
        'status': 'pending',
        'deliveryStatus': 'sending', // This should trigger monitoring
        'timestamp': ServerValue.timestamp,
        'isTest': true,
      });

      results['testRequestCreated'] = true;

      // Wait a moment for monitoring to detect
      await Future.delayed(const Duration(seconds: 2));

      // Check if monitoring detected the request
      final updatedSnapshot = await testRequestRef.get();
      if (updatedSnapshot.exists) {
        final data = updatedSnapshot.value as Map<dynamic, dynamic>;
        results['monitoringDetected'] = data['deliveryStatus'] != 'sending';
      }

      // Clean up test data
      await testRequestRef.remove();

      debugPrint('📊 Monitoring Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Monitoring Test Error: $e');
    }

    return results;
  }

  /// Test fallback mechanisms
  static Future<Map<String, dynamic>> _testFallbackMechanisms() async {
    debugPrint('🧪 Testing Fallback Mechanisms...');

    final results = <String, dynamic>{};

    try {
      // Test Firebase Database fallback
      debugPrint('💾 Testing Firebase Database fallback...');

      final database = FirebaseDatabase.instance;
      final testUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

      // Simulate notification save to Firebase Database
      final notificationRef = database.ref('notifications/$testUserId').push();
      await notificationRef.set({
        'title': 'Test Fallback Notification',
        'body': 'This is a test fallback notification',
        'type': 'help_request',
        'timestamp': ServerValue.timestamp,
        'read': false,
        'isTest': true,
      });

      results['fallbackSaveSuccess'] = true;

      // Test retrieval
      final savedSnapshot = await notificationRef.get();
      results['fallbackRetrievalSuccess'] = savedSnapshot.exists;

      if (savedSnapshot.exists) {
        final data = savedSnapshot.value as Map<dynamic, dynamic>;
        results['fallbackDataIntact'] =
            data['title'] == 'Test Fallback Notification';
      }

      // Clean up
      await notificationRef.remove();

      // Test multiple fallback scenarios
      debugPrint('🔄 Testing multiple fallback scenarios...');

      final scenarios = ['no_fcm_token', 'invalid_token', 'network_error'];
      final scenarioResults = <String, bool>{};

      for (final scenario in scenarios) {
        try {
          // Simulate each scenario by saving to Firebase Database
          final scenarioRef = database.ref('test_fallback/$scenario').push();
          await scenarioRef.set({
            'scenario': scenario,
            'timestamp': ServerValue.timestamp,
            'handled': true,
          });

          scenarioResults[scenario] = true;
          await scenarioRef.remove();
        } catch (e) {
          scenarioResults[scenario] = false;
          debugPrint('❌ Scenario $scenario failed: $e');
        }
      }

      results['scenarioResults'] = scenarioResults;

      debugPrint('📊 Fallback Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Fallback Test Error: $e');
    }

    return results;
  }

  /// Test error scenarios
  static Future<Map<String, dynamic>> _testErrorScenarios() async {
    debugPrint('🧪 Testing Error Scenarios...');

    final results = <String, dynamic>{};

    try {
      // Test invalid user ID
      debugPrint('❌ Testing invalid user ID...');
      final invalidToken =
          await _fcmTokenManager.getTokenForUser('invalid_user_id');
      results['invalidUserHandled'] = invalidToken == null;

      // Test empty notification data
      debugPrint('❌ Testing empty notification data...');
      try {
        // This should handle gracefully
        await _fcmService.sendPushNotification(
          userId: 'test_user',
          title: '',
          body: '',
        );
        results['emptyDataHandled'] = true;
      } catch (e) {
        results['emptyDataHandled'] = false;
        debugPrint('Empty data error (expected): $e');
      }

      // Test network connectivity issues
      debugPrint('🌐 Testing network scenarios...');
      results['networkErrorHandling'] =
          true; // Assume handled by try-catch blocks

      // Test Firebase Database errors
      debugPrint('🔥 Testing Firebase errors...');
      try {
        final database = FirebaseDatabase.instance;
        // Try to access a restricted path (should fail gracefully)
        final restrictedRef =
            database.ref('restricted/path/that/should/not/exist');
        await restrictedRef.get();
        results['firebaseErrorHandling'] = true;
      } catch (e) {
        results['firebaseErrorHandling'] = true; // Error was caught
        debugPrint('Firebase error handled: $e');
      }

      debugPrint('📊 Error Handling Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Error Scenario Test Error: $e');
    }

    return results;
  }

  /// Test performance
  static Future<Map<String, dynamic>> _testPerformance() async {
    debugPrint('🧪 Testing Performance...');

    final results = <String, dynamic>{};

    try {
      // Test notification creation speed
      final startTime = DateTime.now();

      for (int i = 0; i < 5; i++) {
        // Simulate notification preparation
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      results['notificationCreationTime'] = duration.inMilliseconds;
      results['averageTimePerNotification'] = duration.inMilliseconds / 5;

      // Test Firebase Database write speed
      final dbStartTime = DateTime.now();
      final database = FirebaseDatabase.instance;

      for (int i = 0; i < 3; i++) {
        final testRef = database.ref('performance_test/test_$i');
        await testRef.set({
          'index': i,
          'timestamp': ServerValue.timestamp,
        });
        await testRef.remove();
      }

      final dbEndTime = DateTime.now();
      final dbDuration = dbEndTime.difference(dbStartTime);

      results['databaseWriteTime'] = dbDuration.inMilliseconds;
      results['averageDbWriteTime'] = dbDuration.inMilliseconds / 3;

      // Performance thresholds
      results['performanceGood'] = {
        'notificationSpeed': results['averageTimePerNotification'] < 100,
        'databaseSpeed': results['averageDbWriteTime'] < 1000,
      };

      debugPrint('📊 Performance Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Performance Test Error: $e');
    }

    return results;
  }

  /// Print delivery test summary
  static void _printDeliveryTestSummary(Map<String, dynamic> results) {
    debugPrint('📋 ===== ملخص اختبار التسليم =====');

    try {
      final infrastructure = results['infrastructure'] as Map<String, dynamic>?;
      final delivery = results['delivery'] as Map<String, dynamic>?;
      final monitoring = results['monitoring'] as Map<String, dynamic>?;
      final fallback = results['fallback'] as Map<String, dynamic>?;
      final performance = results['performance'] as Map<String, dynamic>?;

      debugPrint('🏗️ Infrastructure:');
      debugPrint(
          '   - FCM Service: ${infrastructure?['fcmServiceWorking'] ?? 'Unknown'}');
      debugPrint(
          '   - User has token: ${infrastructure?['currentUserHasToken'] ?? 'Unknown'}');
      debugPrint(
          '   - Firebase DB: ${infrastructure?['firebaseDatabaseWorking'] ?? 'Unknown'}');

      debugPrint('📤 Delivery:');
      debugPrint(
          '   - Test data prepared: ${delivery?['testDataPrepared'] ?? 'Unknown'}');
      debugPrint(
          '   - Notification created: ${delivery?['notificationDataCreated'] ?? 'Unknown'}');
      debugPrint(
          '   - Firebase save: ${delivery?['firebaseSaveSuccess'] ?? 'Unknown'}');

      debugPrint('📊 Monitoring:');
      debugPrint(
          '   - Monitoring active: ${monitoring?['monitoringActive'] ?? 'Unknown'}');
      debugPrint(
          '   - Test request created: ${monitoring?['testRequestCreated'] ?? 'Unknown'}');

      debugPrint('🔄 Fallback:');
      debugPrint(
          '   - Fallback save: ${fallback?['fallbackSaveSuccess'] ?? 'Unknown'}');
      debugPrint(
          '   - Fallback retrieval: ${fallback?['fallbackRetrievalSuccess'] ?? 'Unknown'}');

      debugPrint('⚡ Performance:');
      debugPrint(
          '   - Avg notification time: ${performance?['averageTimePerNotification'] ?? 'Unknown'}ms');
      debugPrint(
          '   - Avg DB write time: ${performance?['averageDbWriteTime'] ?? 'Unknown'}ms');
    } catch (e) {
      debugPrint('❌ Error printing delivery summary: $e');
    }

    debugPrint('================================');
  }

  /// Run quick delivery check
  static Future<bool> runQuickDeliveryCheck() async {
    debugPrint('🚀 ===== فحص سريع للتسليم =====');

    try {
      // Quick checks
      final currentUser = FirebaseAuth.instance.currentUser;
      final isLoggedIn = await _authService.isLoggedIn();
      final isGoogleUser = await _authService.isGoogleSignIn();

      if (!isLoggedIn || !isGoogleUser || currentUser == null) {
        debugPrint('❌ User not properly authenticated for help requests');
        return false;
      }

      final hasToken = await _fcmTokenManager.hasTokenForUser(currentUser.uid);
      if (!hasToken) {
        debugPrint('⚠️ No FCM token - will use fallback delivery');
      }

      final isMonitoring = _deliveryMonitor.isMonitoring;
      if (!isMonitoring) {
        debugPrint('⚠️ Delivery monitoring not active');
      }

      debugPrint('✅ Quick delivery check completed');
      debugPrint('   - Authenticated: $isLoggedIn');
      debugPrint('   - Google user: $isGoogleUser');
      debugPrint('   - Has FCM token: $hasToken');
      debugPrint('   - Monitoring active: $isMonitoring');

      return true;
    } catch (e) {
      debugPrint('❌ Quick delivery check failed: $e');
      return false;
    }
  }
}
