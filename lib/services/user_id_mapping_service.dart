import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة مركزية لإدارة User ID Mapping بين النظام التقليدي و Firebase
class UserIdMappingService {
  static final UserIdMappingService _instance =
      UserIdMappingService._internal();
  factory UserIdMappingService() => _instance;
  UserIdMappingService._internal();

  final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://road-helper-fed8f-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache للـ mappings
  final Map<String, String> _emailToFirebaseIdCache = {};
  final Map<String, String> _firebaseIdToEmailCache = {};

  /// الحصول على User ID الموحد للمستخدم الحالي
  Future<String?> getCurrentUnifiedUserId() async {
    try {
      // أولاً: تحقق من Firebase Auth (مستخدمو Google)
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        debugPrint(
            '🔥 UserIdMapping: Current user is Firebase user: ${firebaseUser.uid}');
        return firebaseUser.uid;
      }

      // ثانياً: تحقق من المستخدمين التقليديين
      final prefs = await SharedPreferences.getInstance();
      final sqlUserId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');

      if (sqlUserId != null && sqlUserId.isNotEmpty && userEmail != null) {
        // الحصول على Firebase User ID الموحد للمستخدم التقليدي
        final firebaseUserId =
            await getOrCreateFirebaseUserId(userEmail, sqlUserId);
        debugPrint(
            '👤 UserIdMapping: Current user is traditional user: $firebaseUserId (SQL: $sqlUserId)');
        return firebaseUserId;
      }

      debugPrint('❌ UserIdMapping: No current user found');
      return null;
    } catch (e) {
      debugPrint('❌ UserIdMapping: Failed to get current unified user ID: $e');
      return null;
    }
  }

  /// الحصول على أو إنشاء Firebase User ID موحد للمستخدمين التقليديين
  Future<String> getOrCreateFirebaseUserId(
      String email, String sqlUserId) async {
    try {
      // التحقق من الـ cache أولاً
      if (_emailToFirebaseIdCache.containsKey(email)) {
        final cachedId = _emailToFirebaseIdCache[email]!;
        debugPrint('📦 UserIdMapping: Found cached Firebase ID: $cachedId');
        return cachedId;
      }

      // البحث عن mapping موجود في Firebase
      final mappingSnapshot = await _database
          .child('userIdMappings')
          .orderByChild('email')
          .equalTo(email)
          .get();

      if (mappingSnapshot.exists) {
        final mappingData = mappingSnapshot.value as Map<dynamic, dynamic>;
        final firstMapping = mappingData.values.first as Map<dynamic, dynamic>;
        final existingFirebaseId = firstMapping['firebaseUserId'];

        // حفظ في الـ cache
        _emailToFirebaseIdCache[email] = existingFirebaseId;
        _firebaseIdToEmailCache[existingFirebaseId] = email;

        debugPrint(
            '✅ UserIdMapping: Found existing Firebase ID mapping: $existingFirebaseId');
        return existingFirebaseId;
      }

      // إنشاء Firebase User ID جديد للمستخدم التقليدي
      final newFirebaseUserId =
          'traditional_${sqlUserId}_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint(
          '🆕 UserIdMapping: Created new Firebase ID for traditional user: $newFirebaseUserId');

      // حفظ mapping للبحث السريع
      await saveUserIdMapping(email, sqlUserId, newFirebaseUserId);

      return newFirebaseUserId;
    } catch (e) {
      debugPrint(
          '❌ UserIdMapping: Error getting/creating Firebase User ID: $e');
      // fallback إلى الطريقة القديمة
      return email.replaceAll('@', '_').replaceAll('.', '_');
    }
  }

  /// حفظ mapping بين User IDs
  Future<void> saveUserIdMapping(
      String email, String sqlUserId, String firebaseUserId) async {
    try {
      final mappingData = {
        'email': email,
        'sqlUserId': sqlUserId,
        'firebaseUserId': firebaseUserId,
        'userType': 'traditional',
        'createdAt': DateTime.now().toIso8601String(),
        'lastUpdated': ServerValue.timestamp,
      };

      await _database.child('userIdMappings/$firebaseUserId').set(mappingData);

      // حفظ في الـ cache
      _emailToFirebaseIdCache[email] = firebaseUserId;
      _firebaseIdToEmailCache[firebaseUserId] = email;

      debugPrint(
          '✅ UserIdMapping: User ID mapping saved: $email -> $firebaseUserId');
    } catch (e) {
      debugPrint('❌ UserIdMapping: Error saving user ID mapping: $e');
    }
  }

  /// البحث عن Firebase User ID بواسطة Email
  Future<String?> getFirebaseUserIdByEmail(String email) async {
    try {
      // التحقق من الـ cache أولاً
      if (_emailToFirebaseIdCache.containsKey(email)) {
        return _emailToFirebaseIdCache[email];
      }

      // البحث في Firebase
      final mappingSnapshot = await _database
          .child('userIdMappings')
          .orderByChild('email')
          .equalTo(email)
          .get();

      if (mappingSnapshot.exists) {
        final mappingData = mappingSnapshot.value as Map<dynamic, dynamic>;
        final firstMapping = mappingData.values.first as Map<dynamic, dynamic>;
        final firebaseUserId = firstMapping['firebaseUserId'];

        // حفظ في الـ cache
        _emailToFirebaseIdCache[email] = firebaseUserId;
        _firebaseIdToEmailCache[firebaseUserId] = email;

        return firebaseUserId;
      }

      return null;
    } catch (e) {
      debugPrint(
          '❌ UserIdMapping: Error getting Firebase User ID by email: $e');
      return null;
    }
  }

  /// البحث عن Email بواسطة Firebase User ID
  Future<String?> getEmailByFirebaseUserId(String firebaseUserId) async {
    try {
      // التحقق من الـ cache أولاً
      if (_firebaseIdToEmailCache.containsKey(firebaseUserId)) {
        return _firebaseIdToEmailCache[firebaseUserId];
      }

      // البحث في Firebase
      final mappingSnapshot =
          await _database.child('userIdMappings/$firebaseUserId').get();

      if (mappingSnapshot.exists) {
        final mappingData = mappingSnapshot.value as Map<dynamic, dynamic>;
        final email = mappingData['email'];

        // حفظ في الـ cache
        _emailToFirebaseIdCache[email] = firebaseUserId;
        _firebaseIdToEmailCache[firebaseUserId] = email;

        return email;
      }

      return null;
    } catch (e) {
      debugPrint(
          '❌ UserIdMapping: Error getting email by Firebase User ID: $e');
      return null;
    }
  }

  /// تحديث mapping موجود
  Future<void> updateUserIdMapping(
      String firebaseUserId, Map<String, dynamic> updates) async {
    try {
      await _database.child('userIdMappings/$firebaseUserId').update({
        ...updates,
        'lastUpdated': ServerValue.timestamp,
      });

      debugPrint('✅ UserIdMapping: User ID mapping updated: $firebaseUserId');
    } catch (e) {
      debugPrint('❌ UserIdMapping: Error updating user ID mapping: $e');
    }
  }

  /// مسح الـ cache
  void clearCache() {
    _emailToFirebaseIdCache.clear();
    _firebaseIdToEmailCache.clear();
    debugPrint('🧹 UserIdMapping: Cache cleared');
  }

  /// الحصول على معلومات المستخدم الحالي مع User ID الموحد
  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    try {
      // أولاً: تحقق من Firebase Auth (مستخدمو Google)
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        return {
          'userId': firebaseUser.uid,
          'name': firebaseUser.displayName ?? 'Unknown User',
          'email': firebaseUser.email ?? '',
          'isFirebaseUser': true,
          'userType': 'google',
        };
      }

      // ثانياً: تحقق من المستخدمين التقليديين
      final prefs = await SharedPreferences.getInstance();
      final sqlUserId = prefs.getString('user_id');
      final userName = prefs.getString('user_name');
      final userEmail = prefs.getString('user_email');

      if (sqlUserId != null && sqlUserId.isNotEmpty && userEmail != null) {
        // الحصول على Firebase User ID الموحد للمستخدم التقليدي
        final firebaseUserId =
            await getOrCreateFirebaseUserId(userEmail, sqlUserId);

        return {
          'userId': firebaseUserId, // استخدام Firebase User ID الموحد
          'sqlUserId': sqlUserId, // الاحتفاظ بـ SQL ID للمرجع
          'name': userName ?? 'Unknown User',
          'email': userEmail,
          'isFirebaseUser': false,
          'userType': 'traditional',
        };
      }

      return null;
    } catch (e) {
      debugPrint('❌ UserIdMapping: Error getting current user info: $e');
      return null;
    }
  }

  /// التحقق من صحة User ID
  bool isValidUserId(String? userId) {
    if (userId == null || userId.isEmpty) return false;

    // Firebase UIDs عادة ما تكون 28 حرف
    // Traditional User IDs تبدأ بـ "traditional_"
    return userId.length >= 10 &&
        (userId.startsWith('traditional_') || userId.length == 28);
  }
}
