import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS-specific SOS service implementation
/// Provides iOS-equivalent functionality for emergency services
class IOSSOSService {
  static const MethodChannel _sosChannel =
      MethodChannel('com.example.road_helperr/sos_ios');
  static const MethodChannel _powerButtonChannel =
      MethodChannel('com.example.road_helperr/power_button');

  static IOSSOSService? _instance;
  static IOSSOSService get instance => _instance ??= IOSSOSService._();

  IOSSOSService._();

  /// Initialize iOS SOS services
  Future<void> initialize() async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ IOSSOSService: Not running on iOS, skipping initialization');
      return;
    }

    try {
      debugPrint('🍎 IOSSOSService: Initializing iOS SOS services...');

      // Setup method call handlers for iOS-specific functionality
      _powerButtonChannel.setMethodCallHandler(_handlePowerButtonCall);

      debugPrint('✅ IOSSOSService: iOS SOS services initialized successfully');
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error initializing iOS SOS services: $e');
      rethrow;
    }
  }

  /// Handle power button related calls from iOS
  Future<void> _handlePowerButtonCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onTriplePowerPress':
          debugPrint('🚨 IOSSOSService: Triple power press detected from iOS');
          await _triggerEmergencyAlert();
          break;
        case 'onVolumeButtonEmergency':
          debugPrint('🚨 IOSSOSService: Volume button emergency detected from iOS');
          await _triggerEmergencyAlert();
          break;
        default:
          debugPrint('❓ IOSSOSService: Unknown method: ${call.method}');
      }
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error handling power button call: $e');
    }
  }

  /// Trigger emergency alert (iOS implementation)
  Future<void> _triggerEmergencyAlert() async {
    try {
      debugPrint('🚨 IOSSOSService: Triggering emergency alert...');

      // Import and use the main SOS service
      final sosService = await _getSOSService();
      if (sosService != null) {
        await sosService.triggerSosAlert();
        debugPrint('✅ IOSSOSService: Emergency alert triggered successfully');
      } else {
        debugPrint('❌ IOSSOSService: Could not get SOS service instance');
      }
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error triggering emergency alert: $e');
    }
  }

  /// Get SOS service instance dynamically to avoid circular imports
  Future<dynamic> _getSOSService() async {
    try {
      // Use reflection or dynamic import to get SOS service
      // This avoids circular dependency issues
      return null; // Will be implemented with proper service injection
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error getting SOS service: $e');
      return null;
    }
  }

  /// Send emergency SMS using iOS native implementation
  Future<bool> sendEmergencySMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ IOSSOSService: Not running on iOS');
      return false;
    }

    try {
      debugPrint('📱 IOSSOSService: Sending emergency SMS to ${phoneNumbers.length} recipients');

      final result = await _sosChannel.invokeMethod('sendEmergencySMS', {
        'phoneNumbers': phoneNumbers,
        'message': message,
      });

      debugPrint('📱 IOSSOSService: SMS sending result: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error sending emergency SMS: $e');
      return false;
    }
  }

  /// Trigger emergency alert with custom message
  Future<bool> triggerEmergencyAlert({
    required String title,
    required String body,
  }) async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ IOSSOSService: Not running on iOS');
      return false;
    }

    try {
      debugPrint('🚨 IOSSOSService: Triggering emergency alert: $title');

      final result = await _sosChannel.invokeMethod('triggerEmergencyAlert', {
        'title': title,
        'body': body,
      });

      debugPrint('🚨 IOSSOSService: Emergency alert result: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error triggering emergency alert: $e');
      return false;
    }
  }

  /// Check emergency permissions on iOS
  Future<Map<String, bool>> checkEmergencyPermissions() async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ IOSSOSService: Not running on iOS');
      return {};
    }

    try {
      debugPrint('🔍 IOSSOSService: Checking emergency permissions...');

      final result = await _sosChannel.invokeMethod('checkEmergencyPermissions');

      if (result is Map) {
        final permissions = Map<String, bool>.from(result);
        debugPrint('🔍 IOSSOSService: Permissions: $permissions');
        return permissions;
      }

      return {};
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error checking permissions: $e');
      return {};
    }
  }

  /// Start iOS-specific emergency monitoring
  Future<void> startEmergencyMonitoring() async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ IOSSOSService: Not running on iOS');
      return;
    }

    try {
      debugPrint('🔄 IOSSOSService: Starting emergency monitoring...');

      // Start volume button monitoring (iOS alternative to power button)
      await _sosChannel.invokeMethod('startVolumeButtonMonitoring');

      // Start app state monitoring
      await _sosChannel.invokeMethod('startAppStateMonitoring');

      debugPrint('✅ IOSSOSService: Emergency monitoring started');
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error starting emergency monitoring: $e');
    }
  }

  /// Stop iOS-specific emergency monitoring
  Future<void> stopEmergencyMonitoring() async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ IOSSOSService: Not running on iOS');
      return;
    }

    try {
      debugPrint('🛑 IOSSOSService: Stopping emergency monitoring...');

      await _sosChannel.invokeMethod('stopEmergencyMonitoring');

      debugPrint('✅ IOSSOSService: Emergency monitoring stopped');
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error stopping emergency monitoring: $e');
    }
  }

  /// Get iOS-specific emergency instructions
  static String getIOSEmergencyInstructions() {
    return '''
iOS Emergency Features:

1. Volume Button Emergency:
   - Rapidly press Volume Up and Volume Down buttons alternately (6 times total)
   - This will trigger the emergency alert system

2. App State Emergency:
   - Quickly switch the app to background and foreground 3 times
   - Use the home button or app switcher

3. Manual Emergency:
   - Use the emergency button in the app
   - Access through SOS settings

4. Shake Gesture:
   - Shake your device vigorously to trigger emergency
   - Available when app is active

Note: iOS has different emergency detection methods compared to Android due to platform restrictions.
''';
  }

  /// Check if iOS emergency features are available
  static bool isIOSEmergencyAvailable() {
    return Platform.isIOS;
  }

  /// Get iOS emergency feature status
  Future<Map<String, dynamic>> getEmergencyFeatureStatus() async {
    if (!Platform.isIOS) {
      return {'available': false, 'reason': 'Not running on iOS'};
    }

    try {
      final permissions = await checkEmergencyPermissions();

      return {
        'available': true,
        'permissions': permissions,
        'features': {
          'volumeButtonDetection': true,
          'appStateDetection': true,
          'shakeGesture': true,
          'manualTrigger': true,
          'smsSupport': true,
          'notificationSupport': permissions['notifications'] ?? false,
          'locationSupport': permissions['location'] ?? false,
        },
        'instructions': getIOSEmergencyInstructions(),
      };
    } catch (e) {
      debugPrint('❌ IOSSOSService: Error getting feature status: $e');
      return {
        'available': false,
        'reason': 'Error checking features: $e',
      };
    }
  }

  /// Dispose of iOS SOS service
  void dispose() {
    debugPrint('🗑️ IOSSOSService: Disposing iOS SOS service');
    // Cleanup if needed
  }
}

/// iOS Emergency Detection Methods
enum IOSEmergencyMethod {
  volumeButton,
  appState,
  shakeGesture,
  manual,
}

/// iOS Emergency Configuration
class IOSEmergencyConfig {
  final bool enableVolumeButtonDetection;
  final bool enableAppStateDetection;
  final bool enableShakeGesture;
  final bool enableManualTrigger;
  final Duration detectionTimeout;
  final int requiredTriggerCount;

  const IOSEmergencyConfig({
    this.enableVolumeButtonDetection = true,
    this.enableAppStateDetection = true,
    this.enableShakeGesture = true,
    this.enableManualTrigger = true,
    this.detectionTimeout = const Duration(seconds: 2),
    this.requiredTriggerCount = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'enableVolumeButtonDetection': enableVolumeButtonDetection,
      'enableAppStateDetection': enableAppStateDetection,
      'enableShakeGesture': enableShakeGesture,
      'enableManualTrigger': enableManualTrigger,
      'detectionTimeoutMs': detectionTimeout.inMilliseconds,
      'requiredTriggerCount': requiredTriggerCount,
    };
  }
}
