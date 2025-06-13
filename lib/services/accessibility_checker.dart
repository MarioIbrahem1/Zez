import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accessibility_service.dart';

/// خدمة للتحقق الدوري من حالة Accessibility Service
class AccessibilityChecker {
  static final AccessibilityChecker _instance =
      AccessibilityChecker._internal();
  factory AccessibilityChecker() => _instance;
  AccessibilityChecker._internal();

  Timer? _periodicTimer;
  bool _isChecking = false;

  // Callbacks
  Function(bool isEnabled)? onAccessibilityStatusChanged;
  VoidCallback? onAccessibilityDisabled;
  VoidCallback? onAccessibilityEnabled;

  static const String _lastCheckKey = 'accessibility_last_check';
  static const String _userDismissedKey = 'accessibility_user_dismissed';
  static const String _reminderCountKey = 'accessibility_reminder_count';
  static const String _sessionNotificationShownKey =
      'accessibility_session_notification_shown';

  /// بدء التحقق الدوري
  Future<void> startPeriodicCheck(
      {Duration interval = const Duration(minutes: 5)}) async {
    debugPrint(
        '🔍 AccessibilityChecker: Starting periodic check every ${interval.inMinutes} minutes');

    // التحقق الفوري
    await _performCheck();

    // بدء التحقق الدوري
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (timer) async {
      await _performCheck();
    });
  }

  /// إيقاف التحقق الدوري
  void stopPeriodicCheck() {
    debugPrint('🔍 AccessibilityChecker: Stopping periodic check');
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// التحقق الفوري من الحالة
  Future<bool> checkNow() async {
    return await _performCheck();
  }

  /// التحقق الداخلي
  Future<bool> _performCheck() async {
    if (_isChecking) return false;

    _isChecking = true;

    try {
      final isEnabled =
          await AccessibilityService.isAccessibilityServiceEnabled();
      final prefs = await SharedPreferences.getInstance();

      // حفظ وقت آخر فحص
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      // استدعاء callbacks
      onAccessibilityStatusChanged?.call(isEnabled);

      if (isEnabled) {
        debugPrint('✅ AccessibilityChecker: Service is enabled');
        onAccessibilityEnabled?.call();

        // مسح عداد التذكيرات عند التفعيل
        await prefs.remove(_reminderCountKey);
        await prefs.remove(_userDismissedKey);
      } else {
        debugPrint('⚠️ AccessibilityChecker: Service is disabled');
        onAccessibilityDisabled?.call();

        // زيادة عداد التذكيرات
        final reminderCount = prefs.getInt(_reminderCountKey) ?? 0;
        await prefs.setInt(_reminderCountKey, reminderCount + 1);
      }

      return isEnabled;
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error during check: $e');
      return false;
    } finally {
      _isChecking = false;
    }
  }

  /// التحقق من ضرورة إظهار التذكير
  Future<bool> shouldShowReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint(
          '🔍 AccessibilityChecker: Checking if should show reminder...');

      // التحقق من حالة الخدمة أولاً
      final isEnabled =
          await AccessibilityService.isAccessibilityServiceEnabled();
      debugPrint('🔍 AccessibilityChecker: Service enabled: $isEnabled');
      if (isEnabled) return false;

      // التحقق من إذا كان التنبيه تم عرضه في هذه الجلسة
      final sessionNotificationShown =
          prefs.getBool(_sessionNotificationShownKey) ?? false;
      debugPrint(
          '🔍 AccessibilityChecker: Session notification shown: $sessionNotificationShown');
      if (sessionNotificationShown) {
        debugPrint(
            '🔇 AccessibilityChecker: Notification already shown in this session');
        return false;
      }

      // التحقق من إذا كان المستخدم رفض التذكير نهائياً
      final userDismissed = prefs.getBool(_userDismissedKey) ?? false;
      final reminderCount = prefs.getInt(_reminderCountKey) ?? 0;
      debugPrint(
          '🔍 AccessibilityChecker: User dismissed: $userDismissed, count: $reminderCount');

      // إظهار التذكير في الحالات التالية:
      // 1. الخدمة غير مفعلة
      // 2. لم يتم عرض التنبيه في هذه الجلسة
      // 3. المستخدم لم يرفض التذكير نهائياً

      if (!userDismissed) {
        debugPrint(
            '📢 AccessibilityChecker: Should show reminder (count: $reminderCount, session: false)');
        return true;
      }

      debugPrint(
          '🔇 AccessibilityChecker: Should not show reminder (dismissed: $userDismissed, count: $reminderCount, session: $sessionNotificationShown)');
      return false;
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error checking reminder status: $e');
      return false;
    }
  }

  /// تسجيل أن المستخدم رفض التذكير
  Future<void> markUserDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userDismissedKey, true);
      // أيضاً تسجيل أن التنبيه تم عرضه في هذه الجلسة
      await prefs.setBool(_sessionNotificationShownKey, true);
      debugPrint('🔇 AccessibilityChecker: User dismissed reminder');
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error marking user dismissed: $e');
    }
  }

  /// تسجيل أن التنبيه تم عرضه في هذه الجلسة
  Future<void> markSessionNotificationShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionNotificationShownKey, true);
      debugPrint(
          '📢 AccessibilityChecker: Session notification marked as shown');
    } catch (e) {
      debugPrint(
          '❌ AccessibilityChecker: Error marking session notification: $e');
    }
  }

  /// إعادة تعيين حالة الجلسة (يتم استدعاؤها عند تسجيل الدخول/الخروج)
  Future<void> resetSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // التحقق من القيمة قبل المسح
      final currentValue = prefs.getBool(_sessionNotificationShownKey) ?? false;
      debugPrint(
          '🔄 AccessibilityChecker: Current session state before reset: $currentValue');

      await prefs.remove(_sessionNotificationShownKey);

      // التحقق من أن القيمة اتمسحت
      final afterValue = prefs.getBool(_sessionNotificationShownKey) ?? false;
      debugPrint(
          '🔄 AccessibilityChecker: Session state after reset: $afterValue');
      debugPrint('🔄 AccessibilityChecker: Session state reset completed');
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error resetting session state: $e');
    }
  }

  /// مسح كامل لكل بيانات الـ accessibility (للـ logout الكامل)
  Future<void> clearAllAccessibilityData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint(
          '🧹 AccessibilityChecker: Starting to clear all accessibility data...');

      // التحقق من القيم قبل المسح
      final sessionShown = prefs.getBool(_sessionNotificationShownKey) ?? false;
      final userDismissed = prefs.getBool(_userDismissedKey) ?? false;
      final reminderCount = prefs.getInt(_reminderCountKey) ?? 0;
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;

      debugPrint(
          '🧹 Before clearing - Session shown: $sessionShown, User dismissed: $userDismissed, Count: $reminderCount, Last check: $lastCheck');

      await prefs.remove(_sessionNotificationShownKey);
      await prefs.remove(_userDismissedKey);
      await prefs.remove(_reminderCountKey);
      await prefs.remove(_lastCheckKey);

      // التحقق من أن القيم اتمسحت
      final sessionShownAfter =
          prefs.getBool(_sessionNotificationShownKey) ?? false;
      final userDismissedAfter = prefs.getBool(_userDismissedKey) ?? false;
      final reminderCountAfter = prefs.getInt(_reminderCountKey) ?? 0;
      final lastCheckAfter = prefs.getInt(_lastCheckKey) ?? 0;

      debugPrint(
          '🧹 After clearing - Session shown: $sessionShownAfter, User dismissed: $userDismissedAfter, Count: $reminderCountAfter, Last check: $lastCheckAfter');
      debugPrint(
          '🧹 AccessibilityChecker: All accessibility data cleared successfully');
    } catch (e) {
      debugPrint(
          '❌ AccessibilityChecker: Error clearing accessibility data: $e');
    }
  }

  /// التحقق من حالة الجلسة الحالية
  Future<bool> isSessionNotificationShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isShown = prefs.getBool(_sessionNotificationShownKey) ?? false;
      debugPrint(
          '🔍 AccessibilityChecker: Session notification shown status: $isShown');
      return isShown;
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error checking session status: $e');
      return false;
    }
  }

  /// عرض جميع الـ accessibility keys الموجودة في SharedPreferences (للتشخيص)
  Future<void> debugAccessibilityKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final accessibilityKeys =
          allKeys.where((key) => key.startsWith('accessibility_')).toList();

      debugPrint(
          '🔍 AccessibilityChecker: All accessibility keys in SharedPreferences:');
      if (accessibilityKeys.isEmpty) {
        debugPrint('🔍 AccessibilityChecker: No accessibility keys found');
      } else {
        for (final key in accessibilityKeys) {
          final value = prefs.get(key);
          debugPrint('🔍 AccessibilityChecker: $key = $value');
        }
      }
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error debugging keys: $e');
    }
  }

  /// إعادة تعيين حالة التذكيرات (للاختبار أو إعادة التعيين)
  Future<void> resetReminderState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDismissedKey);
      await prefs.remove(_reminderCountKey);
      debugPrint('🔄 AccessibilityChecker: Reminder state reset');
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error resetting reminder state: $e');
    }
  }

  /// الحصول على إحصائيات التذكيرات
  Future<Map<String, dynamic>> getReminderStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final userDismissed = prefs.getBool(_userDismissedKey) ?? false;
      final reminderCount = prefs.getInt(_reminderCountKey) ?? 0;
      final sessionNotificationShown =
          prefs.getBool(_sessionNotificationShownKey) ?? false;
      final isEnabled =
          await AccessibilityService.isAccessibilityServiceEnabled();

      return {
        'isEnabled': isEnabled,
        'lastCheck': DateTime.fromMillisecondsSinceEpoch(lastCheck),
        'userDismissed': userDismissed,
        'reminderCount': reminderCount,
        'sessionNotificationShown': sessionNotificationShown,
        'shouldShowReminder': await shouldShowReminder(),
      };
    } catch (e) {
      debugPrint('❌ AccessibilityChecker: Error getting reminder stats: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// التحقق عند بدء التطبيق
  Future<bool> checkOnAppStart() async {
    debugPrint('🚀 AccessibilityChecker: Checking on app start');

    final isEnabled = await _performCheck();

    if (!isEnabled) {
      final shouldShow = await shouldShowReminder();
      if (shouldShow) {
        debugPrint('📢 AccessibilityChecker: App start - should show reminder');
      } else {
        debugPrint(
            '🔇 AccessibilityChecker: App start - should not show reminder');
      }
    }

    return isEnabled;
  }

  /// تنظيف الموارد
  void dispose() {
    debugPrint('🧹 AccessibilityChecker: Disposing');
    stopPeriodicCheck();
    onAccessibilityStatusChanged = null;
    onAccessibilityDisabled = null;
    onAccessibilityEnabled = null;
  }
}
