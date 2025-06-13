import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Security validator for help request system
class HelpRequestSecurityValidator {
  /// Validate help request before sending
  static Future<Map<String, dynamic>> validateHelpRequest({
    required String receiverId,
    required String receiverName,
    required LatLng senderLocation,
    required LatLng receiverLocation,
    String? message,
  }) async {
    final result = <String, dynamic>{
      'isValid': false,
      'errors': <String>[],
      'warnings': <String>[],
    };

    try {
      // 1. Check authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        result['errors'].add('User not authenticated');
        return result;
      }

      // 2. Check if user is Google authenticated
      final isGoogleUser = currentUser.providerData
          .any((provider) => provider.providerId == 'google.com');
      if (!isGoogleUser) {
        result['errors'].add('Help requests only available for Google users');
        return result;
      }

      // 3. Validate receiver ID
      if (receiverId.isEmpty || receiverId == currentUser.uid) {
        result['errors'].add('Invalid receiver ID');
        return result;
      }

      // 4. Validate locations
      if (!_isValidLocation(senderLocation)) {
        result['errors'].add('Invalid sender location');
      }
      if (!_isValidLocation(receiverLocation)) {
        result['errors'].add('Invalid receiver location');
      }

      // 5. Check distance (reasonable range)
      final distance = calculateDistance(senderLocation, receiverLocation);
      if (distance > 100) {
        // 100 km max
        result['warnings']
            .add('Distance is very large: ${distance.toStringAsFixed(1)} km');
      }

      // 6. Validate message content
      if (message != null && message.length > 500) {
        result['errors'].add('Message too long (max 500 characters)');
      }

      // 7. Check rate limiting (max 5 requests per hour)
      final rateLimitCheck = await _checkRateLimit(currentUser.uid);
      if (!rateLimitCheck['allowed']) {
        result['errors']
            .add('Rate limit exceeded: ${rateLimitCheck['message']}');
      }

      result['isValid'] = (result['errors'] as List).isEmpty;
    } catch (e) {
      result['errors'].add('Validation error: $e');
    }

    return result;
  }

  /// Validate location coordinates
  static bool _isValidLocation(LatLng location) {
    return location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }

  /// Calculate distance between two points in kilometers
  static double calculateDistance(LatLng point1, LatLng point2) {
    // Simplified distance calculation using Haversine formula
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLng = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.asin(math.sqrt(a));

    return 6371 * c; // Earth's radius in km
  }

  /// Check rate limiting for user
  static Future<Map<String, dynamic>> _checkRateLimit(String userId) async {
    // This would typically check against a database
    // For now, return allowed
    return {
      'allowed': true,
      'remaining': 5,
      'resetTime': DateTime.now().add(Duration(hours: 1)),
    };
  }

  /// Sanitize message content
  static String sanitizeMessage(String? message) {
    if (message == null) return '';

    // Remove potentially harmful content
    String sanitized = message
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF.,!?-]'),
            '') // Keep only safe characters
        .trim();

    return sanitized.length > 500 ? sanitized.substring(0, 500) : sanitized;
  }
}
