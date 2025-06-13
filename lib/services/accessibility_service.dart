import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// خدمة للتحقق من حالة Accessibility Service وإدارتها
class AccessibilityService {
  static const MethodChannel _channel =
      MethodChannel('com.example.road_helperr/accessibility');

  /// التحقق من تفعيل Accessibility Service
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool isEnabled =
          await _channel.invokeMethod('isAccessibilityServiceEnabled');
      debugPrint('🔍 AccessibilityService: Service enabled: $isEnabled');
      return isEnabled;
    } catch (e) {
      debugPrint('❌ AccessibilityService: Error checking service status: $e');
      return false;
    }
  }

  /// فتح إعدادات Accessibility
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      debugPrint('✅ AccessibilityService: Accessibility settings opened');
    } catch (e) {
      debugPrint('❌ AccessibilityService: Error opening settings: $e');
    }
  }

  /// التحقق من الحالة وإظهار رسالة إذا لزم الأمر
  static Future<bool> checkAndPromptIfNeeded() async {
    final isEnabled = await isAccessibilityServiceEnabled();

    if (!isEnabled) {
      debugPrint(
          '⚠️ AccessibilityService: Service not enabled - user action required');
      return false;
    }

    debugPrint('✅ AccessibilityService: Service is enabled and ready');
    return true;
  }

  /// Get instruction message for the user
  static String getInstructionMessage() {
    return '''
To enable SOS Emergency Service for power button detection:

1. Tap "Open Settings" below
2. Go to Android Settings → Accessibility
3. Look for "Installed Apps" or "Downloaded Apps" section
4. Find and select "Road Helper"
5. Toggle the service ON
6. Tap "Allow" in the popup dialog

This allows the app to detect triple power button presses for emergency alerts.
''';
  }

  /// Get short message
  static String getShortMessage() {
    return 'Enable accessibility service to use SOS power button trigger';
  }

  /// Get alert title
  static String getAlertTitle() {
    return 'Enable SOS Emergency Service';
  }
}
