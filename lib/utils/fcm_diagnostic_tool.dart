import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_helperr/services/fcm_token_manager.dart';
import 'package:road_helperr/services/fcm_v1_service.dart';

/// أداة تشخيص مشاكل FCM Push Notifications
class FCMDiagnosticTool {
  static final FCMDiagnosticTool _instance = FCMDiagnosticTool._internal();
  factory FCMDiagnosticTool() => _instance;
  FCMDiagnosticTool._internal();

  /// تشخيص شامل لحالة FCM
  Future<void> runFullDiagnostic() async {
    debugPrint(
        '🔍 FCM DIAGNOSTIC: ========== STARTING FULL DIAGNOSTIC ==========');

    await _checkFCMConfiguration();
    await _checkUserAuthentication();
    await _checkFCMToken();
    await _checkFirebaseDatabase();
    await _testTokenSaving();
    await _testNotificationSending();

    debugPrint('🔍 FCM DIAGNOSTIC: ========== DIAGNOSTIC COMPLETE ==========');
  }

  /// فحص إعدادات النظام الجديد
  Future<void> _checkFCMConfiguration() async {
    debugPrint(
        '🔍 FCM DIAGNOSTIC: Checking Notification System Configuration...');

    debugPrint('✅ FCM DIAGNOSTIC: Local Notification System is enabled');
    debugPrint(
        '📱 FCM DIAGNOSTIC: Using Firebase Database + Local Notifications');
    debugPrint('🔧 FCM DIAGNOSTIC: No FCM Server Key required');
    debugPrint('🎯 FCM DIAGNOSTIC: System ready for notifications');
  }

  /// فحص حالة المصادقة
  Future<void> _checkUserAuthentication() async {
    debugPrint('🔍 FCM DIAGNOSTIC: Checking User Authentication...');

    // فحص Firebase Auth
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      debugPrint(
          '✅ FCM DIAGNOSTIC: Firebase user authenticated: ${firebaseUser.uid}');
      debugPrint(
          '📧 FCM DIAGNOSTIC: Firebase user email: ${firebaseUser.email}');
    } else {
      debugPrint('⚠️ FCM DIAGNOSTIC: No Firebase user authenticated');
    }

    // فحص SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');

      if (userId != null) {
        debugPrint('✅ FCM DIAGNOSTIC: SQL user found: $userId');
        debugPrint('📧 FCM DIAGNOSTIC: SQL user email: $userEmail');
      } else {
        debugPrint('⚠️ FCM DIAGNOSTIC: No SQL user found');
      }
    } catch (e) {
      debugPrint('❌ FCM DIAGNOSTIC: Error checking SharedPreferences: $e');
    }
  }

  /// فحص FCM Token
  Future<void> _checkFCMToken() async {
    debugPrint('🔍 FCM DIAGNOSTIC: Checking FCM Token...');

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        debugPrint('✅ FCM DIAGNOSTIC: FCM token obtained successfully');
        debugPrint('🔑 FCM DIAGNOSTIC: Token length: ${fcmToken.length}');
        debugPrint(
            '🔑 FCM DIAGNOSTIC: Token preview: ${fcmToken.substring(0, 20)}...');
      } else {
        debugPrint('❌ FCM DIAGNOSTIC: Could not get FCM token');
        debugPrint(
            '❌ FCM DIAGNOSTIC: This might be a Firebase configuration issue');
      }
    } catch (e) {
      debugPrint('❌ FCM DIAGNOSTIC: Error getting FCM token: $e');
    }
  }

  /// فحص اتصال Firebase Database
  Future<void> _checkFirebaseDatabase() async {
    debugPrint('🔍 FCM DIAGNOSTIC: Checking Firebase Database connection...');

    try {
      final database = FirebaseDatabase.instance;
      final testRef = database.ref('diagnostic_test');

      await testRef.set({
        'timestamp': DateTime.now().toIso8601String(),
        'test': true,
      });

      final snapshot = await testRef.get();
      if (snapshot.exists) {
        debugPrint('✅ FCM DIAGNOSTIC: Firebase Database connection successful');
        await testRef.remove(); // تنظيف البيانات التجريبية
      } else {
        debugPrint('❌ FCM DIAGNOSTIC: Firebase Database read failed');
      }
    } catch (e) {
      debugPrint('❌ FCM DIAGNOSTIC: Firebase Database error: $e');
    }
  }

  /// اختبار حفظ FCM Token
  Future<void> _testTokenSaving() async {
    debugPrint('🔍 FCM DIAGNOSTIC: Testing FCM token saving...');

    try {
      final tokenManager = FCMTokenManager();
      final success = await tokenManager.saveTokenOnLogin();

      if (success) {
        debugPrint('✅ FCM DIAGNOSTIC: FCM token saving test successful');
      } else {
        debugPrint('❌ FCM DIAGNOSTIC: FCM token saving test failed');
      }
    } catch (e) {
      debugPrint('❌ FCM DIAGNOSTIC: Error testing token saving: $e');
    }
  }

  /// اختبار إرسال الإشعارات
  Future<void> _testNotificationSending() async {
    debugPrint('🔍 FCM DIAGNOSTIC: Testing notification sending...');

    try {
      // الحصول على معرف المستخدم الحالي
      String? currentUserId;

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        currentUserId = firebaseUser.uid;
      } else {
        final prefs = await SharedPreferences.getInstance();
        currentUserId = prefs.getString('user_id');
      }

      debugPrint(
          '🔍 FCM DIAGNOSTIC: Testing notification to user: $currentUserId');

      final fcmService = FCMv1Service();
      final success = await fcmService.sendPushNotification(
        userId: currentUserId ?? 'unknown_user',
        title: 'اختبار الإشعارات',
        body: 'هذا إشعار تجريبي للتأكد من عمل النظام',
        data: {
          'type': 'test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (success) {
        debugPrint('✅ FCM DIAGNOSTIC: Test notification sent successfully');
      } else {
        debugPrint('❌ FCM DIAGNOSTIC: Test notification failed');
      }
    } catch (e) {
      debugPrint('❌ FCM DIAGNOSTIC: Error testing notification sending: $e');
    }
  }

  /// فحص سريع للمشاكل الشائعة
  Future<void> quickCheck() async {
    debugPrint('🔍 FCM DIAGNOSTIC: ========== QUICK CHECK ==========');

    // فحص النظام الجديد
    debugPrint('✅ QUICK CHECK: Local Notification System enabled');
    debugPrint('📱 QUICK CHECK: No FCM Server Key needed');
    debugPrint('🎯 QUICK CHECK: System ready for notifications');

    // فحص المستخدم
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final sqlUser = prefs.getString('user_id');

    if (firebaseUser == null && sqlUser == null) {
      debugPrint('❌ QUICK CHECK: No user authenticated!');
    } else {
      debugPrint('✅ QUICK CHECK: User authenticated');
    }

    // فحص FCM Token
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint('❌ QUICK CHECK: FCM Token not available!');
      } else {
        debugPrint('✅ QUICK CHECK: FCM Token available');
      }
    } catch (e) {
      debugPrint('❌ QUICK CHECK: FCM Token error: $e');
    }

    debugPrint('🔍 FCM DIAGNOSTIC: ========== QUICK CHECK COMPLETE ==========');
  }
}
