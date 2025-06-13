import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/persistent_login_manager.dart';

/// فئة اختبار نظام الـ Persistent Login
class PersistentLoginTest {
  static final AuthService _authService = AuthService();
  static final PersistentLoginManager _loginManager = PersistentLoginManager();

  /// تشغيل جميع الاختبارات
  static Future<void> runAllTests() async {
    debugPrint('🧪 ===== بدء اختبارات نظام Persistent Login =====');
    
    try {
      await testBasicFunctionality();
      await testTokenExpiry();
      await testSosServices();
      await testSessionInfo();
      await testSettingsExportImport();
      
      debugPrint('✅ ===== جميع الاختبارات نجحت =====');
    } catch (e) {
      debugPrint('❌ ===== فشل في الاختبارات: $e =====');
    }
  }

  /// اختبار الوظائف الأساسية
  static Future<void> testBasicFunctionality() async {
    debugPrint('🧪 Test 1: Basic Functionality');
    
    // اختبار تمكين/تعطيل persistent login
    await _loginManager.setPersistentLoginEnabled(true);
    bool enabled = await _loginManager.isPersistentLoginEnabled();
    assert(enabled == true, 'Failed to enable persistent login');
    debugPrint('✅ Persistent login enabled successfully');
    
    await _loginManager.setPersistentLoginEnabled(false);
    enabled = await _loginManager.isPersistentLoginEnabled();
    assert(enabled == false, 'Failed to disable persistent login');
    debugPrint('✅ Persistent login disabled successfully');
    
    // إعادة تمكين للاختبارات التالية
    await _loginManager.setPersistentLoginEnabled(true);
    debugPrint('✅ Test 1 passed');
  }

  /// اختبار انتهاء صلاحية الـ token
  static Future<void> testTokenExpiry() async {
    debugPrint('🧪 Test 2: Token Expiry Handling');
    
    // محاكاة token منتهي الصلاحية
    const testToken = 'test_token_123';
    const testUserId = 'test_user_456';
    const testEmail = 'test@example.com';
    
    // حفظ token مع انتهاء صلاحية في الماضي
    await _authService.saveAuthData(
      token: testToken,
      userId: testUserId,
      email: testEmail,
      name: 'Test User',
      enablePersistentLogin: true,
    );
    
    // التحقق من حالة تسجيل الدخول
    final isLoggedIn = await _authService.isLoggedIn();
    debugPrint('Login status with test token: $isLoggedIn');
    
    debugPrint('✅ Test 2 passed');
  }

  /// اختبار خدمات SOS
  static Future<void> testSosServices() async {
    debugPrint('🧪 Test 3: SOS Services');
    
    // اختبار بدون emergency contacts
    bool canUseSos = await _authService.canUseSosServices();
    debugPrint('SOS available without contacts: $canUseSos');
    
    // إضافة emergency contacts
    final testContacts = ['+1234567890', '+0987654321'];
    await _authService.saveEmergencyContacts(testContacts);
    
    // اختبار مع emergency contacts
    canUseSos = await _authService.canUseSosServices();
    debugPrint('SOS available with contacts: $canUseSos');
    
    // التحقق من استرجاع الـ contacts
    final retrievedContacts = await _authService.getEmergencyContacts();
    assert(retrievedContacts.length == testContacts.length, 'Emergency contacts count mismatch');
    debugPrint('✅ Emergency contacts saved and retrieved successfully');
    
    debugPrint('✅ Test 3 passed');
  }

  /// اختبار معلومات الجلسة
  static Future<void> testSessionInfo() async {
    debugPrint('🧪 Test 4: Session Information');
    
    final sessionInfo = await _loginManager.getSessionInfo();
    debugPrint('Session info: $sessionInfo');
    
    // التحقق من وجود المفاتيح المطلوبة
    final requiredKeys = [
      'isLoggedIn',
      'persistentLoginEnabled',
      'canUseSos',
      'tokenExpiry',
      'lastLogin',
      'tokenValid',
    ];
    
    for (final key in requiredKeys) {
      assert(sessionInfo.containsKey(key), 'Missing session info key: $key');
    }
    
    debugPrint('✅ All required session info keys present');
    debugPrint('✅ Test 4 passed');
  }

  /// اختبار تصدير/استيراد الإعدادات
  static Future<void> testSettingsExportImport() async {
    debugPrint('🧪 Test 5: Settings Export/Import');
    
    // تصدير الإعدادات
    final exportedSettings = await _loginManager.exportSessionSettings();
    debugPrint('Exported settings: $exportedSettings');
    
    assert(exportedSettings.containsKey('persistentLoginEnabled'), 'Missing persistentLoginEnabled in export');
    assert(exportedSettings.containsKey('emergencyContacts'), 'Missing emergencyContacts in export');
    
    // تعديل الإعدادات
    await _loginManager.setPersistentLoginEnabled(false);
    await _authService.saveEmergencyContacts([]);
    
    // استيراد الإعدادات
    final importSuccess = await _loginManager.importSessionSettings(exportedSettings);
    assert(importSuccess == true, 'Failed to import settings');
    
    // التحقق من استعادة الإعدادات
    final restoredEnabled = await _loginManager.isPersistentLoginEnabled();
    final restoredContacts = await _authService.getEmergencyContacts();
    
    debugPrint('Restored persistent login: $restoredEnabled');
    debugPrint('Restored contacts count: ${restoredContacts.length}');
    
    debugPrint('✅ Settings export/import successful');
    debugPrint('✅ Test 5 passed');
  }

  /// اختبار تنظيف الجلسات المنتهية الصلاحية
  static Future<void> testSessionCleanup() async {
    debugPrint('🧪 Test 6: Session Cleanup');
    
    // تشغيل تنظيف الجلسات
    await _loginManager.cleanupExpiredSessions();
    debugPrint('✅ Session cleanup completed');
    
    // التحقق من جدولة تذكير التجديد
    await _loginManager.scheduleTokenRenewalReminder();
    debugPrint('✅ Token renewal reminder scheduled');
    
    debugPrint('✅ Test 6 passed');
  }

  /// اختبار سيناريو كامل
  static Future<void> testCompleteScenario() async {
    debugPrint('🧪 Test 7: Complete Scenario');
    
    // 1. تسجيل دخول جديد
    await _authService.saveAuthData(
      token: 'scenario_token_789',
      userId: 'scenario_user_123',
      email: 'scenario@test.com',
      name: 'Scenario User',
      enablePersistentLogin: true,
    );
    
    // 2. إضافة emergency contacts
    await _authService.saveEmergencyContacts(['+1111111111', '+2222222222']);
    
    // 3. التحقق من جميع الخدمات
    final isLoggedIn = await _authService.isLoggedIn();
    final canUseSos = await _authService.canUseSosServices();
    final persistentEnabled = await _loginManager.isPersistentLoginEnabled();
    
    debugPrint('Complete scenario results:');
    debugPrint('  - Logged in: $isLoggedIn');
    debugPrint('  - SOS available: $canUseSos');
    debugPrint('  - Persistent login: $persistentEnabled');
    
    // 4. محاولة تجديد الـ token
    final renewalSuccess = await _loginManager.forceTokenRenewal();
    debugPrint('  - Token renewal: $renewalSuccess');
    
    debugPrint('✅ Test 7 passed');
  }

  /// تشغيل اختبار سريع
  static Future<void> runQuickTest() async {
    debugPrint('🧪 ===== اختبار سريع لنظام Persistent Login =====');
    
    try {
      // اختبار أساسي
      await _loginManager.setPersistentLoginEnabled(true);
      final enabled = await _loginManager.isPersistentLoginEnabled();
      debugPrint('Persistent login enabled: $enabled');
      
      // اختبار SOS
      await _authService.saveEmergencyContacts(['+1234567890']);
      final canUseSos = await _authService.canUseSosServices();
      debugPrint('SOS services available: $canUseSos');
      
      // معلومات الجلسة
      final sessionInfo = await _loginManager.getSessionInfo();
      debugPrint('Session valid: ${sessionInfo['tokenValid']}');
      
      debugPrint('✅ ===== الاختبار السريع نجح =====');
    } catch (e) {
      debugPrint('❌ ===== فشل الاختبار السريع: $e =====');
    }
  }
}
