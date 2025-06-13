import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fcm_token_manager.dart';

/// خدمة مخصصة للتعامل مع مصادقة Google
class GoogleAuthService {
  // Singleton pattern
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign In instance with minimal configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  /// تسجيل الدخول باستخدام Google - طريقة جديدة تتجاوز مشكلة PigeonUserDetails
  Future<Map<String, dynamic>?> signInWithGoogleAlternative() async {
    try {
      // تسجيل الخروج أولاً لتجنب مشاكل الجلسات السابقة
      try {
        await _googleSignIn.signOut();
        debugPrint('تم تسجيل الخروج من الجلسة السابقة');
      } catch (e) {
        debugPrint('لا توجد جلسة سابقة للخروج منها: ${e.toString()}');
      }

      // بدء عملية تسجيل الدخول
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // إذا ألغى المستخدم العملية
      if (googleUser == null) {
        debugPrint('تم إلغاء تسجيل الدخول بواسطة المستخدم');
        return null;
      }

      debugPrint('تم تسجيل الدخول بنجاح باستخدام Google: ${googleUser.email}');

      try {
        // الحصول على تفاصيل المصادقة
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // إنشاء بيانات اعتماد Firebase
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // تسجيل الدخول إلى Firebase
        try {
          final UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          debugPrint(
              'تم تسجيل الدخول بنجاح في Firebase: ${userCredential.user?.email}');

          // استخراج بيانات المستخدم
          final userData = _extractUserData(userCredential);

          // حفظ بيانات المستخدم في التخزين المحلي
          await _saveUserDataLocally(userData);

          // مزامنة بيانات المستخدم مع Firebase Database للظهور على الخريطة
          try {
            await _syncUserDataToFirebase(userData);
          } catch (syncError) {
            debugPrint('⚠️ Failed to sync user data to Firebase: $syncError');
            // لا نرمي خطأ هنا لأن تسجيل الدخول نجح
          }

          // Initialize FCM token for Google user
          try {
            await _initializeFCMTokenForGoogleUser(userData['uid']);
          } catch (fcmError) {
            debugPrint('⚠️ Failed to initialize FCM token: $fcmError');
            // Don't throw error as login succeeded
          }

          return userData;
        } catch (firebaseError) {
          debugPrint(
              'خطأ في تسجيل الدخول إلى Firebase: ${firebaseError.toString()}');

          // إذا كان الخطأ هو مشكلة PigeonUserDetails، نحاول الحصول على المستخدم الحالي
          if (firebaseError.toString().contains('PigeonUserDetails')) {
            // التحقق مما إذا كان المستخدم مسجل الدخول بالفعل
            final User? currentUser = _auth.currentUser;
            if (currentUser != null) {
              debugPrint('تم العثور على مستخدم حالي: ${currentUser.email}');

              // استخراج بيانات المستخدم من المستخدم الحالي
              final userData = _extractUserDataFromUser(currentUser);

              // حفظ بيانات المستخدم في التخزين المحلي
              await _saveUserDataLocally(userData);

              // مزامنة بيانات المستخدم مع Firebase Database للظهور على الخريطة
              try {
                await _syncUserDataToFirebase(userData);
              } catch (syncError) {
                debugPrint(
                    '⚠️ Failed to sync user data to Firebase (fallback): $syncError');
                // لا نرمي خطأ هنا لأن تسجيل الدخول نجح
              }

              return userData;
            }
          }

          rethrow;
        }
      } catch (authError) {
        debugPrint(
            'خطأ في الحصول على تفاصيل المصادقة: ${authError.toString()}');
        rethrow;
      }
    } catch (e) {
      debugPrint('خطأ في تسجيل الدخول باستخدام Google: ${e.toString()}');
      rethrow;
    }
  }

  /// استخراج بيانات المستخدم من UserCredential
  Map<String, dynamic> _extractUserData(UserCredential userCredential) {
    final User? user = userCredential.user;
    return _extractUserDataFromUser(user);
  }

  /// استخراج بيانات المستخدم من User
  Map<String, dynamic> _extractUserDataFromUser(User? user) {
    if (user == null) {
      return {
        'email': '',
        'firstName': '',
        'lastName': '',
        'phone': '',
        'photoURL': '',
        'uid': '',
        'isGoogleSignIn': true,
      };
    }

    // استخراج اسم المستخدم وتقسيمه إلى اسم أول واسم أخير
    final String? displayName = user.displayName;
    final List<String> nameParts =
        displayName != null ? displayName.split(' ') : [''];

    // إنشاء خريطة بيانات التسجيل
    return {
      'email': user.email ?? '',
      'firstName': nameParts.isNotEmpty ? nameParts.first : '',
      'lastName': nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
      'phone': user.phoneNumber ?? '',
      'photoURL': user.photoURL ?? '',
      'uid': user.uid,
      'isGoogleSignIn': true,
    };
  }

  /// حفظ بيانات المستخدم في التخزين المحلي
  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // حفظ البيانات الأساسية
      await prefs.setString('logged_in_email', userData['email'] ?? '');
      await prefs.setString('user_email', userData['email'] ?? '');
      await prefs.setBool('is_google_sign_in', true);

      // حفظ معرف المستخدم
      await prefs.setString('user_id', userData['uid'] ?? '');

      // حفظ اسم المستخدم للاستخدام في الإشعارات والدردشة
      final fullName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      if (fullName.isNotEmpty) {
        await prefs.setString('user_name', fullName);
      } else if (userData['email'] != null) {
        // استخدام الجزء الأول من البريد الإلكتروني كاسم احتياطي
        final emailName = userData['email'].toString().split('@')[0];
        await prefs.setString('user_name', emailName);
      }

      // حفظ رقم الهاتف إذا كان متوفراً
      if (userData['phone'] != null &&
          userData['phone'].toString().isNotEmpty) {
        await prefs.setString('user_phone', userData['phone'].toString());
      }

      // حفظ رابط الصورة الشخصية
      if (userData['photoURL'] != null &&
          userData['photoURL'].toString().isNotEmpty) {
        await prefs.setString(
            'user_profile_image', userData['photoURL'].toString());
      }

      // حفظ البيانات الكاملة كـ JSON للاستخدام المستقبلي
      await prefs.setString('google_user_data', jsonEncode(userData));

      debugPrint('✅ Google user data saved locally:');
      debugPrint('   - Email: ${userData['email']}');
      debugPrint('   - Name: $fullName');
      debugPrint('   - UID: ${userData['uid']}');
      debugPrint('   - Phone: ${userData['phone']}');
    } catch (e) {
      debugPrint('❌ خطأ في حفظ بيانات المستخدم: ${e.toString()}');
    }
  }

  /// مزامنة بيانات المستخدم مع Firebase Database للظهور على الخريطة
  Future<void> _syncUserDataToFirebase(Map<String, dynamic> userData) async {
    try {
      debugPrint('🔄 Google Auth: Syncing user data to Firebase Database...');

      final userId = userData['uid'];
      if (userId == null || userId.isEmpty) {
        debugPrint('❌ Google Auth: No user ID found for Firebase sync');
        return;
      }

      // إعداد بيانات المستخدم للحفظ في Firebase
      final firebaseUserData = {
        'userId': userId,
        'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
            .trim(),
        'userName':
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim(),
        'email': userData['email'] ?? '',
        'phone': userData['phone'] ?? '',
        'profileImage': userData['photoURL'] ?? '',
        'profileImageUrl': userData['photoURL'] ?? '',
        'isGoogleUser': true,
        'isOnline': true,
        'isAvailableForHelp': true,
        'userType': 'google',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'lastDataUpdate': DateTime.now().millisecondsSinceEpoch,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // حفظ البيانات في Firebase Database
      final database = FirebaseDatabase.instance;
      await database.ref('users/$userId').update(firebaseUserData);

      debugPrint('✅ Google Auth: User data synced to Firebase successfully');
      debugPrint(
          '📊 Google Auth: Synced data for user: ${firebaseUserData['name']}');
    } catch (e) {
      debugPrint('❌ Google Auth: Error syncing user data to Firebase: $e');
      rethrow; // إعادة رمي الخطأ للتعامل معه في المستوى الأعلى
    }
  }

  /// التحقق مما إذا كان المستخدم مسجل الدخول حاليًا
  bool isUserSignedIn() {
    return _auth.currentUser != null;
  }

  /// الحصول على المستخدم الحالي
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Initialize FCM token for Google user
  Future<void> _initializeFCMTokenForGoogleUser(String userId) async {
    try {
      debugPrint(
          '🔔 GoogleAuthService: Initializing FCM token for user: $userId');

      final fcmTokenManager = FCMTokenManager();

      // Save FCM token for the user
      final tokenSaved = await fcmTokenManager.saveTokenOnLogin();
      if (tokenSaved) {
        debugPrint(
            '✅ GoogleAuthService: FCM token saved successfully for Google user');

        // Validate the token
        final isValid = await fcmTokenManager.validateTokenForUser(userId);
        if (isValid) {
          debugPrint('✅ GoogleAuthService: FCM token validated successfully');
        } else {
          debugPrint(
              '⚠️ GoogleAuthService: FCM token validation failed, attempting refresh');
          await fcmTokenManager.forceTokenRefresh();
        }
      } else {
        debugPrint('❌ GoogleAuthService: Failed to save FCM token');
        // Try force refresh as fallback
        await fcmTokenManager.forceTokenRefresh();
      }
    } catch (e) {
      debugPrint('❌ GoogleAuthService: Error initializing FCM token: $e');
      rethrow;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('خطأ في تسجيل الخروج من Google: ${e.toString()}');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('خطأ في تسجيل الخروج من Firebase: ${e.toString()}');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_in_email');
      await prefs.remove('is_google_sign_in');
    } catch (e) {
      debugPrint('خطأ في حذف بيانات المستخدم: ${e.toString()}');
    }
  }
}
