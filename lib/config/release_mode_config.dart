import 'package:flutter/foundation.dart';

/// إعدادات خاصة بـ Release Mode
class ReleaseModeConfig {
  /// التحقق من أن التطبيق يعمل في Release Mode
  static bool get isReleaseMode => kReleaseMode;

  /// إعدادات Firebase للـ Release Mode
  static const Map<String, dynamic> firebaseSettings = {
    'persistence_enabled': true,
    'cache_size_bytes': 10 * 1024 * 1024, // 10MB
    'logging_enabled': true, // نفعل logging حتى في Release Mode للتشخيص
    'offline_persistence': true,
  };

  /// إعدادات FCM للـ Release Mode
  static const Map<String, dynamic> fcmSettings = {
    'token_refresh_interval': 24 * 60 * 60 * 1000, // 24 hours
    'max_retry_attempts': 5,
    'retry_delay_seconds': [2, 4, 8, 16, 32], // Exponential backoff
    'backup_token_validity_days': 7,
  };

  /// إعدادات الشبكة للـ Release Mode
  static const Map<String, dynamic> networkSettings = {
    'connection_timeout_seconds': 30,
    'read_timeout_seconds': 30,
    'max_retry_attempts': 3,
    'enable_certificate_pinning': false, // نتركه false لتجنب مشاكل الشهادات
  };

  /// إعدادات التشخيص للـ Release Mode
  static const Map<String, dynamic> diagnosticsSettings = {
    'enable_network_diagnostics': true,
    'enable_fcm_diagnostics': true,
    'enable_firebase_diagnostics': true,
    'log_level': 'info', // info, warning, error
  };

  /// URLs مهمة للتحقق من الاتصال
  static const List<String> criticalUrls = [
    'https://firebase.googleapis.com',
    'https://fcm.googleapis.com',
    'https://road-helper-fed8f-default-rtdb.europe-west1.firebasedatabase.app',
    'https://www.googleapis.com',
  ];

  /// رسائل خطأ مخصصة للـ Release Mode
  static const Map<String, String> errorMessages = {
    'fcm_token_failed':
        'Failed to obtain FCM token in Release Mode. This might be due to network restrictions or Firebase configuration issues.',
    'firebase_connection_failed':
        'Failed to connect to Firebase in Release Mode. Please check your internet connection.',
    'help_request_failed':
        'Failed to send help request in Release Mode. The request has been saved locally and will be sent when connection is restored.',
    'user_location_failed':
        'Failed to update user location in Release Mode. Location will be updated when connection is restored.',
  };

  /// إعدادات الـ fallback للـ Release Mode
  static const Map<String, dynamic> fallbackSettings = {
    'use_local_storage': true,
    'retry_failed_operations': true,
    'cache_user_data': true,
    'offline_mode_enabled': true,
  };

  /// الحصول على إعدادات مخصصة حسب نوع البناء
  static Map<String, dynamic> getConfigForBuildType() {
    if (isReleaseMode) {
      return {
        'build_type': 'release',
        'debug_mode': false,
        'verbose_logging': false,
        'crash_reporting': true,
        'analytics': true,
        'performance_monitoring': true,
        ...firebaseSettings,
        ...fcmSettings,
        ...networkSettings,
        ...diagnosticsSettings,
        ...fallbackSettings,
      };
    } else {
      return {
        'build_type': 'debug',
        'debug_mode': true,
        'verbose_logging': true,
        'crash_reporting': false,
        'analytics': false,
        'performance_monitoring': false,
      };
    }
  }

  /// طباعة معلومات التكوين
  static void printConfiguration() {
    final config = getConfigForBuildType();
    if (isReleaseMode) {
      // في Release Mode نستخدم debugPrint
      debugPrint('🔧 ========== RELEASE MODE CONFIGURATION ==========');
      debugPrint('🔧 Build Type: ${config['build_type']}');
      debugPrint('🔧 Debug Mode: ${config['debug_mode']}');
      debugPrint('🔧 Firebase Persistence: ${config['persistence_enabled']}');
      debugPrint('🔧 FCM Retry Attempts: ${config['max_retry_attempts']}');
      debugPrint(
          '🔧 Network Timeout: ${config['connection_timeout_seconds']}s');
      debugPrint('🔧 Offline Mode: ${config['offline_mode_enabled']}');
      debugPrint('🔧 ===============================================');
    } else {
      debugPrint('🔧 ========== DEBUG MODE CONFIGURATION ==========');
      debugPrint('🔧 Build Type: ${config['build_type']}');
      debugPrint('🔧 Debug Mode: ${config['debug_mode']}');
      debugPrint('🔧 Verbose Logging: ${config['verbose_logging']}');
      debugPrint('🔧 ===============================================');
    }
  }

  /// التحقق من صحة التكوين
  static bool validateConfiguration() {
    try {
      final config = getConfigForBuildType();

      // التحقق من الإعدادات المطلوبة
      final requiredKeys = ['build_type', 'debug_mode'];
      for (final key in requiredKeys) {
        if (!config.containsKey(key)) {
          debugPrint('❌ ReleaseModeConfig: Missing required key: $key');
          return false;
        }
      }

      debugPrint('✅ ReleaseModeConfig: Configuration validation passed');

      return true;
    } catch (e) {
      debugPrint('❌ ReleaseModeConfig: Configuration validation failed: $e');
      return false;
    }
  }

  /// الحصول على إعداد محدد
  static T? getSetting<T>(String key) {
    final config = getConfigForBuildType();
    return config[key] as T?;
  }

  /// التحقق من تفعيل ميزة معينة
  static bool isFeatureEnabled(String feature) {
    final config = getConfigForBuildType();
    return config[feature] == true;
  }
}
