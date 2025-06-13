import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service for cleaning up expired help requests
class HelpRequestCleanupService {
  static final HelpRequestCleanupService _instance = HelpRequestCleanupService._internal();
  factory HelpRequestCleanupService() => _instance;
  HelpRequestCleanupService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Timer? _cleanupTimer;
  bool _isRunning = false;

  /// Start automatic cleanup service
  void startCleanupService() {
    if (_isRunning) return;
    
    _isRunning = true;
    debugPrint('🧹 HelpRequestCleanup: Starting cleanup service...');
    
    // Run cleanup every 10 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _performCleanup();
    });
    
    // Run initial cleanup
    _performCleanup();
  }

  /// Stop cleanup service
  void stopCleanupService() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _isRunning = false;
    debugPrint('🧹 HelpRequestCleanup: Cleanup service stopped');
  }

  /// Perform cleanup of expired requests
  Future<void> _performCleanup() async {
    try {
      debugPrint('🧹 HelpRequestCleanup: Starting cleanup cycle...');
      
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 2)); // Clean requests older than 2 hours
      
      // Get all help requests
      final snapshot = await _database.ref('helpRequests').get();
      
      if (!snapshot.exists) {
        debugPrint('🧹 HelpRequestCleanup: No help requests found');
        return;
      }
      
      final requestsData = snapshot.value as Map<dynamic, dynamic>;
      int expiredCount = 0;
      int cleanedCount = 0;
      
      for (final entry in requestsData.entries) {
        final requestId = entry.key as String;
        final requestData = entry.value as Map<dynamic, dynamic>;
        
        try {
          // Check if request has expired
          final expiresAtStr = requestData['expiresAt'] as String?;
          final createdAtStr = requestData['createdAt'] as String?;
          final status = requestData['status'] as String?;
          
          bool shouldClean = false;
          String reason = '';
          
          // Check expiration time
          if (expiresAtStr != null) {
            final expiresAt = DateTime.parse(expiresAtStr);
            if (now.isAfter(expiresAt)) {
              shouldClean = true;
              reason = 'expired';
              expiredCount++;
            }
          }
          
          // Check old requests without expiration
          if (!shouldClean && createdAtStr != null) {
            final createdAt = DateTime.parse(createdAtStr);
            if (createdAt.isBefore(cutoffTime)) {
              shouldClean = true;
              reason = 'too_old';
            }
          }
          
          // Check completed/rejected requests older than 1 hour
          if (!shouldClean && (status == 'accepted' || status == 'rejected' || status == 'completed')) {
            if (createdAtStr != null) {
              final createdAt = DateTime.parse(createdAtStr);
              if (createdAt.isBefore(now.subtract(const Duration(hours: 1)))) {
                shouldClean = true;
                reason = 'completed_old';
              }
            }
          }
          
          if (shouldClean) {
            await _cleanupRequest(requestId, reason);
            cleanedCount++;
          }
          
        } catch (e) {
          debugPrint('🧹 HelpRequestCleanup: Error processing request $requestId: $e');
        }
      }
      
      debugPrint('🧹 HelpRequestCleanup: Cleanup completed - $cleanedCount requests cleaned ($expiredCount expired)');
      
      // Clean up old notifications as well
      await _cleanupOldNotifications();
      
    } catch (e) {
      debugPrint('🧹 HelpRequestCleanup: Error during cleanup: $e');
    }
  }

  /// Clean up a specific request
  Future<void> _cleanupRequest(String requestId, String reason) async {
    try {
      // Move to archive before deletion
      final requestSnapshot = await _database.ref('helpRequests/$requestId').get();
      
      if (requestSnapshot.exists) {
        final requestData = requestSnapshot.value as Map<dynamic, dynamic>;
        
        // Archive the request
        await _database.ref('archivedHelpRequests/$requestId').set({
          ...requestData,
          'archivedAt': DateTime.now().toIso8601String(),
          'archiveReason': reason,
        });
        
        // Delete from active requests
        await _database.ref('helpRequests/$requestId').remove();
        
        debugPrint('🧹 HelpRequestCleanup: Archived request $requestId (reason: $reason)');
      }
      
    } catch (e) {
      debugPrint('🧹 HelpRequestCleanup: Error cleaning request $requestId: $e');
    }
  }

  /// Clean up old notifications
  Future<void> _cleanupOldNotifications() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(days: 7)); // Keep notifications for 7 days
      
      final notificationsSnapshot = await _database.ref('notifications').get();
      
      if (!notificationsSnapshot.exists) return;
      
      final notificationsData = notificationsSnapshot.value as Map<dynamic, dynamic>;
      int cleanedNotifications = 0;
      
      for (final userEntry in notificationsData.entries) {
        final userId = userEntry.key as String;
        final userNotifications = userEntry.value as Map<dynamic, dynamic>;
        
        for (final notifEntry in userNotifications.entries) {
          final notifId = notifEntry.key as String;
          final notifData = notifEntry.value as Map<dynamic, dynamic>;
          
          final createdAtStr = notifData['createdAt'] as String?;
          if (createdAtStr != null) {
            final createdAt = DateTime.parse(createdAtStr);
            if (createdAt.isBefore(cutoffTime)) {
              await _database.ref('notifications/$userId/$notifId').remove();
              cleanedNotifications++;
            }
          }
        }
      }
      
      if (cleanedNotifications > 0) {
        debugPrint('🧹 HelpRequestCleanup: Cleaned $cleanedNotifications old notifications');
      }
      
    } catch (e) {
      debugPrint('🧹 HelpRequestCleanup: Error cleaning notifications: $e');
    }
  }

  /// Manual cleanup trigger
  Future<void> performManualCleanup() async {
    debugPrint('🧹 HelpRequestCleanup: Manual cleanup triggered');
    await _performCleanup();
  }

  /// Get cleanup statistics
  Future<Map<String, dynamic>> getCleanupStats() async {
    try {
      final stats = <String, dynamic>{};
      
      // Count active requests
      final activeSnapshot = await _database.ref('helpRequests').get();
      stats['active_requests'] = activeSnapshot.exists 
          ? (activeSnapshot.value as Map<dynamic, dynamic>).length 
          : 0;
      
      // Count archived requests
      final archivedSnapshot = await _database.ref('archivedHelpRequests').get();
      stats['archived_requests'] = archivedSnapshot.exists 
          ? (archivedSnapshot.value as Map<dynamic, dynamic>).length 
          : 0;
      
      stats['cleanup_running'] = _isRunning;
      stats['last_cleanup'] = DateTime.now().toIso8601String();
      
      return stats;
      
    } catch (e) {
      debugPrint('🧹 HelpRequestCleanup: Error getting stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Dispose resources
  void dispose() {
    stopCleanupService();
  }
}
