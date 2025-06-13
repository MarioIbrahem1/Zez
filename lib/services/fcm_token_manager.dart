import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:road_helperr/services/release_mode_helper.dart';
import 'package:road_helperr/services/user_id_mapping_service.dart';
import 'package:flutter/foundation.dart';

/// مدير توكنات FCM
/// يضمن حفظ توكنات FCM لجميع أنواع المستخدمين (Firebase و SQL)
class FCMTokenManager {
  static final FCMTokenManager _instance = FCMTokenManager._internal();
  factory FCMTokenManager() => _instance;
  FCMTokenManager._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// حفظ FCM token للمستخدم الحالي عند تسجيل الدخول
  /// يجب استدعاء هذه الطريقة بعد تسجيل الدخول مباشرة
  Future<bool> saveTokenOnLogin() async {
    try {
      debugPrint('🔔 FCMTokenManager: ========== SAVING FCM TOKEN ==========');
      debugPrint('🔔 FCMTokenManager: Starting FCM token save process...');

      // في Release Mode، نستخدم ReleaseModeHelper للتحقق من FCM
      if (kReleaseMode) {
        debugPrint(
            '🔍 FCMTokenManager: Running in Release Mode - using enhanced FCM handling');
        final fcmWorking = await ReleaseModeHelper.verifyFCMInReleaseMode();
        if (!fcmWorking) {
          debugPrint(
              '❌ FCMTokenManager: FCM verification failed in Release Mode');
          // محاولة استخدام backup token
          final backupToken = await ReleaseModeHelper.getFCMTokenBackup();
          if (backupToken != null) {
            debugPrint('🔄 FCMTokenManager: Using backup FCM token');
            return await _saveTokenToFirebase(backupToken);
          }
          return false;
        }
      }

      // الحصول على FCM token
      debugPrint(
          '🔍 FCMTokenManager: Getting FCM token from Firebase Messaging...');
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint(
            '❌ FCMTokenManager: Could not get FCM token from Firebase Messaging');
        debugPrint(
            '❌ FCMTokenManager: This might be a Firebase configuration issue');

        // في Release Mode، محاولة استخدام backup token
        if (kReleaseMode) {
          final backupToken = await ReleaseModeHelper.getFCMTokenBackup();
          if (backupToken != null) {
            debugPrint(
                '🔄 FCMTokenManager: Using backup FCM token as fallback');
            return await _saveTokenToFirebase(backupToken);
          }
        }

        return false;
      }

      debugPrint('✅ FCMTokenManager: Got FCM token successfully');
      debugPrint('🔑 FCMTokenManager: Token length: ${fcmToken.length}');
      debugPrint(
          '🔑 FCMTokenManager: Token preview: ${fcmToken.substring(0, 20)}...${fcmToken.substring(fcmToken.length - 10)}');

      // Validate token format before saving
      if (!_isValidTokenFormat(fcmToken)) {
        debugPrint('❌ FCMTokenManager: Invalid token format detected');
        // Try to force refresh token
        debugPrint('🔄 FCMTokenManager: Attempting to force refresh token...');
        final refreshedToken = await _forceRefreshToken();
        if (refreshedToken != null) {
          return await _saveTokenToFirebase(refreshedToken);
        }
        return false;
      }

      return await _saveTokenToFirebase(fcmToken);
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error saving FCM token: $e');
      debugPrint('❌ FCMTokenManager: Stack trace: ${StackTrace.current}');
      debugPrint('🔔 FCMTokenManager: ========== TOKEN SAVE FAILED ==========');
      return false;
    }
  }

  /// حفظ FCM token في Firebase Database
  Future<bool> _saveTokenToFirebase(String fcmToken) async {
    try {
      // تحديد معرف المستخدم الحالي
      debugPrint('🔍 FCMTokenManager: Getting current user ID...');
      String? userId = await getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ FCMTokenManager: No current user found');
        debugPrint('❌ FCMTokenManager: User might not be logged in properly');
        return false;
      }

      debugPrint('✅ FCMTokenManager: Found current user: $userId');

      // حفظ التوكن في Firebase Database مع verification
      debugPrint('💾 FCMTokenManager: Saving token to Firebase Database...');
      await _database.ref('users/$userId/fcmToken').set(fcmToken);

      // Verify the token was saved correctly
      debugPrint('🔍 FCMTokenManager: Verifying token was saved...');
      final savedTokenSnapshot =
          await _database.ref('users/$userId/fcmToken').get();
      if (savedTokenSnapshot.exists && savedTokenSnapshot.value == fcmToken) {
        debugPrint(
            '✅ FCMTokenManager: Token saved and verified successfully for user: $userId');
        debugPrint('📍 FCMTokenManager: Saved to path: users/$userId/fcmToken');
        debugPrint(
            '🔔 FCMTokenManager: ========== TOKEN SAVED SUCCESSFULLY ==========');
        return true;
      } else {
        debugPrint('❌ FCMTokenManager: Token verification failed');
        debugPrint(
            '🔔 FCMTokenManager: ========== TOKEN VERIFICATION FAILED ==========');
        return false;
      }
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error saving token to Firebase: $e');
      return false;
    }
  }

  /// حفظ FCM token لمستخدم محدد
  Future<bool> saveTokenForUser(String userId) async {
    try {
      debugPrint('🔔 FCMTokenManager: Saving FCM token for user: $userId');

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint('❌ FCMTokenManager: Could not get FCM token');
        return false;
      }

      await _database.ref('users/$userId/fcmToken').set(fcmToken);
      debugPrint(
          '✅ FCMTokenManager: Token saved successfully for user: $userId');
      return true;
    } catch (e) {
      debugPrint(
          '❌ FCMTokenManager: Error saving FCM token for user $userId: $e');
      return false;
    }
  }

  /// الحصول على معرف المستخدم الحالي الموحد (محدث للنظام الهجين)
  Future<String?> getCurrentUserId() async {
    try {
      // استخدام خدمة User ID Mapping للحصول على User ID الموحد
      final userIdMappingService = UserIdMappingService();
      final unifiedUserId =
          await userIdMappingService.getCurrentUnifiedUserId();

      if (unifiedUserId != null) {
        debugPrint('✅ FCMTokenManager: Found unified user ID: $unifiedUserId');
        return unifiedUserId;
      }

      debugPrint('❌ FCMTokenManager: No unified user ID found');
      return null;
    } catch (e) {
      debugPrint(
          '❌ FCMTokenManager: Error getting current unified user ID: $e');
      return null;
    }
  }

  /// تحديث FCM token عند تجديده
  Future<void> onTokenRefresh(String newToken) async {
    try {
      debugPrint('🔄 FCMTokenManager: FCM token refreshed');
      debugPrint('🔑 FCMTokenManager: New token length: ${newToken.length}');

      // Validate new token format
      if (newToken.isEmpty ||
          !newToken.contains(':') ||
          newToken.length < 100) {
        debugPrint('❌ FCMTokenManager: Invalid new token format');
        return;
      }

      // Save the new token
      final saved = await saveTokenOnLogin();
      if (saved) {
        debugPrint('✅ FCMTokenManager: New token saved successfully');

        // Update token for current user specifically
        final currentUserId = await getCurrentUserId();
        if (currentUserId != null) {
          await _database.ref('users/$currentUserId/fcmToken').set(newToken);
          await _database
              .ref('users/$currentUserId/tokenUpdatedAt')
              .set(DateTime.now().toIso8601String());
          debugPrint(
              '✅ FCMTokenManager: Token updated for current user: $currentUserId');
        }
      } else {
        debugPrint('❌ FCMTokenManager: Failed to save new token');
      }
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error handling token refresh: $e');
    }
  }

  /// التحقق من وجود FCM token للمستخدم
  Future<bool> hasTokenForUser(String userId) async {
    try {
      final tokenSnapshot = await _database.ref('users/$userId/fcmToken').get();
      return tokenSnapshot.exists && tokenSnapshot.value != null;
    } catch (e) {
      debugPrint(
          '❌ FCMTokenManager: Error checking token for user $userId: $e');
      return false;
    }
  }

  /// الحصول على FCM token للمستخدم
  Future<String?> getTokenForUser(String userId) async {
    try {
      debugPrint('🔍 FCMTokenManager: Getting token for user: $userId');
      final tokenSnapshot = await _database.ref('users/$userId/fcmToken').get();
      if (tokenSnapshot.exists) {
        final token = tokenSnapshot.value as String?;
        debugPrint('✅ FCMTokenManager: Found token for user $userId');
        return token;
      }
      debugPrint('❌ FCMTokenManager: No token found for user $userId');

      // Try to save current device token for this user if they are the current user
      final currentUserId = await getCurrentUserId();
      if (currentUserId == userId) {
        debugPrint(
            '🔄 FCMTokenManager: This is current user, attempting to save token...');
        final saved = await saveTokenOnLogin();
        if (saved) {
          // Try to get the token again
          final newTokenSnapshot =
              await _database.ref('users/$userId/fcmToken').get();
          if (newTokenSnapshot.exists) {
            debugPrint(
                '✅ FCMTokenManager: Token saved and retrieved for current user');
            return newTokenSnapshot.value as String?;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error getting token for user $userId: $e');
      return null;
    }
  }

  /// حفظ FCM token لجميع المستخدمين النشطين (للاستخدام الإداري)
  Future<void> saveTokenForAllActiveUsers() async {
    try {
      debugPrint(
          '🔄 FCMTokenManager: Saving FCM token for all active users...');

      // Get current FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint('❌ FCMTokenManager: No FCM token available');
        return;
      }

      // Get all active users from Firebase Database
      final usersSnapshot = await _database.ref('users').get();
      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>;

        for (final userId in usersData.keys) {
          try {
            // Check if user is active (has recent activity)
            final userRef = _database.ref('users/$userId');
            final lastActiveSnapshot = await userRef.child('lastActive').get();

            if (lastActiveSnapshot.exists) {
              final lastActive = lastActiveSnapshot.value as int?;
              final now = DateTime.now().millisecondsSinceEpoch;

              // If user was active in the last 7 days, save token
              if (lastActive != null &&
                  (now - lastActive) < (7 * 24 * 60 * 60 * 1000)) {
                await userRef.child('fcmToken').set(fcmToken);
                debugPrint(
                    '✅ FCMTokenManager: Token saved for active user: $userId');
              }
            }
          } catch (e) {
            debugPrint(
                '❌ FCMTokenManager: Error saving token for user $userId: $e');
          }
        }
      }

      debugPrint(
          '✅ FCMTokenManager: Completed saving tokens for all active users');
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error in saveTokenForAllActiveUsers: $e');
    }
  }

  /// Validate FCM token format and functionality
  Future<bool> validateTokenForUser(String userId) async {
    try {
      debugPrint('🔍 FCMTokenManager: Validating token for user: $userId');

      final token = await getTokenForUser(userId);
      if (token == null) {
        debugPrint('❌ FCMTokenManager: No token found for user');
        return false;
      }

      // Check token format
      if (!_isValidTokenFormat(token)) {
        debugPrint('❌ FCMTokenManager: Invalid token format');
        return false;
      }

      // Check token age
      final tokenAge = await _getTokenAge(userId);
      if (tokenAge != null && tokenAge > 60) {
        // More than 60 days old
        debugPrint(
            '⚠️ FCMTokenManager: Token is old (${tokenAge.toInt()} days)');
        // Try to refresh the token
        return await _refreshTokenForUser(userId);
      }

      debugPrint('✅ FCMTokenManager: Token validation passed');
      return true;
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error validating token: $e');
      return false;
    }
  }

  /// Check if token format is valid
  bool _isValidTokenFormat(String token) {
    return token.isNotEmpty &&
        token.contains(':') &&
        token.length >= 100 &&
        !token.contains(' ') &&
        token.split(':').length >= 2;
  }

  /// Get token age in days
  Future<double?> _getTokenAge(String userId) async {
    try {
      final tokenUpdatedSnapshot =
          await _database.ref('users/$userId/tokenUpdatedAt').get();
      if (tokenUpdatedSnapshot.exists) {
        final updatedAt = DateTime.parse(tokenUpdatedSnapshot.value as String);
        final now = DateTime.now();
        return now.difference(updatedAt).inDays.toDouble();
      }
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error getting token age: $e');
    }
    return null;
  }

  /// Refresh token for specific user
  Future<bool> _refreshTokenForUser(String userId) async {
    try {
      debugPrint('🔄 FCMTokenManager: Refreshing token for user: $userId');

      // Get current user ID to check if this is the current user
      final currentUserId = await getCurrentUserId();
      if (currentUserId == userId) {
        // This is the current user, we can refresh their token
        final newToken = await FirebaseMessaging.instance.getToken();
        if (newToken != null && _isValidTokenFormat(newToken)) {
          await _database.ref('users/$userId/fcmToken').set(newToken);
          await _database
              .ref('users/$userId/tokenUpdatedAt')
              .set(DateTime.now().toIso8601String());
          debugPrint('✅ FCMTokenManager: Token refreshed for current user');
          return true;
        }
      } else {
        // For other users, we can't refresh their token directly
        debugPrint('⚠️ FCMTokenManager: Cannot refresh token for other users');
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error refreshing token: $e');
      return false;
    }
  }

  /// Force refresh FCM token (internal method)
  Future<String?> _forceRefreshToken() async {
    try {
      debugPrint('🔄 FCMTokenManager: Force refreshing FCM token...');

      // Delete current token
      await FirebaseMessaging.instance.deleteToken();

      // Wait a moment for the deletion to process
      await Future.delayed(const Duration(seconds: 2));

      // Get new token
      final newToken = await FirebaseMessaging.instance.getToken();
      if (newToken != null && _isValidTokenFormat(newToken)) {
        debugPrint(
            '✅ FCMTokenManager: Successfully obtained new token after force refresh');
        return newToken;
      }

      debugPrint(
          '❌ FCMTokenManager: Failed to obtain valid token after force refresh');
      return null;
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error during force refresh: $e');
      return null;
    }
  }

  /// Force token refresh for current user
  Future<bool> forceTokenRefresh() async {
    try {
      debugPrint('🔄 FCMTokenManager: Forcing token refresh...');

      // Delete current token to force refresh
      await FirebaseMessaging.instance.deleteToken();

      // Wait a moment
      await Future.delayed(const Duration(seconds: 2));

      // Get new token
      final newToken = await FirebaseMessaging.instance.getToken();
      if (newToken != null && _isValidTokenFormat(newToken)) {
        debugPrint('✅ FCMTokenManager: New token obtained after force refresh');

        // Save the new token
        final saved = await saveTokenOnLogin();
        if (saved) {
          debugPrint('✅ FCMTokenManager: Force refresh completed successfully');
          return true;
        }
      }

      debugPrint('❌ FCMTokenManager: Force refresh failed');
      return false;
    } catch (e) {
      debugPrint('❌ FCMTokenManager: Error during force refresh: $e');
      return false;
    }
  }
}
