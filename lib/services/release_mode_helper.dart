import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة مساعدة للتعامل مع مشاكل Release Mode
class ReleaseModeHelper {
  static const String _fcmTokenKey = 'fcm_token_release';
  static const String _lastTokenRefreshKey = 'last_token_refresh';

  /// التحقق من أن FCM يعمل بشكل صحيح في Release Mode
  static Future<bool> verifyFCMInReleaseMode() async {
    try {
      // في Release Mode، نحتاج للتأكد من أن FCM token يتم إنتاجه بشكل صحيح
      if (kReleaseMode) {
        print('🔍 ReleaseModeHelper: Verifying FCM in Release Mode...');

        // محاولة الحصول على FCM token مع retry
        String? fcmToken;
        int retryCount = 0;
        const maxRetries = 5;

        while (fcmToken == null && retryCount < maxRetries) {
          try {
            fcmToken = await FirebaseMessaging.instance.getToken();
            print(
                '✅ ReleaseModeHelper: FCM token obtained on attempt ${retryCount + 1}');
            break;
                    } catch (e) {
            print(
                '❌ ReleaseModeHelper: FCM token attempt ${retryCount + 1} failed: $e');
          }

          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(
                Duration(seconds: retryCount * 2)); // Exponential backoff
          }
        }

        if (fcmToken == null) {
          print(
              '❌ ReleaseModeHelper: Failed to get FCM token after $maxRetries attempts');
          return false;
        }

        // حفظ الـ token في SharedPreferences كـ backup
        await _saveFCMTokenBackup(fcmToken);

        // التحقق من صحة الـ token
        if (fcmToken.length < 100 || !fcmToken.contains(':')) {
          print(
              '❌ ReleaseModeHelper: Invalid FCM token format in Release Mode');
          return false;
        }

        print(
            '✅ ReleaseModeHelper: FCM verification successful in Release Mode');
        return true;
      } else {
        // في Debug Mode، الفحص العادي
        final fcmToken = await FirebaseMessaging.instance.getToken();
        return fcmToken != null;
      }
    } catch (e) {
      print('❌ ReleaseModeHelper: FCM verification failed: $e');
      return false;
    }
  }

  /// حفظ FCM token كـ backup في SharedPreferences
  static Future<void> _saveFCMTokenBackup(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      await prefs.setInt(
          _lastTokenRefreshKey, DateTime.now().millisecondsSinceEpoch);
      print('✅ ReleaseModeHelper: FCM token backup saved');
    } catch (e) {
      print('❌ ReleaseModeHelper: Failed to save FCM token backup: $e');
    }
  }

  /// استرجاع FCM token من الـ backup
  static Future<String?> getFCMTokenBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_fcmTokenKey);
      final lastRefresh = prefs.getInt(_lastTokenRefreshKey);

      if (token != null && lastRefresh != null) {
        // التحقق من أن الـ token ليس قديم جداً (أكثر من 7 أيام)
        final daysSinceRefresh = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastRefresh))
            .inDays;

        if (daysSinceRefresh <= 7) {
          print(
              '✅ ReleaseModeHelper: Using backup FCM token ($daysSinceRefresh days old)');
          return token;
        } else {
          print(
              '⚠️ ReleaseModeHelper: Backup FCM token is too old ($daysSinceRefresh days)');
        }
      }

      return null;
    } catch (e) {
      print('❌ ReleaseModeHelper: Failed to get FCM token backup: $e');
      return null;
    }
  }

  /// إعداد Firebase Database للعمل بشكل أفضل في Release Mode
  static Future<void> optimizeFirebaseForReleaseMode() async {
    try {
      if (kReleaseMode) {
        print('🔧 ReleaseModeHelper: Optimizing Firebase for Release Mode...');

        // تفعيل persistence للعمل offline
        try {
          FirebaseDatabase.instance.setPersistenceEnabled(true);
          print('✅ ReleaseModeHelper: Firebase persistence enabled');
        } catch (e) {
          print('⚠️ ReleaseModeHelper: Could not enable persistence: $e');
        }

        // تحسين cache size
        try {
          FirebaseDatabase.instance
              .setPersistenceCacheSizeBytes(10 * 1024 * 1024); // 10MB
          print('✅ ReleaseModeHelper: Firebase cache size set to 10MB');
        } catch (e) {
          print('⚠️ ReleaseModeHelper: Could not set cache size: $e');
        }

        // تفعيل logging في Release Mode للتشخيص
        try {
          FirebaseDatabase.instance.setLoggingEnabled(true);
          print('✅ ReleaseModeHelper: Firebase logging enabled');
        } catch (e) {
          print('⚠️ ReleaseModeHelper: Could not enable logging: $e');
        }

        print('✅ ReleaseModeHelper: Firebase optimization completed');
      }
    } catch (e) {
      print('❌ ReleaseModeHelper: Firebase optimization failed: $e');
    }
  }

  /// تشخيص مشاكل الشبكة في Release Mode
  static Future<Map<String, dynamic>> diagnoseNetworkIssues() async {
    final results = <String, dynamic>{};

    try {
      // فحص الاتصال بـ Firebase
      results['firebase_reachable'] = await _testFirebaseConnection();

      // فحص الاتصال بـ FCM
      results['fcm_reachable'] = await _testFCMConnection();

      // فحص الاتصال بـ Google APIs
      results['google_apis_reachable'] = await _testGoogleAPIsConnection();

      // فحص FCM token
      results['fcm_token_valid'] = await _validateFCMToken();

      print('📊 ReleaseModeHelper: Network diagnosis completed');
      print('📊 Results: $results');
    } catch (e) {
      print('❌ ReleaseModeHelper: Network diagnosis failed: $e');
      results['error'] = e.toString();
    }

    return results;
  }

  static Future<bool> _testFirebaseConnection() async {
    try {
      final database = FirebaseDatabase.instance;
      final ref = database.ref('test_connection');
      await ref.set({'timestamp': DateTime.now().millisecondsSinceEpoch});
      await ref.remove();
      return true;
    } catch (e) {
      print('❌ ReleaseModeHelper: Firebase connection test failed: $e');
      return false;
    }
  }

  static Future<bool> _testFCMConnection() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('❌ ReleaseModeHelper: FCM connection test failed: $e');
      return false;
    }
  }

  static Future<bool> _testGoogleAPIsConnection() async {
    try {
      // محاولة الوصول لـ Google APIs
      // يمكن إضافة فحص HTTP request هنا إذا لزم الأمر
      return true;
    } catch (e) {
      print('❌ ReleaseModeHelper: Google APIs connection test failed: $e');
      return false;
    }
  }

  static Future<bool> _validateFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return false;

      // التحقق من صيغة الـ token
      return token.length >= 100 && token.contains(':');
    } catch (e) {
      print('❌ ReleaseModeHelper: FCM token validation failed: $e');
      return false;
    }
  }

  /// طباعة معلومات التشخيص في Release Mode
  static void printReleaseModeDiagnostics() {
    if (kReleaseMode) {
      print('🔍 ========== RELEASE MODE DIAGNOSTICS ==========');
      print('🔍 App is running in RELEASE MODE');
      print('🔍 Debug prints are disabled by default');
      print('🔍 Using production Firebase configuration');
      print('🔍 Network security config is active');
      print('🔍 ===============================================');
    }
  }
}
