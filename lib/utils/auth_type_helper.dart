import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// مساعد لتحديد نوع المصادقة وإدارة APIs المناسبة
class AuthTypeHelper {
  /// تحديد نوع المصادقة الحالي
  static Future<bool> isGoogleSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_google_sign_in') ?? false;
    } catch (e) {
      debugPrint('❌ خطأ في تحديد نوع المصادقة: $e');
      return false;
    }
  }

  /// الحصول على نوع المصادقة كنص
  static Future<String> getAuthType() async {
    final isGoogle = await isGoogleSignIn();
    return isGoogle ? 'Google' : 'Traditional';
  }

  /// الحصول على API endpoint المناسب لجلب البيانات
  static Future<String> getDataApiEndpoint(String baseUrl) async {
    final isGoogle = await isGoogleSignIn();
    if (isGoogle) {
      return '$baseUrl/datagoogle'; // يجلب البيانات والصور معاً
    } else {
      return '$baseUrl/data';
    }
  }

  /// الحصول على API endpoint المناسب لجلب الصور
  static Future<String> getImagesApiEndpoint(String baseUrl) async {
    final isGoogle = await isGoogleSignIn();
    if (isGoogle) {
      return '$baseUrl/datagoogle'; // نفس endpoint البيانات
    } else {
      return '$baseUrl/images'; // endpoint منفصل للصور
    }
  }

  /// الحصول على API endpoint المناسب للتسجيل
  static Future<String> getSignupApiEndpoint(String baseUrl) async {
    final isGoogle = await isGoogleSignIn();
    if (isGoogle) {
      return '$baseUrl/SignUpGoogle';
    } else {
      return '$baseUrl/register';
    }
  }

  /// الحصول على API endpoint المناسب لتحديث البيانات
  static Future<String> getUpdateApiEndpoint(String baseUrl) async {
    final isGoogle = await isGoogleSignIn();
    if (isGoogle) {
      return '$baseUrl/updateusergoogle';
    } else {
      return '$baseUrl/updateuser';
    }
  }

  /// الحصول على HTTP method المناسب لجلب البيانات
  static Future<String> getDataApiMethod() async {
    final isGoogle = await isGoogleSignIn();
    return isGoogle ? 'GET' : 'POST';
  }

  /// طباعة معلومات المصادقة الحالية للتشخيص
  static Future<void> printAuthInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGoogle = prefs.getBool('is_google_sign_in') ?? false;
      final email = prefs.getString('logged_in_email') ?? 'غير محدد';
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      debugPrint('=== معلومات المصادقة الحالية ===');
      debugPrint('نوع المصادقة: ${isGoogle ? 'Google' : 'Traditional'}');
      debugPrint('البريد الإلكتروني: $email');
      debugPrint('حالة تسجيل الدخول: $isLoggedIn');
      debugPrint('is_google_sign_in: $isGoogle');
      debugPrint('================================');
    } catch (e) {
      debugPrint('❌ خطأ في طباعة معلومات المصادقة: $e');
    }
  }

  /// تعيين نوع المصادقة يدوياً (للاختبار أو الإصلاح)
  static Future<void> setAuthType(bool isGoogleSignIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_google_sign_in', isGoogleSignIn);
      debugPrint(
          '✅ تم تعيين نوع المصادقة: ${isGoogleSignIn ? 'Google' : 'Traditional'}');
    } catch (e) {
      debugPrint('❌ خطأ في تعيين نوع المصادقة: $e');
    }
  }

  /// التحقق من صحة إعدادات المصادقة
  static Future<bool> validateAuthSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final email = prefs.getString('logged_in_email');
      final hasAuthType = prefs.containsKey('is_google_sign_in');

      if (!isLoggedIn) {
        debugPrint('⚠️ المستخدم غير مسجل دخول');
        return false;
      }

      if (email == null || email.isEmpty) {
        debugPrint('⚠️ البريد الإلكتروني غير محدد');
        return false;
      }

      if (!hasAuthType) {
        debugPrint('⚠️ نوع المصادقة غير محدد - سيتم افتراض Traditional');
        await setAuthType(false); // افتراض Traditional
        return true;
      }

      debugPrint('✅ إعدادات المصادقة صحيحة');
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من إعدادات المصادقة: $e');
      return false;
    }
  }
}
