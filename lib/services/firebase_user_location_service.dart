import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:road_helperr/models/user_location.dart';
import 'package:road_helperr/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class FirebaseUserLocationService {
  static final FirebaseUserLocationService _instance =
      FirebaseUserLocationService._internal();
  factory FirebaseUserLocationService() => _instance;
  FirebaseUserLocationService._internal();

  final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://road-helper-fed8f-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _positionSubscription;

  // Cache للـ stream عشان نتجنب مشكلة "Stream has already been listened to"
  Stream<List<UserLocation>>? _nearbyUsersStream;
  LatLng? _lastLocation;
  double? _lastRadius;

  // تحديث موقع المستخدم الحالي (محدث للنظام الهجين)
  Future<void> updateUserLocation(LatLng location,
      {Map<String, dynamic>? additionalData}) async {
    try {
      // الحصول على User ID الموحد للنظام الهجين
      final userId = await _getUnifiedUserId();
      if (userId == null) {
        debugPrint(
            '❌ Firebase: User not authenticated, cannot update location');
        return;
      }

      debugPrint('🔄 Firebase: Updating location for user $userId');
      debugPrint(
          '📍 Firebase: Location: ${location.latitude}, ${location.longitude}');

      final locationData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'lastUpdated': ServerValue.timestamp,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // إضافة بيانات إضافية إذا وجدت
      if (additionalData != null) {
        locationData.addAll(additionalData.cast<String, Object>());
      }

      // تحديث موقع المستخدم
      await _database.child('users/$userId/location').update(locationData);

      // تحديث حالة الاتصال
      await _database.child('users/$userId').update({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      // للمستخدمين Google، تحديث بيانات المستخدم من API
      await _updateGoogleUserDataInFirebase(userId);

      debugPrint('✅ Firebase: Location updated successfully for $userId');
      debugPrint('📊 Firebase: Data sent to path: users/$userId/location');
    } catch (e) {
      debugPrint('❌ Firebase: Error updating user location: $e');
      debugPrint('🔍 Firebase: Error details: ${e.toString()}');
    }
  }

  // تحديث بيانات مستخدم Google في Firebase من API
  Future<void> _updateGoogleUserDataInFirebase(String userId) async {
    try {
      // التحقق من أن المستخدم هو مستخدم Google
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        return;
      }

      debugPrint('🔄 Firebase: Updating Google user data from API for $userId');

      // جلب بيانات المستخدم من API الخاص بـ Google
      final prefs = await SharedPreferences.getInstance();
      final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

      if (isGoogleSignIn) {
        debugPrint(
            '🔍 Firebase: Fetching Google user data from datagoogle API');

        final response = await ApiService.getGoogleUserData(currentUser.email!);

        if (response['success'] == true && response['data'] != null) {
          final userData = response['data']['user'] ?? response['data'];

          debugPrint(
              '✅ Firebase: Google user data received from datagoogle API');

          // تحديث بيانات المستخدم في Firebase
          final userUpdateData = {
            'name':
                '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                    .trim(),
            'userName':
                '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                    .trim(),
            'email': userData['email'] ?? currentUser.email,
            'phone': userData['phone'],
            'carModel': userData['car_model'],
            'carColor': userData['car_color'],
            'plateNumber': userData['car_number'],
            'profileImage': userData['profile_picture'],
            'profileImageUrl': userData['profile_picture'],
            'isGoogleUser': true,
            'isAvailableForHelp': true,
            'lastDataUpdate': ServerValue.timestamp,
          };

          await _database.child('users/$userId').update(userUpdateData);

          debugPrint(
              '✅ Firebase: Google user data updated successfully in Firebase');
          debugPrint(
              '📊 Firebase: Updated data: ${userUpdateData.keys.toList()}');
        } else {
          debugPrint('❌ Firebase: Failed to fetch Google user data from API');
        }
      }
    } catch (e) {
      debugPrint('❌ Firebase: Error updating Google user data: $e');
      // لا نرمي خطأ هنا لأن تحديث الموقع نجح
    }
  }

  /// الحصول على User ID للمستخدمين المصرح لهم (Google users only)
  Future<String?> _getUnifiedUserId() async {
    try {
      // فقط مستخدمو Google مسموح لهم بتحديث المواقع
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        debugPrint(
            '🔥 Firebase: Current user is Firebase user: ${firebaseUser.uid}');
        return firebaseUser.uid;
      }

      // المستخدمون التقليديون لا يمكنهم تحديث المواقع في Firebase
      final prefs = await SharedPreferences.getInstance();
      final sqlUserId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');

      if (sqlUserId != null && sqlUserId.isNotEmpty && userEmail != null) {
        debugPrint(
            '❌ Firebase: Traditional users cannot update location in Firebase');
        debugPrint(
            'ℹ️ Firebase: Traditional user detected (SQL: $sqlUserId, Email: $userEmail)');
        return null; // منع المستخدمين التقليديين من تحديث المواقع
      }

      debugPrint('❌ Firebase: No current user found');
      return null;
    } catch (e) {
      debugPrint('❌ Firebase: Failed to get unified user ID: $e');
      return null;
    }
  }

  // تحديث معلومات المستخدم الأساسية (Google users only)
  Future<void> updateUserInfo({
    required String name,
    required String email,
    String? phone,
    String? carModel,
    String? carColor,
    String? plateNumber,
    String? profileImageUrl,
    bool? isAvailableForHelp,
  }) async {
    try {
      // فقط مستخدمو Google مسموح لهم بتحديث المعلومات في Firebase
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        debugPrint('❌ Firebase: Only Google users can update info in Firebase');
        return;
      }

      final userId = firebaseUser.uid;
      const userType = 'google';

      final userInfo = {
        'userId': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'carModel': carModel,
        'carColor': carColor,
        'plateNumber': plateNumber,
        'profileImageUrl': profileImageUrl,
        'isOnline': true,
        'isAvailableForHelp': isAvailableForHelp ?? true,
        'userType': userType,
        'lastUpdated': ServerValue.timestamp,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // طباعة البيانات قبل الحفظ للتصحيح
      debugPrint('💾 Saving Google user info to Firebase:');
      debugPrint('  - User ID: $userId');
      debugPrint('  - User Type: $userType');
      debugPrint('  - Name: $name');
      debugPrint('  - Email: $email');
      debugPrint('  - Phone: $phone');
      debugPrint('  - Car Model: $carModel');
      debugPrint('  - Car Color: $carColor');
      debugPrint('  - Plate Number: $plateNumber');
      debugPrint('  - Profile Image URL: $profileImageUrl');

      await _database.child('users/$userId').update(userInfo);

      // حفظ FCM token للإشعارات
      await _saveFCMToken();

      debugPrint('✅ Google user info updated successfully in Firebase');
    } catch (e) {
      debugPrint('❌ Error updating Google user info: $e');
      throw Exception('Failed to update user info: $e');
    }
  }

  // حفظ FCM token للمستخدم (محدث للنظام الهجين)
  Future<void> _saveFCMToken() async {
    try {
      // الحصول على User ID الموحد للنظام الهجين
      final userId = await _getUnifiedUserId();
      if (userId == null) {
        debugPrint(
            '❌ Firebase: Cannot save FCM token - user not authenticated');
        return;
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _database.child('users/$userId/fcmToken').set(fcmToken);
        debugPrint(
            '✅ Firebase: FCM token saved successfully for $userId: $fcmToken');
      }
    } catch (e) {
      debugPrint('❌ Firebase: Error saving FCM token: $e');
    }
  }

  // الاستماع للمستخدمين القريبين
  Stream<List<UserLocation>> listenToNearbyUsers(
      LatLng currentLocation, double radiusKm) {
    debugPrint('🔄 Firebase: Starting to listen for nearby users...');
    debugPrint(
        '📍 Firebase: Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');
    debugPrint('📏 Firebase: Search radius: ${radiusKm}km');

    // التحقق من إذا كان الـ stream موجود بالفعل ونفس المعاملات
    if (_nearbyUsersStream != null &&
        _lastLocation != null &&
        _lastRadius != null &&
        _lastLocation!.latitude == currentLocation.latitude &&
        _lastLocation!.longitude == currentLocation.longitude &&
        _lastRadius == radiusKm) {
      debugPrint('📦 Firebase: Using cached stream');
      return _nearbyUsersStream!;
    }

    // إنشاء stream جديد
    debugPrint('🆕 Firebase: Creating new stream');
    _lastLocation = currentLocation;
    _lastRadius = radiusKm;

    _nearbyUsersStream = _database
        .child('users')
        .onValue
        .asBroadcastStream()
        .asyncMap((event) async {
      debugPrint('📡 Firebase: Received data update from users node');
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) {
        debugPrint('❌ Firebase: No data found in users node');
        return <UserLocation>[];
      }

      debugPrint('📊 Firebase: Found ${data.length} total users in database');

      // الحصول على User ID الموحد للمستخدم الحالي
      final currentUserId = await _getUnifiedUserId();
      debugPrint('🔑 Firebase: Current user ID: $currentUserId');

      final users = data.entries
          .where((entry) {
            final userId = entry.key;
            final userData = entry.value as Map<dynamic, dynamic>;

            debugPrint('🔍 Firebase: Checking user $userId');

            // استبعاد المستخدم الحالي
            if (userId == currentUserId) {
              debugPrint('  ⏭️ Skipping current user: $userId');
              return false;
            }

            // التحقق من وجود بيانات الموقع
            if (userData['location'] == null) {
              debugPrint('  ❌ User $userId has no location data');
              return false;
            }

            // التحقق من أن المستخدم متاح للمساعدة ومتصل
            final isOnline = userData['isOnline'] == true;
            final isAvailable = userData['isAvailableForHelp'] == true;

            debugPrint(
                '  📊 User $userId: isOnline=$isOnline, isAvailable=$isAvailable');

            if (!isOnline || !isAvailable) {
              debugPrint('  ❌ User $userId is offline or not available');
              return false;
            }

            // التحقق من أن الموقع محدث حديثاً (خلال آخر 10 دقائق)
            final lastUpdated = userData['location']['updatedAt'];
            if (lastUpdated != null) {
              try {
                final lastUpdateTime = DateTime.parse(lastUpdated);
                final now = DateTime.now();
                final difference = now.difference(lastUpdateTime).inMinutes;
                debugPrint(
                    '  ⏰ User $userId: last updated $difference minutes ago');
                if (difference > 10) {
                  debugPrint(
                      '  ❌ User $userId location is too old ($difference minutes)');
                  return false; // أكثر من 10 دقائق
                }
              } catch (e) {
                debugPrint('  ⚠️ User $userId: Error parsing update time: $e');
              }
            }

            debugPrint('  ✅ User $userId passed all filters');
            return true;
          })
          .map((entry) => _userLocationFromFirebase(entry.key, entry.value))
          .where((user) {
            // حساب المسافة وتصفية المستخدمين حسب النطاق
            final distance = _calculateDistance(currentLocation, user.position);
            debugPrint(
                '📏 Firebase: User ${user.userId} is ${distance.toStringAsFixed(2)} km away (limit: $radiusKm km)');

            if (distance <= radiusKm) {
              debugPrint('  ✅ User ${user.userId} is within range');
              return true;
            } else {
              debugPrint('  ❌ User ${user.userId} is too far away');
              return false;
            }
          })
          .toList();

      // ترتيب حسب المسافة (الأقرب أولاً)
      users.sort((a, b) {
        final distanceA = _calculateDistance(currentLocation, a.position);
        final distanceB = _calculateDistance(currentLocation, b.position);
        return distanceA.compareTo(distanceB);
      });

      debugPrint(
          '🎯 Firebase: Final result: ${users.length} users found after all filters');
      return users;
    });

    return _nearbyUsersStream!;
  }

  // جلب معلومات مستخدم محدد
  Future<UserLocation?> getUserById(String userId) async {
    try {
      final snapshot = await _database.child('users/$userId').get();
      if (snapshot.exists) {
        return _userLocationFromFirebase(userId, snapshot.value);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  // بدء تتبع الموقع التلقائي
  void startLocationTracking() {
    _locationUpdateTimer?.cancel();

    // تحديث الموقع كل دقيقة
    _locationUpdateTimer =
        Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        await updateUserLocation(LatLng(position.latitude, position.longitude));
      } catch (e) {
        debugPrint('Error in automatic location update: $e');
      }
    });
  }

  // إيقاف تتبع الموقع
  void stopLocationTracking() {
    _locationUpdateTimer?.cancel();
    _positionSubscription?.cancel();
  }

  // تحديث حالة الاتصال عند الخروج (محدث للنظام الهجين)
  Future<void> setUserOffline() async {
    try {
      // الحصول على User ID الموحد للنظام الهجين
      final userId = await _getUnifiedUserId();
      if (userId == null) {
        debugPrint(
            '❌ Firebase: Cannot set user offline - user not authenticated');
        return;
      }

      await _database.child('users/$userId').update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint('✅ Firebase: User $userId set to offline');
    } catch (e) {
      debugPrint('❌ Firebase: Error setting user offline: $e');
    }
  }

  // تحديث حالة توفر المستخدم للمساعدة
  Future<void> updateAvailabilityForHelp(bool isAvailable) async {
    try {
      final userId = await _getUnifiedUserId();
      if (userId == null) {
        debugPrint(
            '❌ Firebase: User not authenticated, cannot update availability');
        return;
      }

      await _database.child('users/$userId').update({
        'isAvailableForHelp': isAvailable,
        'lastUpdated': ServerValue.timestamp,
      });

      debugPrint(
          '✅ Firebase: User $userId availability updated to: $isAvailable');
    } catch (e) {
      debugPrint('❌ Firebase: Error updating user availability: $e');
      rethrow;
    }
  }

  // تحويل بيانات Firebase إلى UserLocation
  UserLocation _userLocationFromFirebase(String userId, dynamic data) {
    final userData = data as Map<dynamic, dynamic>;
    final locationData = userData['location'] as Map<dynamic, dynamic>?;

    // طباعة البيانات للتصحيح
    debugPrint('🔍 Firebase User Data for $userId:');
    debugPrint('  - Raw data: $userData');
    debugPrint('  - Name: ${userData['name']}');
    debugPrint('  - Email: ${userData['email']}');
    debugPrint('  - Phone: ${userData['phone']}');
    debugPrint('  - Car Model: ${userData['carModel']}');
    debugPrint('  - Car Color: ${userData['carColor']}');
    debugPrint('  - Plate Number: ${userData['plateNumber']}');
    debugPrint('  - Location: $locationData');

    return UserLocation(
      userId: userId,
      userName: userData['name'] ?? 'Unknown User',
      email: userData['email'] ?? '',
      phone: userData['phone'],
      position: LatLng(
        (locationData?['latitude'] as num?)?.toDouble() ?? 0.0,
        (locationData?['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      carModel: userData['carModel'],
      carColor: userData['carColor'],
      plateNumber: userData['plateNumber'],
      profileImageUrl: userData['profileImageUrl'],
      isOnline: userData['isOnline'] == true,
      isAvailableForHelp: userData['isAvailableForHelp'] == true,
      lastSeen: userData['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(userData['lastSeen'])
          : DateTime.now(),
      rating: (userData['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: userData['totalRatings'] ?? 0,
    );
  }

  // حساب المسافة بين نقطتين (بالكيلومتر)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // نصف قطر الأرض بالكيلومتر

    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (math.pi / 180);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // تنظيف الموارد
  void dispose() {
    stopLocationTracking();
  }
}
