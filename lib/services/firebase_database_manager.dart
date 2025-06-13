import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:road_helperr/services/auth_service.dart';
import 'package:road_helperr/services/release_mode_helper.dart';

class FirebaseDatabaseManager {
  static final FirebaseDatabaseManager _instance =
      FirebaseDatabaseManager._internal();
  factory FirebaseDatabaseManager() => _instance;
  FirebaseDatabaseManager._internal();

  late DatabaseReference _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;
  Timer? _connectionTestTimer;
  StreamSubscription<DatabaseEvent>? _connectionListener;

  // تهيئة Firebase Database
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔥 Firebase DB Manager: Initializing...');

      // تهيئة Firebase Database مع URL الصحيح
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://road-helper-fed8f-default-rtdb.europe-west1.firebasedatabase.app',
      ).ref();

      // تفعيل الـ persistence
      FirebaseDatabase.instance.setPersistenceEnabled(true);

      // اختبار الاتصال
      await _testConnection();

      // بدء مراقبة الاتصال
      _startConnectionMonitoring();

      _isInitialized = true;
      debugPrint('✅ Firebase DB Manager: Initialized successfully');
    } catch (e) {
      debugPrint('❌ Firebase DB Manager: Initialization failed: $e');
      throw Exception('Failed to initialize Firebase Database: $e');
    }
  }

  // اختبار الاتصال بـ Firebase Database
  Future<bool> _testConnection() async {
    try {
      // في Release Mode، نستخدم تشخيص محسن
      if (kReleaseMode) {
        print('🔍 Firebase DB Manager: Testing connection in Release Mode...');
        final diagnostics = await ReleaseModeHelper.diagnoseNetworkIssues();
        print('📊 Firebase DB Manager: Network diagnostics: $diagnostics');

        if (diagnostics['firebase_reachable'] == true) {
          print(
              '✅ Firebase DB Manager: Connection test successful in Release Mode');
          return true;
        } else {
          print(
              '❌ Firebase DB Manager: Connection test failed in Release Mode');
          return false;
        }
      }

      debugPrint('🔍 Firebase DB Manager: Testing connection...');

      // محاولة قراءة بسيطة للتأكد من الاتصال
      final testRef = _database.child('.info/connected');
      final snapshot = await testRef.get().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
                'Connection test timed out', const Duration(seconds: 10)),
          );

      final isConnected = snapshot.value as bool? ?? false;
      debugPrint('🔗 Firebase DB Manager: Connection status: $isConnected');

      if (isConnected) {
        debugPrint('✅ Firebase DB Manager: Connection test successful');
        return true;
      } else {
        debugPrint('⚠️ Firebase DB Manager: Not connected to Firebase');
        return false;
      }
    } catch (e) {
      if (kReleaseMode) {
        print(
            '❌ Firebase DB Manager: Connection test failed in Release Mode: $e');
      } else {
        debugPrint('❌ Firebase DB Manager: Connection test failed: $e');
      }
      return false;
    }
  }

  // بدء مراقبة الاتصال
  void _startConnectionMonitoring() {
    try {
      _connectionListener?.cancel();

      _connectionListener =
          _database.child('.info/connected').onValue.listen((event) {
        final isConnected = event.snapshot.value as bool? ?? false;
        debugPrint(
            '🔗 Firebase DB Manager: Connection status changed: $isConnected');

        if (isConnected) {
          debugPrint('✅ Firebase DB Manager: Connected to Firebase');
          _onConnectionRestored();
        } else {
          debugPrint('⚠️ Firebase DB Manager: Disconnected from Firebase');
          _onConnectionLost();
        }
      });

      debugPrint('📡 Firebase DB Manager: Connection monitoring started');
    } catch (e) {
      debugPrint(
          '❌ Firebase DB Manager: Failed to start connection monitoring: $e');
    }
  }

  // عند استعادة الاتصال
  void _onConnectionRestored() {
    debugPrint(
        '🔄 Firebase DB Manager: Connection restored, updating user status...');
    _updateUserOnlineStatus(true);
  }

  // عند فقدان الاتصال
  void _onConnectionLost() {
    debugPrint('⚠️ Firebase DB Manager: Connection lost');
  }

  // تحديث حالة المستخدم (متصل/غير متصل)
  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return;

      await _database.child('users/$userId').update({
        'isOnline': isOnline,
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint(
          '✅ Firebase DB Manager: User online status updated: $isOnline');
    } catch (e) {
      debugPrint('❌ Firebase DB Manager: Failed to update online status: $e');
    }
  }

  // الحصول على ID المستخدم الحالي
  Future<String?> _getCurrentUserId() async {
    // أولاً، جرب Firebase Auth
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return firebaseUser.uid;
    }

    // إذا لم يكن متوفراً، استخدم AuthService
    try {
      final authService = AuthService();
      return await authService.getUserId();
    } catch (e) {
      debugPrint('❌ Firebase DB Manager: Failed to get user ID: $e');
      return null;
    }
  }

  // تحديث موقع المستخدم
  Future<void> updateUserLocation(LatLng location,
      {Map<String, dynamic>? additionalData}) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        debugPrint(
            '❌ Firebase DB Manager: Cannot update location - user not authenticated');
        return;
      }

      debugPrint('📍 Firebase DB Manager: Updating location for user $userId');

      final locationData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'lastUpdated': ServerValue.timestamp,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (additionalData != null) {
        locationData.addAll(additionalData.cast<String, Object>());
      }

      await _database.child('users/$userId/location').update(locationData);
      await _database.child('users/$userId').update({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint('✅ Firebase DB Manager: Location updated successfully');
    } catch (e) {
      debugPrint('❌ Firebase DB Manager: Failed to update location: $e');
      throw Exception('Failed to update location: $e');
    }
  }

  // تحديث معلومات المستخدم
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
      final userId = await _getCurrentUserId();
      if (userId == null) {
        debugPrint(
            '❌ Firebase DB Manager: Cannot update user info - user not authenticated');
        return;
      }

      debugPrint('👤 Firebase DB Manager: Updating user info for $userId');

      final userInfo = {
        'name': name,
        'email': email,
        'phone': phone,
        'carModel': carModel,
        'carColor': carColor,
        'plateNumber': plateNumber,
        'profileImageUrl': profileImageUrl,
        'isAvailableForHelp': isAvailableForHelp ?? true,
        'lastUpdated': ServerValue.timestamp,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // إزالة القيم null
      userInfo.removeWhere((key, value) => value == null);

      await _database
          .child('users/$userId')
          .update(userInfo.cast<String, Object>());

      debugPrint('✅ Firebase DB Manager: User info updated successfully');
    } catch (e) {
      debugPrint('❌ Firebase DB Manager: Failed to update user info: $e');
      throw Exception('Failed to update user info: $e');
    }
  }

  // الحصول على مرجع قاعدة البيانات
  DatabaseReference get database => _database;

  // التحقق من حالة التهيئة
  bool get isInitialized => _isInitialized;

  // إعادة تشغيل الاتصال
  Future<void> reconnect() async {
    try {
      debugPrint('🔄 Firebase DB Manager: Attempting to reconnect...');

      // إيقاف المراقبة الحالية
      _connectionListener?.cancel();

      // إعادة تهيئة الاتصال
      await _testConnection();
      _startConnectionMonitoring();

      debugPrint('✅ Firebase DB Manager: Reconnection attempt completed');
    } catch (e) {
      debugPrint('❌ Firebase DB Manager: Reconnection failed: $e');
    }
  }

  // تنظيف الموارد
  void dispose() {
    _connectionTestTimer?.cancel();
    _connectionListener?.cancel();
    _isInitialized = false;

    debugPrint('🛑 Firebase DB Manager: Disposed');
  }
}
