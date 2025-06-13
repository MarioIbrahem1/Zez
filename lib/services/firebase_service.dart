import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:road_helperr/services/firebase_user_location_service.dart';
import 'package:road_helperr/services/firebase_help_request_service.dart';
import 'package:road_helperr/services/fcm_v1_service.dart';
import 'package:road_helperr/services/help_request_delivery_monitor.dart';
import 'package:road_helperr/services/help_request_cleanup_service.dart';
import 'package:road_helperr/services/help_request_analytics.dart';
import 'package:road_helperr/services/help_request_security_validator.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _isInitialized = false;

  // خدمات Firebase
  late FirebaseUserLocationService _userLocationService;
  late FirebaseHelpRequestService _helpRequestService;
  late HelpRequestDeliveryMonitor _deliveryMonitor;
  late HelpRequestCleanupService _cleanupService;
  late HelpRequestAnalytics _analytics;

  // Getters للخدمات
  FirebaseUserLocationService get userLocationService => _userLocationService;
  FirebaseHelpRequestService get helpRequestService => _helpRequestService;
  HelpRequestDeliveryMonitor get deliveryMonitor => _deliveryMonitor;
  HelpRequestCleanupService get cleanupService => _cleanupService;
  HelpRequestAnalytics get analytics => _analytics;

  // تهيئة Firebase
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // تهيئة Firebase Core
      await Firebase.initializeApp();

      // تهيئة Firebase Realtime Database
      FirebaseDatabase.instance.setPersistenceEnabled(true);

      // تهيئة الخدمات
      _userLocationService = FirebaseUserLocationService();
      _helpRequestService = FirebaseHelpRequestService();
      _deliveryMonitor = HelpRequestDeliveryMonitor();
      _cleanupService = HelpRequestCleanupService();
      _analytics = HelpRequestAnalytics();

      // بدء الخدمات التلقائية
      _deliveryMonitor.startMonitoring();
      _cleanupService.startCleanupService();

      _isInitialized = true;
      debugPrint('Firebase services initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      throw Exception('Failed to initialize Firebase: $e');
    }
  }

  // تسجيل دخول المستخدم وتحديث معلوماته
  Future<void> signInUser({
    required String email,
    required String name,
    String? phone,
    String? carModel,
    String? carColor,
    String? plateNumber,
    String? profileImageUrl,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // تحديث معلومات المستخدم في Firebase
      await _userLocationService.updateUserInfo(
        name: name,
        email: email,
        phone: phone,
        carModel: carModel,
        carColor: carColor,
        plateNumber: plateNumber,
        profileImageUrl: profileImageUrl,
        isAvailableForHelp: true,
      );

      // بدء تتبع الموقع
      _userLocationService.startLocationTracking();

      debugPrint('User signed in and info updated: $email');
    } catch (e) {
      debugPrint('Error signing in user: $e');
      throw Exception('Failed to sign in user: $e');
    }
  }

  // تسجيل خروج المستخدم
  Future<void> signOutUser() async {
    try {
      // إيقاف تتبع الموقع
      _userLocationService.stopLocationTracking();

      // تحديث حالة المستخدم إلى غير متصل
      await _userLocationService.setUserOffline();

      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error signing out user: $e');
    }
  }

  // تحديث موقع المستخدم
  Future<void> updateUserLocation(double latitude, double longitude) async {
    try {
      await _userLocationService.updateUserLocation(
        gmaps.LatLng(latitude, longitude),
      );
    } catch (e) {
      debugPrint('Error updating user location: $e');
    }
  }

  // إرسال طلب مساعدة (محدث لاستخدام ServiceRouter)
  Future<String> sendHelpRequest({
    required String receiverId,
    required String receiverName,
    required double senderLat,
    required double senderLng,
    required double receiverLat,
    required double receiverLng,
    String? message,
  }) async {
    try {
      // Help requests are now only available for Google authenticated users
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            'Help request system is only available for Google authenticated users');
      }

      // التحقق من الأمان قبل الإرسال
      final validation = await HelpRequestSecurityValidator.validateHelpRequest(
        receiverId: receiverId,
        receiverName: receiverName,
        senderLocation: gmaps.LatLng(senderLat, senderLng),
        receiverLocation: gmaps.LatLng(receiverLat, receiverLng),
        message: message,
      );

      if (!validation['isValid']) {
        final errors = validation['errors'] as List<String>;
        throw Exception('Validation failed: ${errors.join(', ')}');
      }

      // تنظيف الرسالة
      final sanitizedMessage =
          HelpRequestSecurityValidator.sanitizeMessage(message);

      final requestId = await _helpRequestService.sendHelpRequest(
        receiverId: receiverId,
        receiverName: receiverName,
        senderLocation: gmaps.LatLng(senderLat, senderLng),
        receiverLocation: gmaps.LatLng(receiverLat, receiverLng),
        message: sanitizedMessage,
      );

      // تسجيل الإحصائيات
      final distance = _calculateDistance(
        gmaps.LatLng(senderLat, senderLng),
        gmaps.LatLng(receiverLat, receiverLng),
      );

      await _analytics.trackHelpRequestSent(
        requestId: requestId,
        senderId: currentUser.uid,
        receiverId: receiverId,
        distance: distance,
      );

      return requestId;
    } catch (e) {
      debugPrint('Error sending help request: $e');
      throw Exception('Failed to send help request: $e');
    }
  }

  // الرد على طلب مساعدة
  Future<void> respondToHelpRequest({
    required String requestId,
    required bool accept,
    String? estimatedArrival,
  }) async {
    try {
      final startTime = DateTime.now();

      await _helpRequestService.respondToHelpRequest(
        requestId: requestId,
        accept: accept,
        estimatedArrival: estimatedArrival,
      );

      // تسجيل الإحصائيات
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final responseTime = DateTime.now().difference(startTime);
        await _analytics.trackHelpRequestResponse(
          requestId: requestId,
          responderId: currentUser.uid,
          accepted: accept,
          responseTime: responseTime,
        );
      }
    } catch (e) {
      debugPrint('Error responding to help request: $e');
      throw Exception('Failed to respond to help request: $e');
    }
  }

  // إضافة إشعار
  Future<void> addNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      // استخدام FCM v1 Service لإرسال الإشعارات
      final fcmService = FCMv1Service();
      await fcmService.sendPushNotification(
        userId: userId,
        title: title,
        body: message,
        data: data,
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // حساب المسافة بين نقطتين
  double _calculateDistance(gmaps.LatLng point1, gmaps.LatLng point2) {
    return HelpRequestSecurityValidator.calculateDistance(
      gmaps.LatLng(point1.latitude, point1.longitude),
      gmaps.LatLng(point2.latitude, point2.longitude),
    );
  }

  // تنظيف الموارد
  void dispose() {
    _deliveryMonitor.dispose();
    _cleanupService.dispose();
    _userLocationService.dispose();
    _helpRequestService.dispose();
  }

  // التحقق من حالة الاتصال
  bool get isInitialized => _isInitialized;

  // الحصول على معرف المستخدم الحالي
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // التحقق من تسجيل الدخول
  bool get isUserSignedIn => FirebaseAuth.instance.currentUser != null;
}

// كلاس مساعد لـ LatLng
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  // تحويل إلى Map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // إنشاء من Map
  factory LatLng.fromMap(Map<String, dynamic> map) {
    return LatLng(
      (map['latitude'] as num).toDouble(),
      (map['longitude'] as num).toDouble(),
    );
  }
}
