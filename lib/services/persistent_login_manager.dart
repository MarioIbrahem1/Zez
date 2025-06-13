import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// مدير الـ Persistent Login - للتحكم في إعدادات البقاء مسجل دخول
class PersistentLoginManager {
  static final PersistentLoginManager _instance = PersistentLoginManager._internal();
  factory PersistentLoginManager() => _instance;
  PersistentLoginManager._internal();

  final AuthService _authService = AuthService();

  /// تمكين/تعطيل الـ persistent login
  Future<void> setPersistentLoginEnabled(bool enabled) async {
    try {
      await _authService.setPersistentLoginEnabled(enabled);
      debugPrint('🔄 PersistentLoginManager: ${enabled ? 'Enabled' : 'Disabled'} persistent login');
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error setting persistent login: $e');
    }
  }

  /// التحقق من حالة الـ persistent login
  Future<bool> isPersistentLoginEnabled() async {
    try {
      return await _authService.isPersistentLoginEnabled();
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error checking persistent login status: $e');
      return true; // افتراضياً مفعل
    }
  }

  /// فرض تجديد الـ token إذا كان ممكناً
  Future<bool> forceTokenRenewal() async {
    try {
      debugPrint('🔄 PersistentLoginManager: Forcing token renewal...');
      
      // التحقق من حالة تسجيل الدخول (سيحاول تجديد الـ token تلقائياً)
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        debugPrint('✅ PersistentLoginManager: Token renewal successful');
        return true;
      } else {
        debugPrint('❌ PersistentLoginManager: Token renewal failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error during token renewal: $e');
      return false;
    }
  }

  /// الحصول على معلومات حالة الجلسة
  Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenExpiry = prefs.getInt('token_expiry') ?? 0;
      final lastLoginTime = prefs.getInt('last_login_time') ?? 0;
      final persistentLoginEnabled = await isPersistentLoginEnabled();
      final isLoggedIn = await _authService.isLoggedIn();
      final canUseSos = await _authService.canUseSosServices();
      
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final tokenExpiryDate = DateTime.fromMillisecondsSinceEpoch(tokenExpiry);
      final lastLoginDate = DateTime.fromMillisecondsSinceEpoch(lastLoginTime);
      
      return {
        'isLoggedIn': isLoggedIn,
        'persistentLoginEnabled': persistentLoginEnabled,
        'canUseSos': canUseSos,
        'tokenExpiry': tokenExpiryDate,
        'lastLogin': lastLoginDate,
        'tokenValid': currentTime < tokenExpiry,
        'daysSinceLastLogin': (currentTime - lastLoginTime) / (1000 * 60 * 60 * 24),
        'daysUntilTokenExpiry': (tokenExpiry - currentTime) / (1000 * 60 * 60 * 24),
      };
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error getting session info: $e');
      return {
        'isLoggedIn': false,
        'persistentLoginEnabled': false,
        'canUseSos': false,
        'error': e.toString(),
      };
    }
  }

  /// تنظيف الجلسات المنتهية الصلاحية
  Future<void> cleanupExpiredSessions() async {
    try {
      debugPrint('🧹 PersistentLoginManager: Cleaning up expired sessions...');
      
      final sessionInfo = await getSessionInfo();
      final tokenValid = sessionInfo['tokenValid'] as bool? ?? false;
      final persistentLoginEnabled = sessionInfo['persistentLoginEnabled'] as bool? ?? false;
      
      if (!tokenValid && !persistentLoginEnabled) {
        debugPrint('🧹 PersistentLoginManager: Found expired session without persistent login');
        
        // مسح الجلسة المنتهية الصلاحية
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('token_expiry');
        await prefs.setBool('is_logged_in', false);
        
        debugPrint('✅ PersistentLoginManager: Expired session cleaned up');
      }
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error during cleanup: $e');
    }
  }

  /// إعداد تذكير لتجديد الـ token قبل انتهاء صلاحيته
  Future<void> scheduleTokenRenewalReminder() async {
    try {
      final sessionInfo = await getSessionInfo();
      final daysUntilExpiry = sessionInfo['daysUntilTokenExpiry'] as double? ?? 0;
      
      if (daysUntilExpiry > 0 && daysUntilExpiry <= 7) {
        debugPrint('⚠️ PersistentLoginManager: Token expires in ${daysUntilExpiry.toStringAsFixed(1)} days');
        
        // يمكن إضافة إشعار هنا للمستخدم
        if (daysUntilExpiry <= 3) {
          debugPrint('🚨 PersistentLoginManager: Token expires soon - consider renewal');
        }
      }
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error scheduling renewal reminder: $e');
    }
  }

  /// تصدير إعدادات الجلسة للنسخ الاحتياطي
  Future<Map<String, dynamic>> exportSessionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final emergencyContacts = await _authService.getEmergencyContacts();
      
      return {
        'persistentLoginEnabled': await isPersistentLoginEnabled(),
        'emergencyContacts': emergencyContacts,
        'userEmail': prefs.getString('user_email'),
        'authType': await _authService.getAuthType(),
        'exportDate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error exporting session settings: $e');
      return {'error': e.toString()};
    }
  }

  /// استيراد إعدادات الجلسة من النسخة الاحتياطية
  Future<bool> importSessionSettings(Map<String, dynamic> settings) async {
    try {
      if (settings.containsKey('persistentLoginEnabled')) {
        await setPersistentLoginEnabled(settings['persistentLoginEnabled'] as bool);
      }
      
      if (settings.containsKey('emergencyContacts')) {
        final contacts = List<String>.from(settings['emergencyContacts'] as List);
        await _authService.saveEmergencyContacts(contacts);
      }
      
      debugPrint('✅ PersistentLoginManager: Session settings imported successfully');
      return true;
    } catch (e) {
      debugPrint('❌ PersistentLoginManager: Error importing session settings: $e');
      return false;
    }
  }
}
