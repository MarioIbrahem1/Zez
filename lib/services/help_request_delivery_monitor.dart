import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة مراقبة تسليم طلبات المساعدة لضمان الوصول
class HelpRequestDeliveryMonitor {
  static final HelpRequestDeliveryMonitor _instance =
      HelpRequestDeliveryMonitor._internal();
  factory HelpRequestDeliveryMonitor() => _instance;
  HelpRequestDeliveryMonitor._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;

  /// بدء مراقبة طلبات المساعدة غير المسلمة
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    debugPrint(
        '🔍 DeliveryMonitor: Starting help request delivery monitoring...');

    // فحص كل 30 ثانية للطلبات غير المسلمة
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkUndeliveredRequests();
    });

    // فحص فوري عند البدء
    _checkUndeliveredRequests();
  }

  /// إيقاف المراقبة
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    debugPrint('🛑 DeliveryMonitor: Stopped monitoring');
  }

  /// فحص الطلبات غير المسلمة وإعادة المحاولة
  Future<void> _checkUndeliveredRequests() async {
    try {
      debugPrint(
          '🔍 DeliveryMonitor: Checking for undelivered help requests...');

      // البحث عن الطلبات التي لم يتم تسليمها خلال آخر 5 دقائق
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));

      final snapshot = await _database
          .ref('helpRequests')
          .orderByChild('createdAt')
          .startAt(cutoffTime.toIso8601String())
          .get();

      if (!snapshot.exists) {
        debugPrint('📭 DeliveryMonitor: No recent help requests found');
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      int undeliveredCount = 0;
      int retryCount = 0;

      for (final entry in data.entries) {
        final requestData = entry.value as Map<dynamic, dynamic>;
        final deliveryStatus = requestData['deliveryStatus'] as String?;
        final requestId = entry.key as String;

        // التحقق من الطلبات غير المسلمة أو المعلقة
        if (deliveryStatus == null ||
            deliveryStatus == 'sending' ||
            deliveryStatus == 'failed') {
          undeliveredCount++;
          debugPrint(
              '⚠️ DeliveryMonitor: Found undelivered request: $requestId');

          // محاولة إعادة الإرسال
          final retrySuccess =
              await _retryHelpRequestDelivery(requestId, requestData);
          if (retrySuccess) {
            retryCount++;
          }
        }
      }

      if (undeliveredCount > 0) {
        debugPrint(
            '📊 DeliveryMonitor: Found $undeliveredCount undelivered requests, retried $retryCount successfully');

        // حفظ إحصائيات في SharedPreferences
        await _saveDeliveryStats(undeliveredCount, retryCount);
      } else {
        debugPrint('✅ DeliveryMonitor: All recent help requests are delivered');
      }
    } catch (e) {
      debugPrint('❌ DeliveryMonitor: Error checking undelivered requests: $e');
    }
  }

  /// إعادة محاولة تسليم طلب مساعدة
  Future<bool> _retryHelpRequestDelivery(
      String requestId, Map<dynamic, dynamic> requestData) async {
    try {
      debugPrint(
          '🔄 DeliveryMonitor: Retrying delivery for request: $requestId');

      final receiverId = requestData['receiverId'] as String?;
      final senderName = requestData['senderName'] as String?;

      if (receiverId == null || senderName == null) {
        debugPrint('❌ DeliveryMonitor: Missing required data for retry');
        return false;
      }

      // إنشاء إشعار جديد للمستقبل
      final notificationRef = _database.ref('notifications/$receiverId').push();

      await notificationRef.set({
        'id': notificationRef.key,
        'type': 'help_request',
        'requestId': requestId,
        'title': 'طلب مساعدة جديد',
        'message': 'طلب مساعدة جديد من $senderName (إعادة إرسال)',
        'data': requestData,
        'timestamp': ServerValue.timestamp,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        'isRetry': true,
        'originalRequestId': requestId,
      }).timeout(const Duration(seconds: 10));

      // تحديث حالة الطلب الأصلي
      await _database.ref('helpRequests/$requestId').update({
        'deliveryStatus': 'retry_sent',
        'lastRetryAt': ServerValue.timestamp,
        'retryCount': (requestData['retryCount'] as int? ?? 0) + 1,
      });

      debugPrint(
          '✅ DeliveryMonitor: Retry notification sent for request: $requestId');
      return true;
    } catch (e) {
      debugPrint(
          '❌ DeliveryMonitor: Error retrying delivery for $requestId: $e');

      // تحديث حالة الفشل
      try {
        await _database.ref('helpRequests/$requestId').update({
          'deliveryStatus': 'retry_failed',
          'lastRetryError': e.toString(),
          'lastRetryAt': ServerValue.timestamp,
        });
      } catch (updateError) {
        debugPrint(
            '❌ DeliveryMonitor: Error updating retry failure status: $updateError');
      }

      return false;
    }
  }

  /// حفظ إحصائيات التسليم
  Future<void> _saveDeliveryStats(int undeliveredCount, int retryCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await prefs.setInt('last_undelivered_count', undeliveredCount);
      await prefs.setInt('last_retry_count', retryCount);
      await prefs.setString('last_delivery_check', now.toIso8601String());

      // إحصائيات تراكمية
      final totalUndelivered =
          (prefs.getInt('total_undelivered_count') ?? 0) + undeliveredCount;
      final totalRetries =
          (prefs.getInt('total_retry_count') ?? 0) + retryCount;

      await prefs.setInt('total_undelivered_count', totalUndelivered);
      await prefs.setInt('total_retry_count', totalRetries);

      debugPrint(
          '📊 DeliveryMonitor: Stats saved - Total undelivered: $totalUndelivered, Total retries: $totalRetries');
    } catch (e) {
      debugPrint('❌ DeliveryMonitor: Error saving delivery stats: $e');
    }
  }

  /// الحصول على إحصائيات التسليم
  Future<Map<String, dynamic>> getDeliveryStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'lastUndeliveredCount': prefs.getInt('last_undelivered_count') ?? 0,
        'lastRetryCount': prefs.getInt('last_retry_count') ?? 0,
        'lastDeliveryCheck': prefs.getString('last_delivery_check'),
        'totalUndeliveredCount': prefs.getInt('total_undelivered_count') ?? 0,
        'totalRetryCount': prefs.getInt('total_retry_count') ?? 0,
      };
    } catch (e) {
      debugPrint('❌ DeliveryMonitor: Error getting delivery stats: $e');
      return {};
    }
  }

  /// فحص فوري للطلبات غير المسلمة
  Future<void> checkNow() async {
    debugPrint('🔍 DeliveryMonitor: Manual check triggered');
    await _checkUndeliveredRequests();
  }

  /// تنظيف الموارد
  void dispose() {
    stopMonitoring();
  }
}
