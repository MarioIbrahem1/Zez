import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:road_helperr/services/profile_service.dart';
import 'package:road_helperr/services/fcm_token_manager.dart';

/// خدمة مخصصة لحل مشاكل المستخدمين المختلطين في Release Mode
class ReleaseModeUserSyncService {
  static final ReleaseModeUserSyncService _instance =
      ReleaseModeUserSyncService._internal();
  factory ReleaseModeUserSyncService() => _instance;
  ReleaseModeUserSyncService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// مزامنة بيانات المستخدم الحالي مع Firebase Database
  Future<bool> syncCurrentUserToFirebase() async {
    try {
      if (kReleaseMode) {
        print('🔄 ReleaseModeUserSync: Starting user sync in Release Mode...');
      } else {
        debugPrint(
            '🔄 ReleaseModeUserSync: Starting user sync in Debug Mode...');
      }

      // الحصول على معلومات المستخدم الحالي
      final userInfo = await _getCurrentUserInfo();
      if (userInfo == null) {
        if (kReleaseMode) {
          print('❌ ReleaseModeUserSync: No user info found');
        } else {
          debugPrint('❌ ReleaseModeUserSync: No user info found');
        }
        return false;
      }

      // مزامنة البيانات مع Firebase
      await _syncUserDataToFirebase(userInfo);

      if (kReleaseMode) {
        print('✅ ReleaseModeUserSync: User sync completed successfully');
      } else {
        debugPrint('✅ ReleaseModeUserSync: User sync completed successfully');
      }

      return true;
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: User sync failed: $e');
      } else {
        debugPrint('❌ ReleaseModeUserSync: User sync failed: $e');
      }
      return false;
    }
  }

  /// الحصول على معلومات المستخدم الحالي من جميع المصادر
  Future<Map<String, dynamic>?> _getCurrentUserInfo() async {
    try {
      // أولاً: تحقق من Firebase Auth (Google users)
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        if (kReleaseMode) {
          print(
              '👤 ReleaseModeUserSync: Found Firebase user: ${firebaseUser.uid}');
        } else {
          debugPrint(
              '👤 ReleaseModeUserSync: Found Firebase user: ${firebaseUser.uid}');
        }

        return await _getFirebaseUserInfo(firebaseUser);
      }

      // ثانياً: تحقق من SharedPreferences (SQL users)
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null && userId.isNotEmpty) {
        if (kReleaseMode) {
          print('👤 ReleaseModeUserSync: Found SQL user: $userId');
        } else {
          debugPrint('👤 ReleaseModeUserSync: Found SQL user: $userId');
        }

        return await _getSQLUserInfo(prefs, userId);
      }

      return null;
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: Error getting user info: $e');
      } else {
        debugPrint('❌ ReleaseModeUserSync: Error getting user info: $e');
      }
      return null;
    }
  }

  /// الحصول على معلومات Firebase user
  Future<Map<String, dynamic>> _getFirebaseUserInfo(User firebaseUser) async {
    final userInfo = {
      'userId': firebaseUser.uid,
      'name': firebaseUser.displayName ?? 'Google User',
      'email': firebaseUser.email ?? '',
      'phone': firebaseUser.phoneNumber,
      'profileImageUrl': firebaseUser.photoURL,
      'userType': 'firebase',
      'isOnline': true,
      'isAvailableForHelp': true,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    };

    // محاولة الحصول على بيانات إضافية من ProfileService
    try {
      final profileService = ProfileService();
      final profileData = await profileService
          .getProfileData(firebaseUser.email!, useCache: true);

      userInfo.addAll({
        'carModel': profileData.carModel,
        'carColor': profileData.carColor,
        'plateNumber': profileData.plateNumber,
        'phone': profileData.phone ?? firebaseUser.phoneNumber,
      });
    } catch (e) {
      if (kReleaseMode) {
        print(
            '⚠️ ReleaseModeUserSync: Could not get profile data for Firebase user: $e');
      } else {
        debugPrint(
            '⚠️ ReleaseModeUserSync: Could not get profile data for Firebase user: $e');
      }
    }

    return userInfo;
  }

  /// الحصول على معلومات SQL user
  Future<Map<String, dynamic>> _getSQLUserInfo(
      SharedPreferences prefs, String userId) async {
    final userInfo = {
      'userId': userId,
      'name': prefs.getString('user_name') ?? 'SQL User',
      'email': prefs.getString('user_email') ?? '',
      'phone': prefs.getString('user_phone'),
      'carModel': prefs.getString('user_car_model'),
      'carColor': prefs.getString('user_car_color'),
      'plateNumber': prefs.getString('user_plate_number'),
      'profileImageUrl': prefs.getString('user_profile_image'),
      'userType': 'sql',
      'isOnline': true,
      'isAvailableForHelp': true,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    };

    // محاولة الحصول على بيانات إضافية من ProfileService
    try {
      final email = userInfo['email'] as String?;
      if (email != null && email.isNotEmpty) {
        final profileService = ProfileService();
        final profileData =
            await profileService.getProfileData(email, useCache: true);

        // تحديث البيانات المفقودة
        userInfo['carModel'] ??= profileData.carModel;
        userInfo['carColor'] ??= profileData.carColor;
        userInfo['plateNumber'] ??= profileData.plateNumber;
        userInfo['phone'] ??= profileData.phone;
        // userInfo['profileImageUrl'] ??= profileData.profileImageUrl; // ProfileData doesn't have this field

        // حفظ البيانات المحدثة في SharedPreferences
        await _saveUpdatedDataToPrefs(prefs, profileData);
      }
    } catch (e) {
      if (kReleaseMode) {
        print(
            '⚠️ ReleaseModeUserSync: Could not get profile data for SQL user: $e');
      } else {
        debugPrint(
            '⚠️ ReleaseModeUserSync: Could not get profile data for SQL user: $e');
      }
    }

    return userInfo;
  }

  /// حفظ البيانات المحدثة في SharedPreferences
  Future<void> _saveUpdatedDataToPrefs(
      SharedPreferences prefs, dynamic profileData) async {
    try {
      if (profileData.carModel != null) {
        await prefs.setString('user_car_model', profileData.carModel!);
      }
      if (profileData.carColor != null) {
        await prefs.setString('user_car_color', profileData.carColor!);
      }
      if (profileData.plateNumber != null) {
        await prefs.setString('user_plate_number', profileData.plateNumber!);
      }
      if (profileData.phone != null) {
        await prefs.setString('user_phone', profileData.phone!);
      }
      if (profileData.profileImageUrl != null) {
        await prefs.setString(
            'user_profile_image', profileData.profileImageUrl!);
      }
    } catch (e) {
      if (kReleaseMode) {
        print('⚠️ ReleaseModeUserSync: Error saving updated data to prefs: $e');
      } else {
        debugPrint(
            '⚠️ ReleaseModeUserSync: Error saving updated data to prefs: $e');
      }
    }
  }

  /// مزامنة بيانات المستخدم مع Firebase Database
  Future<void> _syncUserDataToFirebase(Map<String, dynamic> userInfo) async {
    try {
      final userId = userInfo['userId'] as String;

      if (kReleaseMode) {
        print('💾 ReleaseModeUserSync: Syncing user data to Firebase: $userId');
      } else {
        debugPrint(
            '💾 ReleaseModeUserSync: Syncing user data to Firebase: $userId');
      }

      // إزالة القيم null
      final cleanUserInfo = Map<String, dynamic>.from(userInfo);
      cleanUserInfo.removeWhere((key, value) => value == null);

      // إضافة timestamp
      cleanUserInfo['updatedAt'] = DateTime.now().toIso8601String();
      cleanUserInfo['lastActive'] = DateTime.now().millisecondsSinceEpoch;

      // حفظ البيانات في Firebase
      await _database.child('users/$userId').update(cleanUserInfo);

      if (kReleaseMode) {
        print(
            '✅ ReleaseModeUserSync: User data synced to Firebase successfully');
      } else {
        debugPrint(
            '✅ ReleaseModeUserSync: User data synced to Firebase successfully');
      }
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: Error syncing user data to Firebase: $e');
      } else {
        debugPrint(
            '❌ ReleaseModeUserSync: Error syncing user data to Firebase: $e');
      }
      rethrow;
    }
  }

  /// تحديث موقع المستخدم مع مزامنة محسنة
  Future<bool> updateUserLocationWithSync(LatLng location) async {
    try {
      final userInfo = await _getCurrentUserInfo();
      if (userInfo == null) return false;

      final userId = userInfo['userId'] as String;

      final locationData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'updatedAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      // تحديث الموقع والحالة
      await _database.child('users/$userId').update({
        'location': locationData,
        'isOnline': true,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });

      if (kReleaseMode) {
        print('✅ ReleaseModeUserSync: Location updated successfully');
      } else {
        debugPrint('✅ ReleaseModeUserSync: Location updated successfully');
      }

      return true;
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: Error updating location: $e');
      } else {
        debugPrint('❌ ReleaseModeUserSync: Error updating location: $e');
      }
      return false;
    }
  }

  /// التحقق من صحة بيانات المستخدم في Firebase
  Future<bool> validateUserDataInFirebase() async {
    try {
      final userInfo = await _getCurrentUserInfo();
      if (userInfo == null) return false;

      final userId = userInfo['userId'] as String;
      final snapshot = await _database.child('users/$userId').get();

      if (!snapshot.exists) {
        if (kReleaseMode) {
          print(
              '⚠️ ReleaseModeUserSync: User data not found in Firebase, syncing...');
        } else {
          debugPrint(
              '⚠️ ReleaseModeUserSync: User data not found in Firebase, syncing...');
        }

        await _syncUserDataToFirebase(userInfo);
        return true;
      }

      final firebaseData = snapshot.value as Map<dynamic, dynamic>;

      // التحقق من اكتمال البيانات المهمة
      final requiredFields = ['name', 'email', 'userType'];
      final missingFields = requiredFields
          .where((field) =>
              firebaseData[field] == null ||
              firebaseData[field].toString().isEmpty)
          .toList();

      if (missingFields.isNotEmpty) {
        if (kReleaseMode) {
          print(
              '⚠️ ReleaseModeUserSync: Missing fields in Firebase: $missingFields, updating...');
        } else {
          debugPrint(
              '⚠️ ReleaseModeUserSync: Missing fields in Firebase: $missingFields, updating...');
        }

        await _syncUserDataToFirebase(userInfo);
      }

      return true;
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: Error validating user data: $e');
      } else {
        debugPrint('❌ ReleaseModeUserSync: Error validating user data: $e');
      }
      return false;
    }
  }

  /// إصلاح مشاكل المستخدمين في Release Mode
  Future<Map<String, dynamic>> fixReleaseModeUserIssues() async {
    final results = <String, dynamic>{};

    try {
      if (kReleaseMode) {
        print('🔧 ReleaseModeUserSync: Starting Release Mode user fixes...');
      } else {
        debugPrint(
            '🔧 ReleaseModeUserSync: Starting Release Mode user fixes...');
      }

      // 1. مزامنة المستخدم الحالي
      results['user_sync'] = await syncCurrentUserToFirebase();

      // 2. التحقق من صحة البيانات
      results['data_validation'] = await validateUserDataInFirebase();

      // 3. تحديث FCM token
      results['fcm_token_update'] = await _updateFCMToken();

      // 4. تحديث حالة الاتصال
      results['online_status_update'] = await _updateOnlineStatus();

      final allSuccessful = results.values.every((value) => value == true);
      results['overall_success'] = allSuccessful;

      if (kReleaseMode) {
        print('📊 ReleaseModeUserSync: Fix results: $results');
      } else {
        debugPrint('📊 ReleaseModeUserSync: Fix results: $results');
      }
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: Error in Release Mode fixes: $e');
      } else {
        debugPrint('❌ ReleaseModeUserSync: Error in Release Mode fixes: $e');
      }
      results['error'] = e.toString();
    }

    return results;
  }

  /// تحديث FCM token للمستخدم الحالي
  Future<bool> _updateFCMToken() async {
    try {
      final userInfo = await _getCurrentUserInfo();
      if (userInfo == null) return false;

      // استخدام FCMTokenManager لتحديث الـ token
      final tokenManager = FCMTokenManager();
      return await tokenManager.saveTokenOnLogin();
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: Error updating FCM token: $e');
      } else {
        debugPrint('❌ ReleaseModeUserSync: Error updating FCM token: $e');
      }
      return false;
    }
  }

  /// تحديث حالة الاتصال
  Future<bool> _updateOnlineStatus() async {
    try {
      final userInfo = await _getCurrentUserInfo();
      if (userInfo == null) return false;

      final userId = userInfo['userId'] as String;

      await _database.child('users/$userId').update({
        'isOnline': true,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      if (kReleaseMode) {
        print('❌ ReleaseModeUserSync: Error updating online status: $e');
      } else {
        debugPrint('❌ ReleaseModeUserSync: Error updating online status: $e');
      }
      return false;
    }
  }
}
