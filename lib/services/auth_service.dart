import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_helperr/services/api_service.dart';
import 'package:road_helperr/services/profile_service.dart';
import 'package:road_helperr/services/release_mode_user_sync_service.dart';
import 'package:road_helperr/services/accessibility_checker.dart';
import 'package:road_helperr/services/fcm_token_manager.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// خدمة إدارة المصادقة والجلسة
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // مفاتيح SharedPreferences
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _lastLoginTimeKey = 'last_login_time';
  static const String _persistentLoginKey = 'persistent_login_enabled';
  static const String _sosEmergencyContactsKey = 'sos_emergency_contacts';

  /// حفظ بيانات المصادقة بعد تسجيل الدخول
  Future<void> saveAuthData({
    required String token,
    required String userId,
    required String email,
    String? name,
    String? phone,
    String? carModel,
    String? carColor,
    String? plateNumber,
    String? profileImageUrl,
    bool isGoogleSignIn = false, // إضافة parameter لنوع المصادقة
    bool enablePersistentLogin = true, // تمكين الـ persistent login افتراضياً
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // حفظ بيانات المصادقة الأساسية
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userEmailKey, email);
      await prefs.setBool(_isLoggedInKey, true); // هذا مهم جداً!
      await prefs.setBool(
          'is_google_sign_in', isGoogleSignIn); // حفظ نوع المصادقة

      // حفظ معلومات الـ persistent login
      await prefs.setBool(_persistentLoginKey, enablePersistentLogin);
      await prefs.setInt(_lastLoginTimeKey, currentTime);

      // حفظ تاريخ انتهاء صلاحية الـ token (30 يوم من الآن)
      final tokenExpiry = currentTime + (30 * 24 * 60 * 60 * 1000); // 30 يوم
      await prefs.setInt(_tokenExpiryKey, tokenExpiry);

      if (name != null) {
        await prefs.setString(_userNameKey, name);
      }

      // حفظ بيانات المستخدم الإضافية
      if (phone != null) {
        await prefs.setString('user_phone', phone);
      }
      if (carModel != null) {
        await prefs.setString('user_car_model', carModel);
      }
      if (carColor != null) {
        await prefs.setString('user_car_color', carColor);
      }
      if (plateNumber != null) {
        await prefs.setString('user_plate_number', plateNumber);
      }
      if (profileImageUrl != null) {
        await prefs.setString('user_profile_image', profileImageUrl);
      }

      // تعيين حالة تسجيل الدخول
      await prefs.setBool(_isLoggedInKey, true);

      debugPrint('✅ تم حفظ بيانات المصادقة بنجاح');
      debugPrint('✅ Token: ${token.substring(0, min(10, token.length))}...');
      debugPrint('✅ User ID: $userId');
      debugPrint('✅ Email: $email');
      debugPrint('✅ isLoggedIn: true');
      debugPrint('✅ isGoogleSignIn: $isGoogleSignIn');

      // في Release Mode، مزامنة البيانات مع Firebase
      if (kReleaseMode) {
        try {
          final userSyncService = ReleaseModeUserSyncService();
          final syncResult = await userSyncService.syncCurrentUserToFirebase();
          if (syncResult) {
            debugPrint(
                '✅ AuthService: User data synced to Firebase in Release Mode');
          } else {
            debugPrint('⚠️ AuthService: User sync failed in Release Mode');
          }
        } catch (e) {
          debugPrint('❌ AuthService: Error syncing user in Release Mode: $e');
        }
      }

      // Note: Location tracking is now only available for Google authenticated users
      // Traditional users will see a message about this limitation in the app
      debugPrint(
          'ℹ️ AuthService: Traditional user logged in - location tracking not available');
      debugPrint(
          'ℹ️ AuthService: Help request system is only available for Google users');

      // إعادة تعيين حالة جلسة تنبيه الـ accessibility service
      try {
        final accessibilityChecker = AccessibilityChecker();
        await accessibilityChecker.resetSessionState();
        debugPrint('✅ AuthService: Accessibility session state reset on login');
      } catch (e) {
        debugPrint(
            '⚠️ AuthService: Error resetting accessibility session state: $e');
      }
    } catch (e) {
      debugPrint('❌ خطأ في حفظ بيانات المصادقة: $e');
    }
  }

  /// التحقق مما إذا كان المستخدم مسجل الدخول
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      final token = prefs.getString(_tokenKey);
      final userEmail = prefs.getString(_userEmailKey);
      final persistentLoginEnabled =
          prefs.getBool(_persistentLoginKey) ?? false;
      final tokenExpiry = prefs.getInt(_tokenExpiryKey) ?? 0;
      final lastLoginTime = prefs.getInt(_lastLoginTimeKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      debugPrint('=== حالة تسجيل الدخول المحسنة ===');
      debugPrint('isLoggedIn flag: $isLoggedIn');
      debugPrint('token exists: ${token != null}');
      debugPrint('user email: $userEmail');
      debugPrint('persistent login enabled: $persistentLoginEnabled');
      debugPrint(
          'token expiry: ${DateTime.fromMillisecondsSinceEpoch(tokenExpiry)}');
      debugPrint(
          'last login: ${DateTime.fromMillisecondsSinceEpoch(lastLoginTime)}');

      if (token != null) {
        debugPrint('token is not empty: ${token.isNotEmpty}');
        if (token.isNotEmpty) {
          debugPrint(
              'token value: ${token.substring(0, min(10, token.length))}...');
        }
      }

      debugPrint('========================');

      // التحقق من البيانات الأساسية
      final hasBasicData = isLoggedIn &&
          token != null &&
          token.isNotEmpty &&
          userEmail != null &&
          userEmail.isNotEmpty;

      if (!hasBasicData) {
        debugPrint('❌ Missing basic session data');
        await _clearIncompleteSessionData();
        return false;
      }

      // التحقق من صلاحية الـ token
      final isTokenValid = currentTime < tokenExpiry;

      if (!isTokenValid) {
        debugPrint('⚠️ Token expired, checking persistent login...');

        if (persistentLoginEnabled) {
          // إذا كان الـ persistent login مفعل، نحاول تجديد الـ token
          final canRenewToken = await _attemptTokenRenewal();
          if (canRenewToken) {
            debugPrint('✅ Token renewed successfully via persistent login');
            return true;
          } else {
            debugPrint('❌ Token renewal failed, clearing session');
            await _clearExpiredSession();
            return false;
          }
        } else {
          debugPrint('❌ Token expired and persistent login disabled');
          await _clearExpiredSession();
          return false;
        }
      }

      debugPrint('✅ Valid session found - user is logged in');
      return true;
    } catch (e) {
      debugPrint('خطأ في التحقق من حالة تسجيل الدخول: $e');
      return false;
    }
  }

  /// محاولة تجديد الـ token للـ persistent login
  Future<bool> _attemptTokenRenewal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString(_userEmailKey);
      final isGoogleUser = prefs.getBool('is_google_sign_in') ?? false;

      if (userEmail == null || userEmail.isEmpty) {
        debugPrint('❌ Cannot renew token: no user email found');
        return false;
      }

      debugPrint('🔄 Attempting to renew token for: $userEmail');

      // للمستخدمين العاديين، نحاول استخدام remember me credentials
      if (!isGoogleUser) {
        final rememberMeEmail = prefs.getString('remember_me_email');
        final rememberMePassword = prefs.getString('remember_me_password');

        if (rememberMeEmail != null &&
            rememberMeEmail == userEmail &&
            rememberMePassword != null &&
            rememberMePassword.isNotEmpty) {
          debugPrint(
              '🔄 Attempting auto-login with remember me credentials...');

          try {
            // استخدام ApiService لتسجيل الدخول مرة أخرى
            final loginResult =
                await ApiService.login(rememberMeEmail, rememberMePassword);

            if (loginResult['error'] == null && loginResult['token'] != null) {
              // حفظ الـ token الجديد
              await saveAuthData(
                token: loginResult['token'] as String,
                userId: loginResult['user_id']?.toString() ?? '',
                email: rememberMeEmail,
                name: loginResult['name']?.toString(),
                enablePersistentLogin: true,
              );
              debugPrint('✅ Token renewed successfully via auto-login');
              return true;
            }
          } catch (e) {
            debugPrint('❌ Auto-login failed: $e');
          }
        }
      } else {
        // For Google users, try to refresh Firebase Auth token
        debugPrint('🔄 Attempting to refresh Google user token...');
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            // Force refresh the Firebase Auth token
            final idToken = await currentUser.getIdToken(true);
            if (idToken != null && idToken.isNotEmpty) {
              // Update token expiry
              final currentTime = DateTime.now().millisecondsSinceEpoch;
              final newTokenExpiry =
                  currentTime + (30 * 24 * 60 * 60 * 1000); // 30 days
              await prefs.setInt(_tokenExpiryKey, newTokenExpiry);
              await prefs.setString(_tokenKey, idToken);

              debugPrint('✅ Google user token refreshed successfully');

              // Also refresh FCM token for Google user
              try {
                final fcmTokenManager = FCMTokenManager();
                await fcmTokenManager.forceTokenRefresh();
                debugPrint('✅ FCM token also refreshed for Google user');
              } catch (fcmError) {
                debugPrint('⚠️ FCM token refresh failed: $fcmError');
              }

              return true;
            }
          }
        } catch (e) {
          debugPrint('❌ Google token refresh failed: $e');
        }
      }

      debugPrint('❌ Token renewal failed - no valid credentials found');
      return false;
    } catch (e) {
      debugPrint('❌ Error during token renewal: $e');
      return false;
    }
  }

  /// مسح الجلسة المنتهية الصلاحية
  Future<void> _clearExpiredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('🧹 Clearing expired session...');

      // مسح بيانات الـ token المنتهية الصلاحية
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
      await prefs.setBool(_isLoggedInKey, false);

      // الاحتفاظ ببيانات المستخدم الأساسية للـ SOS
      // (email, emergency contacts, etc.) ولكن مسح الـ token

      debugPrint('✅ Expired session cleared');
    } catch (e) {
      debugPrint('❌ Error clearing expired session: $e');
    }
  }

  /// مسح البيانات الجزئية أو الفاسدة
  Future<void> _clearIncompleteSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // التحقق من وجود بيانات جزئية
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      final token = prefs.getString(_tokenKey);
      final userEmail = prefs.getString(_userEmailKey);

      // إذا كانت البيانات غير مكتملة، امسحها
      if (isLoggedIn &&
          (token == null ||
              token.isEmpty ||
              userEmail == null ||
              userEmail.isEmpty)) {
        debugPrint('🧹 Clearing incomplete session data...');
        await prefs.setBool(_isLoggedInKey, false);
        await prefs.remove(_tokenKey);
        await prefs.remove(_userIdKey);
        await prefs.remove(_userEmailKey);
        await prefs.remove(_userNameKey);
        debugPrint('✅ Incomplete session data cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing incomplete session data: $e');
    }
  }

  /// الحصول على رمز المصادقة
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      debugPrint('خطأ في الحصول على رمز المصادقة: $e');
      return null;
    }
  }

  /// الحصول على معرف المستخدم
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      debugPrint('خطأ في الحصول على معرف المستخدم: $e');
      return null;
    }
  }

  /// الحصول على بريد المستخدم الإلكتروني
  Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      debugPrint('خطأ في الحصول على بريد المستخدم: $e');
      return null;
    }
  }

  /// الحصول على اسم المستخدم
  Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userNameKey);
    } catch (e) {
      debugPrint('خطأ في الحصول على اسم المستخدم: $e');
      return null;
    }
  }

  /// الحصول على جميع بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString(_userIdKey);
      final email = prefs.getString(_userEmailKey);
      final name = prefs.getString(_userNameKey);

      if (userId == null || email == null) {
        return null;
      }

      return {
        'userId': userId,
        'email': email,
        'name': name ?? 'Unknown User',
        'phone': prefs.getString('user_phone'),
        'carModel': prefs.getString('user_car_model'),
        'carColor': prefs.getString('user_car_color'),
        'plateNumber': prefs.getString('user_plate_number'),
        'profileImageUrl': prefs.getString('user_profile_image'),
        'isFirebaseUser': prefs.getBool('is_firebase_user') ?? false,
      };
    } catch (e) {
      debugPrint('خطأ في الحصول على بيانات المستخدم: $e');
      return null;
    }
  }

  /// جلب وحفظ بيانات المستخدم الإضافية من الخادم
  Future<void> fetchAndSaveUserProfile(String email) async {
    try {
      debugPrint('🔄 Fetching user profile data for: $email');

      // محاولة جلب البيانات من ProfileService
      final profileService = ProfileService();
      final profileData = await profileService.getProfileData(email);

      final prefs = await SharedPreferences.getInstance();

      // حفظ البيانات الإضافية
      if (profileData.phone != null) {
        await prefs.setString('user_phone', profileData.phone!);
      }
      if (profileData.carModel != null) {
        await prefs.setString('user_car_model', profileData.carModel!);
      }
      if (profileData.carColor != null) {
        await prefs.setString('user_car_color', profileData.carColor!);
      }
      if (profileData.plateNumber != null) {
        await prefs.setString('user_plate_number', profileData.plateNumber!);
      }
      if (profileData.profileImage != null) {
        await prefs.setString('user_profile_image', profileData.profileImage!);
      }

      debugPrint('✅ User profile data saved successfully');
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
    }
  }

  /// تحديد نوع المصادقة الحالي
  Future<bool> isGoogleSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_google_sign_in') ?? false;
    } catch (e) {
      debugPrint('❌ خطأ في تحديد نوع المصادقة: $e');
      return false;
    }
  }

  /// الحصول على نوع المصادقة كنص
  Future<String> getAuthType() async {
    final isGoogle = await isGoogleSignIn();
    return isGoogle ? 'Google' : 'Traditional';
  }

  /// حفظ جهات الاتصال الطارئة للـ SOS
  Future<void> saveEmergencyContacts(List<String> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_sosEmergencyContactsKey, contacts);
      debugPrint('✅ Emergency contacts saved: ${contacts.length} contacts');
    } catch (e) {
      debugPrint('❌ Error saving emergency contacts: $e');
    }
  }

  /// استرجاع جهات الاتصال الطارئة للـ SOS
  Future<List<String>> getEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contacts = prefs.getStringList(_sosEmergencyContactsKey) ?? [];
      debugPrint('📞 Retrieved ${contacts.length} emergency contacts');
      return contacts;
    } catch (e) {
      debugPrint('❌ Error retrieving emergency contacts: $e');
      return [];
    }
  }

  /// التحقق من إمكانية استخدام خدمات SOS (حتى لو انتهت صلاحية الـ token)
  Future<bool> canUseSosServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString(_userEmailKey);
      final emergencyContacts = await getEmergencyContacts();

      // يمكن استخدام SOS إذا كان لدينا email و emergency contacts
      final canUseSos = userEmail != null &&
          userEmail.isNotEmpty &&
          emergencyContacts.isNotEmpty;

      debugPrint('🚨 SOS Services available: $canUseSos');
      debugPrint('   - User email: ${userEmail != null}');
      debugPrint('   - Emergency contacts: ${emergencyContacts.length}');

      return canUseSos;
    } catch (e) {
      debugPrint('❌ Error checking SOS services availability: $e');
      return false;
    }
  }

  /// تمكين/تعطيل الـ persistent login
  Future<void> setPersistentLoginEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_persistentLoginKey, enabled);
      debugPrint('🔄 Persistent login ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('❌ Error setting persistent login: $e');
    }
  }

  /// التحقق من حالة الـ persistent login
  Future<bool> isPersistentLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_persistentLoginKey) ?? true; // مفعل افتراضياً
    } catch (e) {
      debugPrint('❌ Error checking persistent login status: $e');
      return true;
    }
  }

  /// تسجيل الخروج مع مسح كامل للـ session والـ cache
  Future<void> logout() async {
    try {
      debugPrint('🔄 AuthService: Starting complete logout process...');
      final prefs = await SharedPreferences.getInstance();

      // مسح FCM token من Firebase Database قبل حذف user_id
      try {
        final currentUserId = prefs.getString(_userIdKey);
        if (currentUserId != null && currentUserId.isNotEmpty) {
          final database = FirebaseDatabase.instance;
          await database.ref('users/$currentUserId/fcmToken').remove();
          debugPrint(
              '✅ AuthService: FCM token removed from Firebase Database for user: $currentUserId');
        }
      } catch (e) {
        debugPrint(
            '⚠️ AuthService: Could not remove FCM token from Firebase: $e');
      }

      // حذف بيانات المصادقة الأساسية
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userNameKey);
      await prefs.setBool(_isLoggedInKey, false);
      debugPrint('✅ AuthService: Removed basic auth data');

      // حذف بيانات المستخدم الإضافية
      await prefs.remove('user_phone');
      await prefs.remove('user_car_model');
      await prefs.remove('user_car_color');
      await prefs.remove('user_plate_number');
      await prefs.remove('user_profile_image');
      await prefs.remove('is_firebase_user');
      debugPrint('✅ AuthService: Removed user profile data');

      // حفظ بيانات "تذكرني" قبل مسح الـ session
      String? savedRememberMeEmail;
      String? savedRememberMePassword;
      bool? savedRememberMeStatus;
      String? savedEmail;
      String? savedPassword;

      final rememberMeEnabled = prefs.getBool('rememberMe') ?? false;
      if (rememberMeEnabled) {
        savedRememberMeEmail = prefs.getString('remember_me_email');
        savedRememberMePassword = prefs.getString('remember_me_password');
        savedRememberMeStatus = prefs.getBool('rememberMe');
        savedEmail = prefs.getString('email');
        savedPassword = prefs.getString('password');
        debugPrint('💾 AuthService: Saved remember me data before logout');
      }

      // حذف بيانات الـ session القديمة (بدون remember me)
      await prefs.remove('logged_in_email');
      debugPrint('✅ AuthService: Removed session data (kept remember me data)');

      // حذف أي بيانات FCM قديمة
      await prefs.remove('real_user_id');
      await prefs.remove('fcm_token_saved');
      await prefs.remove('last_token_save_time');
      debugPrint('✅ AuthService: Removed FCM related data');

      // حذف بيانات الموقع والنشاط
      await prefs.remove('last_location_lat');
      await prefs.remove('last_location_lng');
      await prefs.remove('location_permission_granted');
      await prefs.remove('last_active_timestamp');
      debugPrint('✅ AuthService: Removed location and activity data');

      // مسح كامل لبيانات الـ accessibility service أولاً
      try {
        final accessibilityChecker = AccessibilityChecker();
        debugPrint('🔄 AuthService: About to clear accessibility data...');
        await accessibilityChecker.debugAccessibilityKeys();
        await accessibilityChecker.clearAllAccessibilityData();
        debugPrint('✅ AuthService: All accessibility data cleared on logout');
        await accessibilityChecker.debugAccessibilityKeys();
      } catch (e) {
        debugPrint('⚠️ AuthService: Error clearing accessibility data: $e');
      }

      // مسح كامل لأي مفاتيح أخرى قد تكون متعلقة بالمستخدم (مع الحفاظ على remember me)
      final allKeys = prefs.getKeys();
      final userRelatedKeys = allKeys
          .where((key) =>
              (key.startsWith('user_') ||
                  key.startsWith('temp_') ||
                  key.startsWith('accessibility_') ||
                  key.contains('session') ||
                  key.contains('cache') ||
                  key.contains('login')) &&
              // استثناء مفاتيح remember me
              !key.startsWith('remember_me_') &&
              key != 'rememberMe' &&
              key != 'email' &&
              key != 'password')
          .toList();

      for (final key in userRelatedKeys) {
        await prefs.remove(key);
        debugPrint('🗑️ AuthService: Removed key: $key');
      }

      // إرجاع بيانات "تذكرني" إذا كانت محفوظة
      if (rememberMeEnabled &&
          savedRememberMeEmail != null &&
          savedRememberMePassword != null) {
        await prefs.setString('remember_me_email', savedRememberMeEmail);
        await prefs.setString('remember_me_password', savedRememberMePassword);
        if (savedRememberMeStatus != null) {
          await prefs.setBool('rememberMe', savedRememberMeStatus);
        }
        if (savedEmail != null) {
          await prefs.setString('email', savedEmail);
        }
        if (savedPassword != null) {
          await prefs.setString('password', savedPassword);
        }
        debugPrint('✅ AuthService: Restored remember me data after logout');
      }

      debugPrint(
          '✅ AuthService: Complete logout successful - all session data cleared');
    } catch (e) {
      debugPrint('❌ AuthService: Error during logout: $e');
    }
  }

  // الحصول على المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // تسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('فشل تسجيل الدخول: $e');
    }
  }

  // تسجيل مستخدم جديد
  Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('فشل إنشاء الحساب: $e');
    }
  }

  // تسجيل الخروج من Firebase مع مسح كامل
  Future<void> signOut() async {
    try {
      debugPrint('🔄 AuthService: Starting Firebase signOut...');

      // تسجيل الخروج من Firebase Auth
      await _auth.signOut();
      debugPrint('✅ AuthService: Firebase Auth signed out');

      // مسح كامل لـ SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ AuthService: SharedPreferences cleared completely');

      debugPrint('✅ AuthService: Firebase signOut completed successfully');
    } catch (e) {
      debugPrint('❌ AuthService: Firebase signOut error: $e');
      throw Exception('فشل تسجيل الخروج: $e');
    }
  }
}
