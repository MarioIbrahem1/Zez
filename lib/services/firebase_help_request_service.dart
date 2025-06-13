import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_helperr/models/help_request.dart';
import 'package:road_helperr/services/fcm_v1_service.dart';
import 'package:road_helperr/services/chat_service.dart';

class FirebaseHelpRequestService {
  static final FirebaseHelpRequestService _instance =
      FirebaseHelpRequestService._internal();
  factory FirebaseHelpRequestService() => _instance;
  FirebaseHelpRequestService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // إرسال طلب مساعدة
  Future<String> sendHelpRequest({
    required String receiverId,
    required String receiverName,
    required LatLng senderLocation,
    required LatLng receiverLocation,
    String? message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // إنشاء ID جديد للطلب
      final requestRef = _database.child('helpRequests').push();
      final requestId = requestRef.key!;

      // الحصول على اسم المرسل من مصادر متعددة
      String senderName = currentUser.displayName ?? 'Unknown User';

      // محاولة الحصول على اسم أفضل من SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedName = prefs.getString('user_name');
        if (savedName != null &&
            savedName.isNotEmpty &&
            savedName != 'مستخدم') {
          senderName = savedName;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get sender name from SharedPreferences: $e');
      }

      debugPrint('📤 Help Request: Sender name resolved to: $senderName');

      // الحصول على بيانات إضافية للمرسل من SharedPreferences
      String senderPhone = '';
      String senderCarModel = '';
      String senderCarColor = '';
      String senderPlateNumber = '';

      try {
        final prefs = await SharedPreferences.getInstance();
        senderPhone = prefs.getString('user_phone') ?? '';
        senderCarModel = prefs.getString('user_car_model') ?? '';
        senderCarColor = prefs.getString('user_car_color') ?? '';
        senderPlateNumber = prefs.getString('user_plate_number') ?? '';

        debugPrint('📋 Help Request: Sender details loaded:');
        debugPrint('   - Phone: $senderPhone');
        debugPrint('   - Car Model: $senderCarModel');
        debugPrint('   - Car Color: $senderCarColor');
        debugPrint('   - Plate Number: $senderPlateNumber');
      } catch (e) {
        debugPrint(
            '⚠️ Could not load sender details from SharedPreferences: $e');
      }

      // بيانات الطلب مع تفاصيل كاملة
      final helpRequestData = {
        'requestId': requestId,
        'senderId': currentUser.uid,
        'senderName': senderName,
        'senderEmail': currentUser.email ?? '',
        'senderPhone': senderPhone,
        'senderCarModel': senderCarModel,
        'senderCarColor': senderCarColor,
        'senderPlateNumber': senderPlateNumber,
        'senderLocation': {
          'latitude': senderLocation.latitude,
          'longitude': senderLocation.longitude,
        },
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverLocation': {
          'latitude': receiverLocation.latitude,
          'longitude': receiverLocation.longitude,
        },
        'message': message ?? 'I need help with my car. Can you assist me?',
        'status': 'pending',
        'timestamp': ServerValue.timestamp,
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt':
            DateTime.now().add(Duration(minutes: 30)).toIso8601String(),
        'priority': 'normal',
        'deliveryStatus': 'pending',
      };

      // حفظ الطلب في Firebase
      await requestRef.set(helpRequestData);

      // إرسال إشعار للمستقبل
      await _sendNotificationToUser(
        receiverId,
        requestId,
        'help_request',
        'طلب مساعدة جديد من $senderName',
        helpRequestData,
      );

      debugPrint('Help request sent successfully: $requestId');
      return requestId;
    } catch (e) {
      debugPrint('Error sending help request: $e');
      throw Exception('Failed to send help request: $e');
    }
  }

  // الرد على طلب المساعدة
  Future<void> respondToHelpRequest({
    required String requestId,
    required bool accept,
    String? estimatedArrival,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final updates = {
        'status': accept ? 'accepted' : 'rejected',
        'respondedAt': ServerValue.timestamp,
        'responderId': currentUser.uid,
        'responderName': currentUser.displayName ?? 'Unknown User',
      };

      if (accept && estimatedArrival != null) {
        updates['estimatedArrival'] = estimatedArrival;
      }

      await _database.child('helpRequests/$requestId').update(updates);

      // إرسال إشعار للمرسل بالرد
      final requestSnapshot =
          await _database.child('helpRequests/$requestId').get();
      if (requestSnapshot.exists) {
        final requestData = requestSnapshot.value as Map<dynamic, dynamic>;
        final senderId = requestData['senderId'];

        await _sendNotificationToUser(
          senderId,
          requestId,
          'help_response',
          accept
              ? 'تم قبول طلب المساعدة من ${currentUser.displayName ?? 'مستخدم'}'
              : 'تم رفض طلب المساعدة',
          Map<String, dynamic>.from(requestData),
        );

        // Create chat room if help request is accepted
        if (accept) {
          try {
            final chatService = ChatService();
            await chatService.createChatFromHelpRequest(
              helpRequestId: requestId,
              senderId: senderId,
              receiverId: currentUser.uid,
              senderName: requestData['senderName'] ?? 'Unknown User',
              receiverName: currentUser.displayName ?? 'Unknown User',
            );
            debugPrint(
                '✅ Chat room created for accepted help request: $requestId');
          } catch (e) {
            debugPrint('❌ Error creating chat room for help request: $e');
            // Don't throw error as the main help request response succeeded
          }
        }
      }

      debugPrint(
          'Help request response sent: $requestId - ${accept ? 'accepted' : 'rejected'}');
    } catch (e) {
      debugPrint('Error responding to help request: $e');
      throw Exception('Failed to respond to help request: $e');
    }
  }

  // الاستماع للطلبات الواردة للمستخدم الحالي
  Stream<List<HelpRequest>> listenToIncomingHelpRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _database
        .child('helpRequests')
        .orderByChild('receiverId')
        .equalTo(currentUser.uid)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <HelpRequest>[];

      return data.entries
          .map((entry) => _helpRequestFromFirebase(entry.key, entry.value))
          .where((request) => request.status == HelpRequestStatus.pending)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // الاستماع لطلبات المساعدة المرسلة من المستخدم الحالي
  Stream<List<HelpRequest>> listenToSentHelpRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _database
        .child('helpRequests')
        .orderByChild('senderId')
        .equalTo(currentUser.uid)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <HelpRequest>[];

      return data.entries
          .map((entry) => _helpRequestFromFirebase(entry.key, entry.value))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // جلب طلب مساعدة محدد
  Future<HelpRequest?> getHelpRequestById(String requestId) async {
    try {
      final snapshot = await _database.child('helpRequests/$requestId').get();
      if (snapshot.exists) {
        return _helpRequestFromFirebase(requestId, snapshot.value);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting help request: $e');
      return null;
    }
  }

  // إرسال إشعار للمستخدم مع Push Notification
  Future<void> _sendNotificationToUser(
    String userId,
    String requestId,
    String type,
    String message,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint(
          '🔔 Firebase Help Request: Sending notification to user: $userId');
      debugPrint('📝 Notification type: $type');
      debugPrint('📄 Message: $message');

      final notificationRef = _database.child('notifications/$userId').push();

      await notificationRef.set({
        'id': notificationRef.key,
        'type': type,
        'requestId': requestId,
        'title':
            type == 'help_request' ? 'طلب مساعدة جديد' : 'رد على طلب المساعدة',
        'message': message,
        'data': data,
        'timestamp': ServerValue.timestamp,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      debugPrint(
          '✅ Firebase Help Request: Notification saved to Firebase Database');

      // إرسال Push Notification حقيقية مع بيانات محسنة
      await _sendPushNotification(
        userId: userId,
        title:
            type == 'help_request' ? 'طلب مساعدة جديد' : 'رد على طلب المساعدة',
        body: message,
        data: {
          ...data,
          'type': type,
          'requestId': requestId,
          'receiverId': userId, // إضافة معرف المستقبل للتأكد
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase Help Request: Error sending notification: $e');
    }
  }

  // إرسال Push Notification باستخدام الخدمة الموحدة مع آلية إعادة المحاولة
  Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint(
          '🔔 Firebase: Sending unified push notification to user: $userId');

      // استخدام FCM v1 API مع آلية إعادة المحاولة
      final fcmService = FCMv1Service();

      bool success = false;
      int retryCount = 0;
      const maxRetries = 3;

      while (!success && retryCount < maxRetries) {
        try {
          success = await fcmService.sendPushNotification(
            userId: userId,
            title: title,
            body: body,
            data: data,
          );

          if (success) {
            debugPrint(
                '✅ Firebase: Push notification sent successfully on attempt ${retryCount + 1}');

            // Mark notification as delivered if requestId is available
            if (data != null && data['requestId'] != null) {
              await _markNotificationAsDelivered(userId, data['requestId']);
            }
            break;
          } else {
            retryCount++;
            if (retryCount < maxRetries) {
              debugPrint(
                  '⚠️ Firebase: Push notification failed, retrying... (${retryCount}/$maxRetries)');
              await Future.delayed(
                  Duration(seconds: retryCount * 2)); // Exponential backoff
            }
          }
        } catch (retryError) {
          retryCount++;
          debugPrint('❌ Firebase: Retry $retryCount failed: $retryError');
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: retryCount * 2));
          }
        }
      }

      if (!success) {
        debugPrint(
            '⚠️ Firebase: All push notification attempts failed, relying on Firebase Database fallback');
        // Mark as failed delivery for monitoring
        if (data != null && data['requestId'] != null) {
          await _markNotificationAsFailed(userId, data['requestId']);
        }
      }
    } catch (e) {
      debugPrint('❌ Firebase: Error sending push notification: $e');
      // Mark as failed if requestId is available
      if (data != null && data['requestId'] != null) {
        await _markNotificationAsFailed(userId, data['requestId']);
      }
    }
  }

  /// Mark notification as delivered
  Future<void> _markNotificationAsDelivered(
      String userId, String requestId) async {
    try {
      await _database.child('helpRequests/$requestId').update({
        'deliveryStatus': 'delivered',
        'deliveredAt': ServerValue.timestamp,
      });
      debugPrint(
          '✅ Firebase: Notification marked as delivered for request: $requestId');
    } catch (e) {
      debugPrint('❌ Firebase: Error marking notification as delivered: $e');
    }
  }

  /// Mark notification as failed
  Future<void> _markNotificationAsFailed(
      String userId, String requestId) async {
    try {
      await _database.child('helpRequests/$requestId').update({
        'deliveryStatus': 'failed',
        'deliveryFailedAt': ServerValue.timestamp,
        'fallbackUsed': true,
      });
      debugPrint(
          '⚠️ Firebase: Notification marked as failed for request: $requestId');
    } catch (e) {
      debugPrint('❌ Firebase: Error marking notification as failed: $e');
    }
  }

  // تحويل بيانات Firebase إلى HelpRequest
  HelpRequest _helpRequestFromFirebase(String requestId, dynamic data) {
    final requestData = data as Map<dynamic, dynamic>;

    return HelpRequest(
      requestId: requestId,
      senderId: requestData['senderId'] ?? '',
      senderName: requestData['senderName'] ?? 'Unknown',
      senderPhone: requestData['senderPhone'],
      senderCarModel: requestData['senderCarModel'],
      senderCarColor: requestData['senderCarColor'],
      senderPlateNumber: requestData['senderPlateNumber'],
      senderLocation: LatLng(
        (requestData['senderLocation']['latitude'] as num).toDouble(),
        (requestData['senderLocation']['longitude'] as num).toDouble(),
      ),
      receiverId: requestData['receiverId'] ?? '',
      receiverName: requestData['receiverName'] ?? 'Unknown',
      receiverPhone: requestData['receiverPhone'],
      receiverCarModel: requestData['receiverCarModel'],
      receiverCarColor: requestData['receiverCarColor'],
      receiverPlateNumber: requestData['receiverPlateNumber'],
      receiverLocation: LatLng(
        (requestData['receiverLocation']['latitude'] as num).toDouble(),
        (requestData['receiverLocation']['longitude'] as num).toDouble(),
      ),
      timestamp: DateTime.parse(
          requestData['createdAt'] ?? DateTime.now().toIso8601String()),
      status: _parseStatus(requestData['status']),
      message: requestData['message'],
    );
  }

  // تحويل النص إلى enum
  HelpRequestStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return HelpRequestStatus.pending;
      case 'accepted':
        return HelpRequestStatus.accepted;
      case 'rejected':
        return HelpRequestStatus.rejected;
      case 'completed':
        return HelpRequestStatus.completed;
      case 'cancelled':
        return HelpRequestStatus.cancelled;
      default:
        return HelpRequestStatus.pending;
    }
  }

  // تنظيف الموارد
  void dispose() {
    // يمكن إضافة تنظيف إضافي هنا إذا لزم الأمر
  }
}
