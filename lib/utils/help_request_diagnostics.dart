import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_token_manager.dart';
import '../services/firebase_help_request_service.dart';
import '../services/fcm_v1_service.dart';
import '../services/user_id_mapping_service.dart';

/// Diagnostic utility for testing Help Request system
class HelpRequestDiagnostics {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FCMTokenManager _tokenManager = FCMTokenManager();
  static final FCMv1Service _fcmService = FCMv1Service();

  /// Run comprehensive diagnostics for Google user help request system
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};
    
    debugPrint('🔍 Help Request Diagnostics: Starting comprehensive test...');
    
    try {
      // Test 1: Check Google Authentication
      results['google_auth'] = await _testGoogleAuthentication();
      
      // Test 2: Check FCM Token Management
      results['fcm_token'] = await _testFCMTokenManagement();
      
      // Test 3: Check User Data Sync
      results['user_data_sync'] = await _testUserDataSync();
      
      // Test 4: Check Firebase Database Connectivity
      results['firebase_connectivity'] = await _testFirebaseConnectivity();
      
      // Test 5: Check User Visibility on Map
      results['map_visibility'] = await _testMapVisibility();
      
      // Test 6: Test Help Request Flow
      results['help_request_flow'] = await _testHelpRequestFlow();
      
      // Test 7: Test Notification Delivery
      results['notification_delivery'] = await _testNotificationDelivery();
      
      debugPrint('✅ Help Request Diagnostics: All tests completed');
      return results;
      
    } catch (e) {
      debugPrint('❌ Help Request Diagnostics: Error during testing: $e');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Test Google Authentication status
  static Future<Map<String, dynamic>> _testGoogleAuthentication() async {
    final result = <String, dynamic>{};
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      result['is_authenticated'] = currentUser != null;
      result['user_id'] = currentUser?.uid;
      result['email'] = currentUser?.email;
      result['display_name'] = currentUser?.displayName;
      result['is_google_provider'] = currentUser?.providerData
          .any((provider) => provider.providerId == 'google.com') ?? false;
      
      // Check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      result['is_google_sign_in_pref'] = prefs.getBool('is_google_sign_in') ?? false;
      result['user_name_pref'] = prefs.getString('user_name');
      result['user_email_pref'] = prefs.getString('user_email');
      
      debugPrint('🔐 Auth Test: ${result['is_authenticated'] ? 'PASSED' : 'FAILED'}');
      
    } catch (e) {
      result['error'] = e.toString();
      debugPrint('❌ Auth Test: FAILED - $e');
    }
    
    return result;
  }

  /// Test FCM Token Management
  static Future<Map<String, dynamic>> _testFCMTokenManagement() async {
    final result = <String, dynamic>{};
    
    try {
      // Get current user ID
      final userIdService = UserIdMappingService();
      final userId = await userIdService.getCurrentUnifiedUserId();
      result['user_id'] = userId;
      
      if (userId != null) {
        // Check if token exists
        final hasToken = await _tokenManager.hasTokenForUser(userId);
        result['has_token'] = hasToken;
        
        // Get token
        final token = await _tokenManager.getTokenForUser(userId);
        result['token_exists'] = token != null;
        result['token_length'] = token?.length;
        
        // Try to save token
        final saveResult = await _tokenManager.saveTokenOnLogin();
        result['save_token_success'] = saveResult;
        
        debugPrint('📱 FCM Test: ${hasToken && token != null ? 'PASSED' : 'FAILED'}');
      } else {
        result['error'] = 'No user ID found';
        debugPrint('❌ FCM Test: FAILED - No user ID');
      }
      
    } catch (e) {
      result['error'] = e.toString();
      debugPrint('❌ FCM Test: FAILED - $e');
    }
    
    return result;
  }

  /// Test User Data Sync
  static Future<Map<String, dynamic>> _testUserDataSync() async {
    final result = <String, dynamic>{};
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Check Firebase Database user data
        final userSnapshot = await _database.ref('users/${currentUser.uid}').get();
        result['user_exists_in_firebase'] = userSnapshot.exists;
        
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          result['user_name'] = userData['name'] ?? userData['userName'];
          result['email'] = userData['email'];
          result['is_online'] = userData['isOnline'];
          result['is_available_for_help'] = userData['isAvailableForHelp'];
          result['has_location'] = userData['location'] != null;
          result['has_fcm_token'] = userData['fcmToken'] != null;
        }
        
        debugPrint('🔄 Sync Test: ${userSnapshot.exists ? 'PASSED' : 'FAILED'}');
      } else {
        result['error'] = 'No authenticated user';
        debugPrint('❌ Sync Test: FAILED - No user');
      }
      
    } catch (e) {
      result['error'] = e.toString();
      debugPrint('❌ Sync Test: FAILED - $e');
    }
    
    return result;
  }

  /// Test Firebase Database Connectivity
  static Future<Map<String, dynamic>> _testFirebaseConnectivity() async {
    final result = <String, dynamic>{};
    
    try {
      // Test write operation
      final testRef = _database.ref('test/connectivity');
      final testData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'test': 'connectivity_check'
      };
      
      await testRef.set(testData);
      result['write_success'] = true;
      
      // Test read operation
      final readSnapshot = await testRef.get();
      result['read_success'] = readSnapshot.exists;
      
      // Clean up
      await testRef.remove();
      result['cleanup_success'] = true;
      
      debugPrint('🔗 Connectivity Test: PASSED');
      
    } catch (e) {
      result['error'] = e.toString();
      debugPrint('❌ Connectivity Test: FAILED - $e');
    }
    
    return result;
  }

  /// Test Map Visibility
  static Future<Map<String, dynamic>> _testMapVisibility() async {
    final result = <String, dynamic>{};
    
    try {
      // Get all users from Firebase
      final usersSnapshot = await _database.ref('users').get();
      result['users_node_exists'] = usersSnapshot.exists;
      
      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
        result['total_users'] = usersData.length;
        
        // Count Google users
        int googleUsers = 0;
        int onlineUsers = 0;
        int usersWithLocation = 0;
        
        for (final userData in usersData.values) {
          final user = userData as Map<dynamic, dynamic>;
          if (user['isGoogleUser'] == true || user['userType'] == 'google') {
            googleUsers++;
          }
          if (user['isOnline'] == true) {
            onlineUsers++;
          }
          if (user['location'] != null) {
            usersWithLocation++;
          }
        }
        
        result['google_users'] = googleUsers;
        result['online_users'] = onlineUsers;
        result['users_with_location'] = usersWithLocation;
        
        debugPrint('👥 Visibility Test: Found $googleUsers Google users, $onlineUsers online');
      }
      
    } catch (e) {
      result['error'] = e.toString();
      debugPrint('❌ Visibility Test: FAILED - $e');
    }
    
    return result;
  }

  /// Test Help Request Flow (simulation)
  static Future<Map<String, dynamic>> _testHelpRequestFlow() async {
    final result = <String, dynamic>{};
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Check if help request service is accessible
        final helpRequestService = FirebaseHelpRequestService();
        result['service_accessible'] = true;
        
        // Check if we can access help requests
        final requestsSnapshot = await _database.ref('help_requests').get();
        result['help_requests_node_accessible'] = true;
        
        if (requestsSnapshot.exists) {
          final requestsData = requestsSnapshot.value as Map<dynamic, dynamic>;
          result['total_help_requests'] = requestsData.length;
        } else {
          result['total_help_requests'] = 0;
        }
        
        debugPrint('🆘 Help Request Test: Service accessible');
      } else {
        result['error'] = 'No authenticated user';
        debugPrint('❌ Help Request Test: FAILED - No user');
      }
      
    } catch (e) {
      result['error'] = e.toString();
      debugPrint('❌ Help Request Test: FAILED - $e');
    }
    
    return result;
  }

  /// Test Notification Delivery
  static Future<Map<String, dynamic>> _testNotificationDelivery() async {
    final result = <String, dynamic>{};
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Check notifications node
        final notificationsSnapshot = await _database.ref('notifications/${currentUser.uid}').get();
        result['notifications_node_accessible'] = true;
        
        if (notificationsSnapshot.exists) {
          final notificationsData = notificationsSnapshot.value as Map<dynamic, dynamic>;
          result['total_notifications'] = notificationsData.length;
          
          // Count unread notifications
          int unreadCount = 0;
          for (final notification in notificationsData.values) {
            final notif = notification as Map<dynamic, dynamic>;
            if (notif['isRead'] != true) {
              unreadCount++;
            }
          }
          result['unread_notifications'] = unreadCount;
        } else {
          result['total_notifications'] = 0;
          result['unread_notifications'] = 0;
        }
        
        debugPrint('🔔 Notification Test: Found ${result['total_notifications']} notifications');
      } else {
        result['error'] = 'No authenticated user';
        debugPrint('❌ Notification Test: FAILED - No user');
      }
      
    } catch (e) {
      result['error'] = e.toString();
      debugPrint('❌ Notification Test: FAILED - $e');
    }
    
    return result;
  }

  /// Print diagnostic results in a formatted way
  static void printResults(Map<String, dynamic> results) {
    debugPrint('\n🔍 ========== HELP REQUEST DIAGNOSTICS RESULTS ==========');
    
    for (final entry in results.entries) {
      debugPrint('\n📋 ${entry.key.toUpperCase()}:');
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        for (final subEntry in value.entries) {
          debugPrint('   ${subEntry.key}: ${subEntry.value}');
        }
      } else {
        debugPrint('   ${entry.value}');
      }
    }
    
    debugPrint('\n🔍 ========== END DIAGNOSTICS ==========\n');
  }
}
