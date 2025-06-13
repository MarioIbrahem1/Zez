import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/fcm_token_manager.dart';

/// Comprehensive diagnostic tool for token management
class TokenManagementDiagnostic {
  static final AuthService _authService = AuthService();
  static final GoogleAuthService _googleAuthService = GoogleAuthService();
  static final FCMTokenManager _fcmTokenManager = FCMTokenManager();

  /// Run complete token management diagnostic
  static Future<Map<String, dynamic>> runCompleteDiagnostic() async {
    debugPrint('🔍 ===== بدء تشخيص شامل لإدارة الرموز =====');

    final results = <String, dynamic>{};

    try {
      // 1. Authentication Token Diagnostic
      final authResults = await _diagnoseAuthenticationTokens();
      results['authentication'] = authResults;

      // 2. FCM Token Diagnostic
      final fcmResults = await _diagnoseFCMTokens();
      results['fcm'] = fcmResults;

      // 3. Google Authentication Diagnostic
      final googleResults = await _diagnoseGoogleAuthentication();
      results['google'] = googleResults;

      // 4. Token Expiration Diagnostic
      final expirationResults = await _diagnoseTokenExpiration();
      results['expiration'] = expirationResults;

      // 5. Storage Diagnostic
      final storageResults = await _diagnoseTokenStorage();
      results['storage'] = storageResults;

      // 6. Overall Health Check
      final healthResults = await _performHealthCheck();
      results['health'] = healthResults;

      debugPrint('✅ ===== تشخيص شامل مكتمل =====');
      _printDiagnosticSummary(results);

      return results;
    } catch (e) {
      debugPrint('❌ ===== فشل التشخيص الشامل: $e =====');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Diagnose authentication tokens
  static Future<Map<String, dynamic>> _diagnoseAuthenticationTokens() async {
    debugPrint('🔍 Diagnosing Authentication Tokens...');

    final results = <String, dynamic>{};

    try {
      // Check if user is logged in
      final isLoggedIn = await _authService.isLoggedIn();
      results['isLoggedIn'] = isLoggedIn;

      // Get authentication token
      final authToken = await _authService.getToken();
      results['hasAuthToken'] = authToken != null;
      results['authTokenLength'] = authToken?.length ?? 0;

      // Get user ID
      final userId = await _authService.getUserId();
      results['hasUserId'] = userId != null;
      results['userId'] = userId;

      // Get user email
      final userEmail = await _authService.getUserEmail();
      results['hasUserEmail'] = userEmail != null;
      results['userEmail'] = userEmail;

      // Check Google sign-in status
      final isGoogleUser = await _authService.isGoogleSignIn();
      results['isGoogleUser'] = isGoogleUser;

      // Check authentication type
      final authType = await _authService.getAuthType();
      results['authType'] = authType;

      debugPrint('📊 Auth Token Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Auth Token Diagnostic Error: $e');
    }

    return results;
  }

  /// Diagnose FCM tokens
  static Future<Map<String, dynamic>> _diagnoseFCMTokens() async {
    debugPrint('🔍 Diagnosing FCM Tokens...');

    final results = <String, dynamic>{};

    try {
      // Get FCM token directly from Firebase Messaging
      final fcmToken = await FirebaseMessaging.instance.getToken();
      results['hasFCMToken'] = fcmToken != null;
      results['fcmTokenLength'] = fcmToken?.length ?? 0;

      if (fcmToken != null) {
        results['fcmTokenFormat'] = {
          'containsColon': fcmToken.contains(':'),
          'minLength': fcmToken.length >= 100,
          'startsWithValid': fcmToken.startsWith('c') ||
              fcmToken.startsWith('d') ||
              fcmToken.startsWith('e'),
        };
      }

      // Check if FCM token is saved for current user
      final userId = await _authService.getUserId();
      if (userId != null) {
        final hasTokenForUser = await _fcmTokenManager.hasTokenForUser(userId);
        results['hasTokenForCurrentUser'] = hasTokenForUser;

        final savedToken = await _fcmTokenManager.getTokenForUser(userId);
        results['savedTokenMatches'] = savedToken == fcmToken;
        results['savedTokenLength'] = savedToken?.length ?? 0;
      }

      // Test token saving
      final tokenSaved = await _fcmTokenManager.saveTokenOnLogin();
      results['tokenSaveSuccess'] = tokenSaved;

      debugPrint('📊 FCM Token Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ FCM Token Diagnostic Error: $e');
    }

    return results;
  }

  /// Diagnose Google authentication
  static Future<Map<String, dynamic>> _diagnoseGoogleAuthentication() async {
    debugPrint('🔍 Diagnosing Google Authentication...');

    final results = <String, dynamic>{};

    try {
      // Check Firebase Auth current user
      final currentUser = FirebaseAuth.instance.currentUser;
      results['hasFirebaseUser'] = currentUser != null;

      if (currentUser != null) {
        results['firebaseUser'] = {
          'uid': currentUser.uid,
          'email': currentUser.email,
          'displayName': currentUser.displayName,
          'photoURL': currentUser.photoURL,
          'emailVerified': currentUser.emailVerified,
          'isAnonymous': currentUser.isAnonymous,
        };

        // Check if user data is synced to Firebase Database
        final database = FirebaseDatabase.instance;
        final userSnapshot =
            await database.ref('users/${currentUser.uid}').get();
        results['userDataSynced'] = userSnapshot.exists;

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          results['syncedUserData'] = {
            'isGoogleUser': userData['isGoogleUser'],
            'userType': userData['userType'],
            'isAvailableForHelp': userData['isAvailableForHelp'],
            'isOnline': userData['isOnline'],
            'lastSeen': userData['lastSeen'],
          };
        }
      }

      // Check Google Sign-In status
      final isGoogleSignedIn = _googleAuthService.isUserSignedIn();
      results['isGoogleSignedIn'] = isGoogleSignedIn;

      debugPrint('📊 Google Auth Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Google Auth Diagnostic Error: $e');
    }

    return results;
  }

  /// Diagnose token expiration
  static Future<Map<String, dynamic>> _diagnoseTokenExpiration() async {
    debugPrint('🔍 Diagnosing Token Expiration...');

    final results = <String, dynamic>{};

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check token expiry time
      final tokenExpiry = prefs.getInt('token_expiry');
      results['hasTokenExpiry'] = tokenExpiry != null;

      if (tokenExpiry != null) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(tokenExpiry);
        final isExpired = currentTime >= tokenExpiry;
        final timeUntilExpiry = tokenExpiry - currentTime;

        results['tokenExpiry'] = {
          'expiryTimestamp': tokenExpiry,
          'expiryDate': expiryTime.toIso8601String(),
          'isExpired': isExpired,
          'timeUntilExpiryMs': timeUntilExpiry,
          'timeUntilExpiryDays': timeUntilExpiry / (24 * 60 * 60 * 1000),
        };
      }

      // Check last login time
      final lastLoginTime = prefs.getInt('last_login_time');
      results['hasLastLoginTime'] = lastLoginTime != null;

      if (lastLoginTime != null) {
        final loginDate = DateTime.fromMillisecondsSinceEpoch(lastLoginTime);
        results['lastLogin'] = {
          'timestamp': lastLoginTime,
          'date': loginDate.toIso8601String(),
          'daysSinceLogin':
              (DateTime.now().millisecondsSinceEpoch - lastLoginTime) /
                  (24 * 60 * 60 * 1000),
        };
      }

      // Check persistent login settings
      final persistentLoginEnabled =
          prefs.getBool('persistent_login_enabled') ?? false;
      results['persistentLoginEnabled'] = persistentLoginEnabled;

      debugPrint('📊 Token Expiration Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Token Expiration Diagnostic Error: $e');
    }

    return results;
  }

  /// Diagnose token storage
  static Future<Map<String, dynamic>> _diagnoseTokenStorage() async {
    debugPrint('🔍 Diagnosing Token Storage...');

    final results = <String, dynamic>{};

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check all stored authentication data
      final storedKeys = [
        'auth_token',
        'user_id',
        'user_email',
        'user_name',
        'is_logged_in',
        'is_google_sign_in',
        'persistent_login_enabled',
        'token_expiry',
        'last_login_time',
        'google_user_data',
      ];

      final storedData = <String, dynamic>{};
      for (final key in storedKeys) {
        final value = prefs.get(key);
        storedData[key] = {
          'exists': value != null,
          'type': value.runtimeType.toString(),
          'value': value is String && value.length > 50
              ? '${value.substring(0, 50)}...'
              : value,
        };
      }

      results['storedData'] = storedData;

      // Check Firebase Database storage
      final userId = await _authService.getUserId();
      if (userId != null) {
        final database = FirebaseDatabase.instance;

        // Check user data
        final userSnapshot = await database.ref('users/$userId').get();
        results['firebaseUserData'] = userSnapshot.exists;

        // Check FCM token
        final tokenSnapshot =
            await database.ref('users/$userId/fcmToken').get();
        results['firebaseFCMToken'] = tokenSnapshot.exists;

        if (tokenSnapshot.exists) {
          final token = tokenSnapshot.value as String?;
          results['firebaseFCMTokenLength'] = token?.length ?? 0;
        }
      }

      debugPrint('📊 Token Storage Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Token Storage Diagnostic Error: $e');
    }

    return results;
  }

  /// Perform overall health check
  static Future<Map<String, dynamic>> _performHealthCheck() async {
    debugPrint('🔍 Performing Health Check...');

    final results = <String, dynamic>{};

    try {
      // Check if all required components are working
      final isLoggedIn = await _authService.isLoggedIn();
      final isGoogleUser = await _authService.isGoogleSignIn();
      final currentUser = FirebaseAuth.instance.currentUser;

      results['authenticationHealthy'] = isLoggedIn && currentUser != null;
      results['googleAuthHealthy'] = isGoogleUser && currentUser != null;

      if (currentUser != null) {
        final userId = currentUser.uid;
        final hasToken = await _fcmTokenManager.hasTokenForUser(userId);
        results['fcmTokenHealthy'] = hasToken;

        // Check if user can send help requests
        results['helpRequestsAvailable'] = isGoogleUser;
      }

      // Overall health score
      final healthChecks = [
        results['authenticationHealthy'] ?? false,
        results['googleAuthHealthy'] ?? false,
        results['fcmTokenHealthy'] ?? false,
        results['helpRequestsAvailable'] ?? false,
      ];

      final healthyCount = healthChecks.where((check) => check == true).length;
      results['healthScore'] = healthyCount / healthChecks.length;
      results['overallHealthy'] = results['healthScore'] >= 0.75;

      debugPrint('📊 Health Check Results: $results');
    } catch (e) {
      results['error'] = e.toString();
      debugPrint('❌ Health Check Error: $e');
    }

    return results;
  }

  /// Print diagnostic summary
  static void _printDiagnosticSummary(Map<String, dynamic> results) {
    debugPrint('📋 ===== ملخص التشخيص =====');

    try {
      final auth = results['authentication'] as Map<String, dynamic>?;
      final fcm = results['fcm'] as Map<String, dynamic>?;
      final google = results['google'] as Map<String, dynamic>?;
      final health = results['health'] as Map<String, dynamic>?;

      debugPrint('🔐 Authentication:');
      debugPrint('   - Logged in: ${auth?['isLoggedIn'] ?? 'Unknown'}');
      debugPrint('   - Google user: ${auth?['isGoogleUser'] ?? 'Unknown'}');
      debugPrint('   - Has auth token: ${auth?['hasAuthToken'] ?? 'Unknown'}');

      debugPrint('📱 FCM Tokens:');
      debugPrint('   - Has FCM token: ${fcm?['hasFCMToken'] ?? 'Unknown'}');
      debugPrint(
          '   - Token saved for user: ${fcm?['hasTokenForCurrentUser'] ?? 'Unknown'}');
      debugPrint(
          '   - Token save success: ${fcm?['tokenSaveSuccess'] ?? 'Unknown'}');

      debugPrint('🔍 Google Auth:');
      debugPrint(
          '   - Firebase user: ${google?['hasFirebaseUser'] ?? 'Unknown'}');
      debugPrint(
          '   - User data synced: ${google?['userDataSynced'] ?? 'Unknown'}');

      debugPrint('💚 Health:');
      debugPrint(
          '   - Overall healthy: ${health?['overallHealthy'] ?? 'Unknown'}');
      debugPrint('   - Health score: ${health?['healthScore'] ?? 'Unknown'}');
      debugPrint(
          '   - Help requests available: ${health?['helpRequestsAvailable'] ?? 'Unknown'}');
    } catch (e) {
      debugPrint('❌ Error printing summary: $e');
    }

    debugPrint('================================');
  }

  /// Fix common token issues
  static Future<Map<String, bool>> fixCommonIssues() async {
    debugPrint('🔧 ===== إصلاح المشاكل الشائعة =====');

    final fixes = <String, bool>{};

    try {
      // Fix 1: Ensure FCM token is saved and validated
      debugPrint('🔧 Fix 1: Saving and validating FCM token...');
      final tokenSaved = await _fcmTokenManager.saveTokenOnLogin();
      fixes['fcmTokenSaved'] = tokenSaved;

      // Validate token for current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final tokenValid =
            await _fcmTokenManager.validateTokenForUser(currentUser.uid);
        fixes['fcmTokenValid'] = tokenValid;

        if (!tokenValid) {
          debugPrint('🔧 Fix 1.1: Token invalid, attempting force refresh...');
          final refreshed = await _fcmTokenManager.forceTokenRefresh();
          fixes['fcmTokenRefreshed'] = refreshed;
        }
      }

      // Fix 2: Verify user data sync
      debugPrint('🔧 Fix 2: Syncing user data...');
      if (currentUser != null) {
        try {
          final userData = {
            'userId': currentUser.uid,
            'email': currentUser.email ?? '',
            'name': currentUser.displayName ?? '',
            'isGoogleUser': true,
            'isOnline': true,
            'isAvailableForHelp': true,
            'userType': 'google',
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
            'updatedAt': DateTime.now().toIso8601String(),
          };

          final database = FirebaseDatabase.instance;
          await database.ref('users/${currentUser.uid}').update(userData);
          fixes['userDataSynced'] = true;
        } catch (e) {
          fixes['userDataSynced'] = false;
          debugPrint('❌ User data sync failed: $e');
        }
      } else {
        fixes['userDataSynced'] = false;
      }

      // Fix 3: Update authentication status
      debugPrint('🔧 Fix 3: Updating authentication status...');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', currentUser != null);
        await prefs.setBool('is_google_sign_in', currentUser != null);
        fixes['authStatusUpdated'] = true;
      } catch (e) {
        fixes['authStatusUpdated'] = false;
        debugPrint('❌ Auth status update failed: $e');
      }

      debugPrint('✅ ===== إصلاح المشاكل مكتمل =====');
      debugPrint('📊 Fix Results: $fixes');
    } catch (e) {
      debugPrint('❌ ===== فشل إصلاح المشاكل: $e =====');
    }

    return fixes;
  }
}
