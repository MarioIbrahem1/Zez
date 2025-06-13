import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Analytics service for help request system
class HelpRequestAnalytics {
  static final HelpRequestAnalytics _instance = HelpRequestAnalytics._internal();
  factory HelpRequestAnalytics() => _instance;
  HelpRequestAnalytics._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Track help request sent
  Future<void> trackHelpRequestSent({
    required String requestId,
    required String senderId,
    required String receiverId,
    required double distance,
  }) async {
    try {
      await _database.ref('analytics/help_requests_sent').push().set({
        'requestId': requestId,
        'senderId': senderId,
        'receiverId': receiverId,
        'distance': distance,
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
    } catch (e) {
      debugPrint('📊 Analytics: Error tracking help request sent: $e');
    }
  }

  /// Track help request response
  Future<void> trackHelpRequestResponse({
    required String requestId,
    required String responderId,
    required bool accepted,
    required Duration responseTime,
  }) async {
    try {
      await _database.ref('analytics/help_requests_responses').push().set({
        'requestId': requestId,
        'responderId': responderId,
        'accepted': accepted,
        'responseTimeSeconds': responseTime.inSeconds,
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
    } catch (e) {
      debugPrint('📊 Analytics: Error tracking help request response: $e');
    }
  }

  /// Track notification delivery
  Future<void> trackNotificationDelivery({
    required String requestId,
    required String userId,
    required bool success,
    required Duration deliveryTime,
  }) async {
    try {
      await _database.ref('analytics/notification_delivery').push().set({
        'requestId': requestId,
        'userId': userId,
        'success': success,
        'deliveryTimeMs': deliveryTime.inMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
    } catch (e) {
      debugPrint('📊 Analytics: Error tracking notification delivery: $e');
    }
  }

  /// Get daily statistics
  Future<Map<String, dynamic>> getDailyStats([DateTime? date]) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = targetDate.toIso8601String().split('T')[0];
      
      final stats = <String, dynamic>{
        'date': dateStr,
        'requests_sent': 0,
        'requests_accepted': 0,
        'requests_rejected': 0,
        'avg_response_time': 0.0,
        'notification_success_rate': 0.0,
      };

      // Get requests sent
      final sentSnapshot = await _database
          .ref('analytics/help_requests_sent')
          .orderByChild('date')
          .equalTo(dateStr)
          .get();
      
      if (sentSnapshot.exists) {
        stats['requests_sent'] = (sentSnapshot.value as Map).length;
      }

      // Get responses
      final responsesSnapshot = await _database
          .ref('analytics/help_requests_responses')
          .orderByChild('date')
          .equalTo(dateStr)
          .get();
      
      if (responsesSnapshot.exists) {
        final responses = responsesSnapshot.value as Map<dynamic, dynamic>;
        int accepted = 0;
        int rejected = 0;
        int totalResponseTime = 0;
        
        for (final response in responses.values) {
          final responseData = response as Map<dynamic, dynamic>;
          if (responseData['accepted'] == true) {
            accepted++;
          } else {
            rejected++;
          }
          totalResponseTime += (responseData['responseTimeSeconds'] as int? ?? 0);
        }
        
        stats['requests_accepted'] = accepted;
        stats['requests_rejected'] = rejected;
        stats['avg_response_time'] = responses.length > 0 
            ? totalResponseTime / responses.length 
            : 0.0;
      }

      // Get notification delivery stats
      final notifSnapshot = await _database
          .ref('analytics/notification_delivery')
          .orderByChild('date')
          .equalTo(dateStr)
          .get();
      
      if (notifSnapshot.exists) {
        final notifications = notifSnapshot.value as Map<dynamic, dynamic>;
        int successful = 0;
        
        for (final notif in notifications.values) {
          final notifData = notif as Map<dynamic, dynamic>;
          if (notifData['success'] == true) {
            successful++;
          }
        }
        
        stats['notification_success_rate'] = notifications.length > 0 
            ? (successful / notifications.length) * 100 
            : 0.0;
      }

      return stats;
      
    } catch (e) {
      debugPrint('📊 Analytics: Error getting daily stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Get system health metrics
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final now = DateTime.now();
      final last24h = now.subtract(const Duration(hours: 24));
      
      final health = <String, dynamic>{
        'timestamp': now.toIso8601String(),
        'status': 'healthy',
        'issues': <String>[],
      };

      // Check recent activity
      final recentRequests = await _database
          .ref('helpRequests')
          .orderByChild('createdAt')
          .startAt(last24h.toIso8601String())
          .get();
      
      health['active_requests_24h'] = recentRequests.exists 
          ? (recentRequests.value as Map).length 
          : 0;

      // Check for stuck requests (pending > 1 hour)
      final stuckCutoff = now.subtract(const Duration(hours: 1));
      final allRequests = await _database.ref('helpRequests').get();
      
      if (allRequests.exists) {
        final requests = allRequests.value as Map<dynamic, dynamic>;
        int stuckCount = 0;
        
        for (final request in requests.values) {
          final requestData = request as Map<dynamic, dynamic>;
          if (requestData['status'] == 'pending') {
            final createdAt = DateTime.parse(requestData['createdAt']);
            if (createdAt.isBefore(stuckCutoff)) {
              stuckCount++;
            }
          }
        }
        
        health['stuck_requests'] = stuckCount;
        if (stuckCount > 5) {
          health['issues'].add('High number of stuck requests: $stuckCount');
          health['status'] = 'warning';
        }
      }

      return health;
      
    } catch (e) {
      debugPrint('📊 Analytics: Error getting system health: $e');
      return {
        'status': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
