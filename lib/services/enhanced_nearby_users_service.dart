import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:road_helperr/models/user_location.dart';
import 'package:road_helperr/services/auth_service.dart';
import 'package:road_helperr/services/api_service.dart';
import 'package:road_helperr/services/firebase_database_manager.dart';

class EnhancedNearbyUsersService {
  static final EnhancedNearbyUsersService _instance =
      EnhancedNearbyUsersService._internal();
  factory EnhancedNearbyUsersService() => _instance;
  EnhancedNearbyUsersService._internal();

  late DatabaseReference _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late FirebaseDatabaseManager _dbManager;

  Timer? _locationUpdateTimer;
  Timer? _userSyncTimer;
  StreamSubscription<Position>? _positionSubscription;

  // Cache للمستخدمين القريبين
  Stream<List<UserLocation>>? _nearbyUsersStream;
  LatLng? _lastLocation;
  double? _lastRadius;

  // تهيئة الخدمة وبدء تتبع الموقع
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Enhanced Nearby Users: Initializing service...');

      // تهيئة Firebase Database Manager
      _dbManager = FirebaseDatabaseManager();
      await _dbManager.initialize();
      _database = _dbManager.database;

      // بدء تتبع الموقع التلقائي
      await _startLocationTracking();

      // بدء مزامنة بيانات المستخدمين
      _startUserDataSync();

      debugPrint('✅ Enhanced Nearby Users: Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Enhanced Nearby Users: Initialization failed: $e');
    }
  }

  // بدء تتبع الموقع التلقائي
  Future<void> _startLocationTracking() async {
    try {
      // تحديث الموقع فوراً
      await _updateCurrentLocation();

      // تحديث الموقع كل 30 ثانية
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (timer) => _updateCurrentLocation(),
      );

      debugPrint('📍 Enhanced Nearby Users: Location tracking started');
    } catch (e) {
      debugPrint('❌ Enhanced Nearby Users: Location tracking failed: $e');
    }
  }

  // تحديث الموقع الحالي
  Future<void> _updateCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      // تحديث الموقع في Firebase باستخدام Database Manager
      await _dbManager.updateUserLocation(currentLocation);

      debugPrint(
          '📍 Enhanced Nearby Users: Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Enhanced Nearby Users: Location update failed: $e');
    }
  }

  // بدء مزامنة بيانات المستخدمين
  void _startUserDataSync() {
    _userSyncTimer?.cancel();
    _userSyncTimer = Timer.periodic(
      const Duration(minutes: 2),
      (timer) => _syncUserData(),
    );

    // مزامنة فورية
    _syncUserData();
  }

  // مزامنة بيانات المستخدم مع Firebase (من SQL Database)
  Future<void> _syncUserData() async {
    try {
      final authService = AuthService();
      final userInfo = await authService.getUserData();

      if (userInfo != null) {
        // جلب بيانات إضافية من SQL database إذا لزم الأمر
        Map<String, dynamic>? additionalData;
        try {
          final email = userInfo['email'];
          if (email != null) {
            additionalData = await ApiService.getUserData(email);
          }
        } catch (e) {
          debugPrint(
              '⚠️ Enhanced Nearby Users: Could not fetch additional data from SQL: $e');
        }

        // دمج البيانات من SQL مع البيانات المحلية
        final finalUserData = {
          ...userInfo,
          if (additionalData != null) ...additionalData,
        };

        await _dbManager.updateUserInfo(
          name: finalUserData['name'] ??
              finalUserData['firstName'] ??
              'Unknown User',
          email: finalUserData['email'] ?? '',
          phone: finalUserData['phone'],
          carModel: finalUserData['carModel'] ?? finalUserData['car_model'],
          carColor: finalUserData['carColor'] ?? finalUserData['car_color'],
          plateNumber:
              finalUserData['plateNumber'] ?? finalUserData['car_number'],
          profileImageUrl: finalUserData['profileImageUrl'] ??
              finalUserData['profile_picture'],
          isAvailableForHelp: true,
        );

        debugPrint(
            '🔄 Enhanced Nearby Users: User data synced from SQL to Firebase successfully');
      }
    } catch (e) {
      debugPrint('❌ Enhanced Nearby Users: User data sync failed: $e');
    }
  }

  // الحصول على المستخدمين القريبين مع تحسينات
  Stream<List<UserLocation>> getNearbyUsers(
      LatLng currentLocation, double radiusKm) {
    debugPrint('🔍 Enhanced Nearby Users: Getting nearby users...');
    debugPrint(
        '📍 Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');
    debugPrint('📏 Search radius: ${radiusKm}km');

    // التحقق من الـ cache
    if (_nearbyUsersStream != null &&
        _lastLocation != null &&
        _lastRadius != null &&
        _calculateDistance(_lastLocation!, currentLocation) <
            0.1 && // أقل من 100 متر
        (_lastRadius! - radiusKm).abs() < 0.1) {
      debugPrint('📦 Enhanced Nearby Users: Using cached stream');
      return _nearbyUsersStream!;
    }

    // إنشاء stream جديد
    _lastLocation = currentLocation;
    _lastRadius = radiusKm;

    _nearbyUsersStream =
        _database.child('users').onValue.asBroadcastStream().map((event) {
      debugPrint('📡 Enhanced Nearby Users: Received Firebase update');

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        debugPrint('❌ Enhanced Nearby Users: No users data found');
        return <UserLocation>[];
      }

      final currentUserId = _getCurrentUserId();
      debugPrint('👤 Enhanced Nearby Users: Current user ID: $currentUserId');
      debugPrint(
          '📊 Enhanced Nearby Users: Total users in database: ${data.length}');

      final nearbyUsers = data.entries
          .where((entry) {
            final userId = entry.key;
            final userData = entry.value as Map<dynamic, dynamic>?;

            // تجاهل المستخدم الحالي
            if (userId == currentUserId) return false;

            // التحقق من وجود بيانات الموقع
            if (userData == null || userData['location'] == null) return false;

            final locationData = userData['location'] as Map<dynamic, dynamic>;
            if (locationData['latitude'] == null ||
                locationData['longitude'] == null) {
              return false;
            }

            // التحقق من أن المستخدم متصل (آخر تحديث خلال 10 دقائق)
            final lastUpdated = locationData['updatedAt'];
            if (lastUpdated != null) {
              try {
                final lastUpdateTime = DateTime.parse(lastUpdated);
                final difference =
                    DateTime.now().difference(lastUpdateTime).inMinutes;
                if (difference > 10) return false;
              } catch (e) {
                debugPrint(
                    '⚠️ Enhanced Nearby Users: Invalid date format: $lastUpdated');
                return false;
              }
            }

            return true;
          })
          .map((entry) =>
              _createUserLocationFromFirebase(entry.key, entry.value))
          .where((user) {
            final distance = _calculateDistance(currentLocation, user.position);
            final isInRange = distance <= radiusKm;

            if (isInRange) {
              debugPrint(
                  '✅ Enhanced Nearby Users: User ${user.userName} is ${distance.toStringAsFixed(2)}km away');
            }

            return isInRange;
          })
          .toList()
        ..sort((a, b) {
          final distanceA = _calculateDistance(currentLocation, a.position);
          final distanceB = _calculateDistance(currentLocation, b.position);
          return distanceA.compareTo(distanceB);
        });

      debugPrint(
          '🎯 Enhanced Nearby Users: Found ${nearbyUsers.length} nearby users');
      return nearbyUsers;
    });

    return _nearbyUsersStream!;
  }

  // الحصول على ID المستخدم الحالي
  String? _getCurrentUserId() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return firebaseUser.uid;
    }

    // للمستخدمين العاديين، استخدم email كـ ID
    // يمكن تحسين هذا لاحقاً
    return null;
  }

  // إنشاء UserLocation من بيانات Firebase
  UserLocation _createUserLocationFromFirebase(String userId, dynamic data) {
    final userData = data as Map<dynamic, dynamic>;
    final locationData = userData['location'] as Map<dynamic, dynamic>?;

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

  // حساب المسافة بين نقطتين
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; // تحويل إلى كيلومتر
  }

  // إيقاف الخدمة
  void dispose() {
    _locationUpdateTimer?.cancel();
    _userSyncTimer?.cancel();
    _positionSubscription?.cancel();
    _nearbyUsersStream = null;

    debugPrint('🛑 Enhanced Nearby Users: Service disposed');
  }

  // إعادة تشغيل الخدمة
  Future<void> restart() async {
    dispose();
    await initialize();
  }
}
