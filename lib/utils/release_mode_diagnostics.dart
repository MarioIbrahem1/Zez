import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:road_helperr/services/release_mode_helper.dart';
import 'package:road_helperr/config/release_mode_config.dart';

/// أداة تشخيص شاملة للـ Release Mode
class ReleaseModeDignostics {
  /// تشغيل تشخيص شامل للتطبيق في Release Mode
  static Future<Map<String, dynamic>> runFullDiagnostics() async {
    final results = <String, dynamic>{};

    try {
      if (kReleaseMode) {
        print('🔍 ========== RELEASE MODE DIAGNOSTICS ==========');

        // 1. فحص التكوين العام
        results['configuration'] = await _diagnoseConfiguration();

        // 2. فحص Firebase
        results['firebase'] = await _diagnoseFirebase();

        // 3. فحص FCM
        results['fcm'] = await _diagnoseFCM();

        // 4. فحص الشبكة
        results['network'] = await _diagnoseNetwork();

        // 5. فحص الصلاحيات
        results['permissions'] = await _diagnosePermissions();

        // 6. فحص التوقيع
        results['signing'] = await _diagnoseSigning();

        print('📊 ========== DIAGNOSTICS COMPLETED ==========');
        print('📊 Results Summary:');
        results.forEach((key, value) {
          if (value is Map) {
            final status = value['status'] ?? 'unknown';
            print('📊 $key: $status');
          }
        });
        print('📊 ==========================================');
      } else {
        results['error'] = 'Not running in Release Mode';
      }
    } catch (e) {
      print('❌ ReleaseModeDignostics: Full diagnostics failed: $e');
      results['error'] = e.toString();
    }

    return results;
  }

  /// فحص التكوين العام
  static Future<Map<String, dynamic>> _diagnoseConfiguration() async {
    final result = <String, dynamic>{};

    try {
      print('🔧 Diagnosing Configuration...');

      // فحص إعدادات Release Mode
      final configValid = ReleaseModeConfig.validateConfiguration();
      result['config_valid'] = configValid;

      // فحص البناء
      result['build_type'] = kReleaseMode ? 'release' : 'debug';
      result['debug_mode'] = kDebugMode;

      // فحص الإعدادات المهمة
      final config = ReleaseModeConfig.getConfigForBuildType();
      result['firebase_persistence'] = config['persistence_enabled'];
      result['offline_mode'] = config['offline_mode_enabled'];

      result['status'] = configValid ? 'healthy' : 'issues_found';
      print('✅ Configuration diagnosis completed');
    } catch (e) {
      print('❌ Configuration diagnosis failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
    }

    return result;
  }

  /// فحص Firebase
  static Future<Map<String, dynamic>> _diagnoseFirebase() async {
    final result = <String, dynamic>{};

    try {
      print('🔥 Diagnosing Firebase...');

      // فحص اتصال Firebase Database
      final database = FirebaseDatabase.instance;
      final testRef = database
          .ref('test_connection_${DateTime.now().millisecondsSinceEpoch}');

      await testRef.set({'timestamp': DateTime.now().millisecondsSinceEpoch});
      final snapshot = await testRef.get();

      if (snapshot.exists) {
        result['database_connection'] = 'working';
        await testRef.remove(); // تنظيف
      } else {
        result['database_connection'] = 'failed';
      }

      // فحص Firebase Auth
      result['auth_available'] = true; // Firebase Auth متوفر دائماً

      result['status'] = result['database_connection'] == 'working'
          ? 'healthy'
          : 'issues_found';
      print('✅ Firebase diagnosis completed');
    } catch (e) {
      print('❌ Firebase diagnosis failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
      result['database_connection'] = 'failed';
    }

    return result;
  }

  /// فحص FCM
  static Future<Map<String, dynamic>> _diagnoseFCM() async {
    final result = <String, dynamic>{};

    try {
      print('📱 Diagnosing FCM...');

      // فحص الحصول على FCM token
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null && token.isNotEmpty) {
        result['token_available'] = true;
        result['token_length'] = token.length;
        result['token_format_valid'] =
            token.contains(':') && token.length > 100;

        // فحص صحة الـ token format
        if (result['token_format_valid']) {
          result['token_status'] = 'healthy';
        } else {
          result['token_status'] = 'invalid_format';
        }
      } else {
        result['token_available'] = false;
        result['token_status'] = 'unavailable';
      }

      // فحص صلاحيات الإشعارات
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      result['notification_permission'] = settings.authorizationStatus.name;

      result['status'] = result['token_available'] == true &&
              result['token_format_valid'] == true
          ? 'healthy'
          : 'issues_found';
      print('✅ FCM diagnosis completed');
    } catch (e) {
      print('❌ FCM diagnosis failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
      result['token_available'] = false;
    }

    return result;
  }

  /// فحص الشبكة
  static Future<Map<String, dynamic>> _diagnoseNetwork() async {
    final result = <String, dynamic>{};

    try {
      print('🌐 Diagnosing Network...');

      // استخدام ReleaseModeHelper للفحص
      final networkResults = await ReleaseModeHelper.diagnoseNetworkIssues();
      result.addAll(networkResults);

      // تحديد الحالة العامة
      final allHealthy = networkResults.values.every((value) => value == true);
      result['status'] = allHealthy ? 'healthy' : 'issues_found';

      print('✅ Network diagnosis completed');
    } catch (e) {
      print('❌ Network diagnosis failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
    }

    return result;
  }

  /// فحص الصلاحيات
  static Future<Map<String, dynamic>> _diagnosePermissions() async {
    final result = <String, dynamic>{};

    try {
      print('🔐 Diagnosing Permissions...');

      // فحص صلاحيات الإشعارات
      final messagingSettings =
          await FirebaseMessaging.instance.getNotificationSettings();
      result['notification_permission'] =
          messagingSettings.authorizationStatus.name;
      result['notification_enabled'] = messagingSettings.authorizationStatus ==
          AuthorizationStatus.authorized;

      // في المستقبل يمكن إضافة فحص صلاحيات أخرى
      result['internet_permission'] = true; // متوفرة في AndroidManifest
      result['location_permission'] = true; // متوفرة في AndroidManifest

      final allPermissionsOk = result['notification_enabled'] == true;
      result['status'] = allPermissionsOk ? 'healthy' : 'issues_found';

      print('✅ Permissions diagnosis completed');
    } catch (e) {
      print('❌ Permissions diagnosis failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
    }

    return result;
  }

  /// فحص التوقيع
  static Future<Map<String, dynamic>> _diagnoseSigning() async {
    final result = <String, dynamic>{};

    try {
      print('✍️ Diagnosing App Signing...');

      // في Release Mode، التطبيق يجب أن يكون موقع بشكل صحيح
      result['is_release_build'] = kReleaseMode;
      result['is_debug_build'] = kDebugMode;

      // فحص إذا كان التوقيع يعمل مع Firebase
      // إذا كان Firebase يعمل، فالتوقيع صحيح
      final database = FirebaseDatabase.instance;
      final testRef =
          database.ref('signing_test_${DateTime.now().millisecondsSinceEpoch}');

      await testRef.set({'test': true});
      await testRef.remove();

      result['firebase_accepts_signature'] = true;
      result['status'] = 'healthy';

      print('✅ App signing diagnosis completed');
    } catch (e) {
      print('❌ App signing diagnosis failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
      result['firebase_accepts_signature'] = false;
    }

    return result;
  }

  /// طباعة تقرير مفصل
  static void printDetailedReport(Map<String, dynamic> diagnostics) {
    if (!kReleaseMode) return;

    print('📋 ========== DETAILED DIAGNOSTICS REPORT ==========');

    diagnostics.forEach((category, data) {
      print('📋 Category: $category');
      if (data is Map) {
        data.forEach((key, value) {
          print('📋   $key: $value');
        });
      } else {
        print('📋   Value: $data');
      }
      print('📋 ');
    });

    print('📋 ================================================');
  }

  /// فحص سريع للمشاكل الحرجة
  static Future<List<String>> getCriticalIssues() async {
    final issues = <String>[];

    try {
      if (!kReleaseMode) return issues;

      // فحص FCM token
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        issues.add('FCM token is not available');
      } else if (!token.contains(':') || token.length < 100) {
        issues.add('FCM token format is invalid');
      }

      // فحص Firebase connection
      try {
        final database = FirebaseDatabase.instance;
        final testRef = database.ref('critical_test');
        await testRef.set({'test': true}).timeout(const Duration(seconds: 5));
        await testRef.remove();
      } catch (e) {
        issues.add('Firebase Database connection failed');
      }

      // فحص صلاحيات الإشعارات
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        issues.add('Notification permission not granted');
      }
    } catch (e) {
      issues.add('Critical diagnostics failed: $e');
    }

    return issues;
  }
}
