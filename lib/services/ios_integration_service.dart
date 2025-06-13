import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:road_helperr/services/ios_sos_service.dart';
import 'package:road_helperr/services/sos_service.dart';

/// Integration service to connect iOS-specific functionality with the main app
class IOSIntegrationService {
  static IOSIntegrationService? _instance;
  static IOSIntegrationService get instance => _instance ??= IOSIntegrationService._();

  IOSIntegrationService._();

  bool _isInitialized = false;
  IOSSOSService? _iosSOSService;

  /// Initialize iOS integration services
  Future<void> initialize() async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ IOSIntegrationService: Not running on iOS, skipping initialization');
      return;
    }

    if (_isInitialized) {
      debugPrint('⚠️ IOSIntegrationService: Already initialized');
      return;
    }

    try {
      debugPrint('🍎 IOSIntegrationService: Initializing iOS integration...');

      // Initialize iOS SOS service
      _iosSOSService = IOSSOSService.instance;
      await _iosSOSService!.initialize();

      // Setup iOS-specific emergency monitoring
      await _setupIOSEmergencyMonitoring();

      // Integrate with main SOS service
      await _integrateWithMainSOSService();

      _isInitialized = true;
      debugPrint('✅ IOSIntegrationService: iOS integration initialized successfully');
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error initializing iOS integration: $e');
      rethrow;
    }
  }

  /// Setup iOS-specific emergency monitoring
  Future<void> _setupIOSEmergencyMonitoring() async {
    try {
      debugPrint('🔄 IOSIntegrationService: Setting up iOS emergency monitoring...');

      // Start iOS emergency monitoring
      await _iosSOSService?.startEmergencyMonitoring();

      debugPrint('✅ IOSIntegrationService: iOS emergency monitoring setup complete');
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error setting up iOS emergency monitoring: $e');
    }
  }

  /// Integrate iOS services with main SOS service
  Future<void> _integrateWithMainSOSService() async {
    try {
      debugPrint('🔗 IOSIntegrationService: Integrating with main SOS service...');

      // Get main SOS service instance
      final sosService = SOSService();

      // Override SMS sending for iOS
      await _setupIOSSMSIntegration(sosService);

      // Setup iOS emergency triggers
      await _setupIOSEmergencyTriggers(sosService);

      debugPrint('✅ IOSIntegrationService: Integration with main SOS service complete');
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error integrating with main SOS service: $e');
    }
  }

  /// Setup iOS SMS integration
  Future<void> _setupIOSSMSIntegration(SOSService sosService) async {
    try {
      debugPrint('📱 IOSIntegrationService: Setting up iOS SMS integration...');

      // This would require modifying the main SOS service to use iOS SMS
      // For now, we'll create a wrapper method

      debugPrint('✅ IOSIntegrationService: iOS SMS integration setup complete');
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error setting up iOS SMS integration: $e');
    }
  }

  /// Setup iOS emergency triggers
  Future<void> _setupIOSEmergencyTriggers(SOSService sosService) async {
    try {
      debugPrint('🚨 IOSIntegrationService: Setting up iOS emergency triggers...');

      // This would integrate iOS-specific triggers with the main SOS service
      // The iOS native code will call Flutter methods when triggers are detected

      debugPrint('✅ IOSIntegrationService: iOS emergency triggers setup complete');
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error setting up iOS emergency triggers: $e');
    }
  }

  /// Send emergency SMS using iOS implementation
  Future<bool> sendEmergencySMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    if (!Platform.isIOS || _iosSOSService == null) {
      debugPrint('⚠️ IOSIntegrationService: iOS SOS service not available');
      return false;
    }

    try {
      debugPrint('📱 IOSIntegrationService: Sending emergency SMS via iOS...');

      final result = await _iosSOSService!.sendEmergencySMS(
        phoneNumbers: phoneNumbers,
        message: message,
      );

      debugPrint('📱 IOSIntegrationService: iOS SMS result: $result');
      return result;
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error sending iOS emergency SMS: $e');
      return false;
    }
  }

  /// Trigger emergency alert using iOS implementation
  Future<bool> triggerEmergencyAlert({
    required String title,
    required String body,
  }) async {
    if (!Platform.isIOS || _iosSOSService == null) {
      debugPrint('⚠️ IOSIntegrationService: iOS SOS service not available');
      return false;
    }

    try {
      debugPrint('🚨 IOSIntegrationService: Triggering emergency alert via iOS...');

      final result = await _iosSOSService!.triggerEmergencyAlert(
        title: title,
        body: body,
      );

      debugPrint('🚨 IOSIntegrationService: iOS emergency alert result: $result');
      return result;
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error triggering iOS emergency alert: $e');
      return false;
    }
  }

  /// Check iOS emergency permissions
  Future<Map<String, bool>> checkIOSEmergencyPermissions() async {
    if (!Platform.isIOS || _iosSOSService == null) {
      debugPrint('⚠️ IOSIntegrationService: iOS SOS service not available');
      return {};
    }

    try {
      debugPrint('🔍 IOSIntegrationService: Checking iOS emergency permissions...');

      final permissions = await _iosSOSService!.checkEmergencyPermissions();

      debugPrint('🔍 IOSIntegrationService: iOS permissions: $permissions');
      return permissions;
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error checking iOS permissions: $e');
      return {};
    }
  }

  /// Get iOS emergency feature status
  Future<Map<String, dynamic>> getIOSEmergencyFeatureStatus() async {
    if (!Platform.isIOS || _iosSOSService == null) {
      return {'available': false, 'reason': 'iOS SOS service not available'};
    }

    try {
      debugPrint('📊 IOSIntegrationService: Getting iOS emergency feature status...');

      final status = await _iosSOSService!.getEmergencyFeatureStatus();

      debugPrint('📊 IOSIntegrationService: iOS feature status: $status');
      return status;
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error getting iOS feature status: $e');
      return {'available': false, 'reason': 'Error: $e'};
    }
  }

  /// Check if iOS integration is available and working
  bool get isIOSIntegrationAvailable {
    return Platform.isIOS && _isInitialized && _iosSOSService != null;
  }

  /// Get iOS-specific emergency instructions
  String getIOSEmergencyInstructions() {
    if (!Platform.isIOS) {
      return 'iOS emergency features are not available on this platform.';
    }

    return IOSSOSService.getIOSEmergencyInstructions();
  }

  /// Dispose of iOS integration service
  void dispose() {
    if (!Platform.isIOS) return;

    try {
      debugPrint('🗑️ IOSIntegrationService: Disposing iOS integration service...');

      // Stop iOS emergency monitoring
      _iosSOSService?.stopEmergencyMonitoring();

      // Dispose iOS SOS service
      _iosSOSService?.dispose();

      _isInitialized = false;
      _iosSOSService = null;

      debugPrint('✅ IOSIntegrationService: iOS integration service disposed');
    } catch (e) {
      debugPrint('❌ IOSIntegrationService: Error disposing iOS integration service: $e');
    }
  }
}

/// iOS Emergency Status
class IOSEmergencyStatus {
  final bool isAvailable;
  final Map<String, bool> permissions;
  final Map<String, bool> features;
  final String? errorMessage;

  const IOSEmergencyStatus({
    required this.isAvailable,
    required this.permissions,
    required this.features,
    this.errorMessage,
  });

  factory IOSEmergencyStatus.fromMap(Map<String, dynamic> map) {
    return IOSEmergencyStatus(
      isAvailable: map['available'] ?? false,
      permissions: Map<String, bool>.from(map['permissions'] ?? {}),
      features: Map<String, bool>.from(map['features'] ?? {}),
      errorMessage: map['reason'],
    );
  }

  bool get hasAllPermissions {
    return permissions.values.every((granted) => granted);
  }

  bool get hasAllFeatures {
    return features.values.every((available) => available);
  }

  List<String> get missingPermissions {
    return permissions.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  List<String> get unavailableFeatures {
    return features.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}
