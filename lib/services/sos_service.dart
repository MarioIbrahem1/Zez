import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart' hide SmsStatus;
import '../models/sos_user_data.dart';
import 'auth_service.dart';
import 'sim_service.dart';
import 'direct_sms_service.dart';
import 'direct_sms_status_listener.dart';
import 'sos_permission_service.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();
  factory SOSService() => _instance;
  SOSService._internal();

  final Battery _battery = Battery();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  int _powerButtonPressCount = 0;
  Timer? _resetTimer;
  Timer? _locationTimer;
  Position? _lastKnownLocation;
  SOSUserData? _userData;

  Future<void> initialize() async {
    // Initialize notifications
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _notifications.initialize(initializationSettings);

    // Load user data
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString('sosUserData');
      print('🔍 SOS Initialize: Loading user data...');
      if (userDataJson != null) {
        print('✅ SOS Initialize: Found saved user data');
        final Map<String, dynamic> jsonMap = jsonDecode(userDataJson);
        _userData = SOSUserData.fromJson(jsonMap);
        print(
            '✅ SOS Initialize: User data loaded - ${_userData!.firstName} ${_userData!.lastName}');
        print(
            '✅ SOS Initialize: Emergency contacts: ${_userData!.emergencyContacts.length} contacts');
      } else {
        print(
            '⚠️ SOS Initialize: No saved user data found - User needs to set up emergency contacts');
      }
    } catch (e) {
      print('❌ SOS Initialize: Error loading SOS user data: $e');
      // If there's an error loading data, clear it to prevent future crashes
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sosUserData');
    }

    // Start location tracking
    _startLocationTracking();
  }

  void _startLocationTracking() async {
    print('🌍 SOS Location: Starting location tracking...');
    // Get location immediately
    try {
      _lastKnownLocation = await Geolocator.getCurrentPosition();
      print(
          '✅ SOS Location: Initial location obtained - ${_lastKnownLocation!.latitude}, ${_lastKnownLocation!.longitude}');
    } catch (e) {
      print('❌ SOS Location: Error getting initial location: $e');
    }

    // Then set up periodic updates
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        _lastKnownLocation = await Geolocator.getCurrentPosition();
        print(
            '🔄 SOS Location: Location updated - ${_lastKnownLocation!.latitude}, ${_lastKnownLocation!.longitude}');
      } catch (e) {
        print('❌ SOS Location: Error getting location update: $e');
      }
    });
  }

  Future<void> onPowerButtonPressed() async {
    _powerButtonPressCount++;
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      _powerButtonPressCount = 0;
    });

    if (_powerButtonPressCount >= 3) {
      await _sendSosMessage();
      _powerButtonPressCount = 0;
    }
  }

  // Public method to trigger SOS message from other services
  Future<bool> triggerSosAlert() async {
    print(
        '🚨 SOS Alert triggered - checking permissions and authentication...');

    // First check if all required permissions are granted
    final permissionService = SOSPermissionService();
    final hasPermissions = await permissionService.hasAllRequiredPermissions();

    if (!hasPermissions) {
      print('❌ SOS Alert failed - Required permissions not granted');
      print('   Please grant SOS permissions in app settings');
      return false;
    }

    print('✅ SOS permissions verified - checking authentication status...');

    // التحقق من إمكانية استخدام خدمات SOS حتى لو انتهت صلاحية الـ token
    final authService = AuthService();
    final canUseSos = await authService.canUseSosServices();

    if (!canUseSos) {
      print('❌ SOS Alert failed - SOS services not available');
      print('   Please ensure you have emergency contacts configured');
      return false;
    }

    print('✅ SOS services available - proceeding with alert...');
    return await _sendSosMessage();
  }

  Future<bool> _sendSosMessage() async {
    print('🚨 _sendSosMessageTAG - Starting SOS message process');

    // Get emergency contacts from AuthService (unified source)
    final authService = AuthService();
    final emergencyContacts = await authService.getEmergencyContacts();

    if (emergencyContacts.isEmpty) {
      print('❌ SOS FAILED: No emergency contacts found in AuthService');
      return false;
    }

    print(
        '✅ Emergency contacts from AuthService: ${emergencyContacts.length} contacts');
    for (int i = 0; i < emergencyContacts.length; i++) {
      print('   Contact ${i + 1}: ${emergencyContacts[i]}');
    }

    // Check user data for name (fallback to email if no name)
    String userName = 'Emergency User';
    if (_userData != null) {
      userName = '${_userData!.firstName} ${_userData!.lastName}';
      print('✅ User data found: $userName');
    } else {
      final userEmail = await authService.getUserEmail();
      userName = userEmail ?? 'Emergency User';
      print('⚠️ Using fallback user name: $userName');
    }

    // Debug: Check location
    if (_lastKnownLocation == null) {
      print(
          '❌ SOS FAILED: Location is null - Trying to get current location...');
      try {
        _lastKnownLocation = await Geolocator.getCurrentPosition();
        print(
            '✅ Location obtained: ${_lastKnownLocation!.latitude}, ${_lastKnownLocation!.longitude}');
      } catch (e) {
        print('❌ SOS FAILED: Could not get location: $e');
        return false;
      }
    } else {
      print(
          '✅ Location available: ${_lastKnownLocation!.latitude}, ${_lastKnownLocation!.longitude}');
    }

    if (_userData == null || _lastKnownLocation == null) {
      print(
          '❌ SOS FAILED: Missing required data - userData: ${_userData != null}, location: ${_lastKnownLocation != null}');
      return false;
    }

    final batteryLevel = await _battery.batteryLevel;

    // Create SOS message without links (to avoid blocking from mobile carriers)
    // while keeping coordinates and adding text description of location
    final message = '''
SOS! $userName needs help!
Current coordinates: ${_lastKnownLocation!.latitude}, ${_lastKnownLocation!.longitude}
Battery: $batteryLevel%
IMPORTANT: Copy the coordinates and put them in Google Maps to show the actual location.
''';

    try {
      // Show notification in status bar only without heads-up notification
      const androidDetails = AndroidNotificationDetails(
        'sos_channel',
        'SOS Alerts',
        channelDescription: 'Important SOS alerts',
        importance: Importance.high, // Changed from max to high
        priority: Priority.high,
        playSound: false, // Disable sound
        enableVibration: false, // Disable vibration
        fullScreenIntent: false, // Disable full screen intent
        visibility: NotificationVisibility
            .secret, // Show on lock screen only as a notification dot
        onlyAlertOnce:
            true, // Only alert the first time this notification is shown
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: false, // Don't show an alert
        presentBadge: true, // Show a badge
        presentSound: false, // Don't play a sound
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use a static notification ID to prevent multiple notifications
      await _notifications.show(
        1, // Use a fixed ID to replace any existing notification
        'SOS Service Active',
        'Triple press power button for emergency',
        details,
      );

      // Send SMS messages to all emergency contacts
      if (emergencyContacts.isNotEmpty) {
        // First try to send SMS directly
        bool smsSent = await _sendSMS(message, emergencyContacts);

        // If direct SMS fails, try using the default SMS app as a fallback
        if (!smsSent && emergencyContacts.isNotEmpty) {
          print('Direct SMS failed, trying to open default SMS app');
          await _sendSMSViaDefaultApp(emergencyContacts.first, message);
        }
      }

      print('Emergency messages sent successfully');
      return true;
    } catch (e) {
      print('Error sending emergency messages: $e');
      return false;
    }
  }

  Future<bool> _sendSMS(String message, List<String> emergencyContacts) async {
    try {
      // Initialize telephony and SimService
      final Telephony telephony = Telephony.instance;
      final SimService simService = SimService();

      // Check if device is SMS capable
      bool? isSmsCapable = await telephony.isSmsCapable;
      print('Device SMS capable: $isSmsCapable');

      if (isSmsCapable == false) {
        print('ERROR: Device is not SMS capable');
        return false;
      }

      // Check if app has SMS permissions
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      print('SMS permissions granted: $permissionsGranted');

      if (permissionsGranted ?? false) {
        // Check if there are any emergency contacts
        if (emergencyContacts.isEmpty) {
          print('ERROR: No emergency contacts found');
          return false;
        }

        print('Attempting to send SMS to ${emergencyContacts.length} contacts');

        // Check if device has dual SIM
        bool hasDualSim = await simService.hasDualSim();
        print('Device has dual SIM: $hasDualSim');

        // Track if any SMS was sent successfully
        bool anySmsSuccess = false;

        // Send SMS to all emergency contacts with optimized timing for emergencies
        for (int i = 0; i < emergencyContacts.length; i++) {
          String contact = emergencyContacts[i];
          print(
              '📱 Processing contact ${i + 1}/${emergencyContacts.length}: $contact');
          // Format phone number (remove any non-digit characters)
          String formattedNumber = contact.replaceAll(RegExp(r'[^\d+]'), '');

          // Add Egypt country code (+20) if needed for Egyptian numbers
          if (!formattedNumber.startsWith('+')) {
            // If number starts with 0, remove it before adding country code
            if (formattedNumber.startsWith('0')) {
              formattedNumber = formattedNumber.substring(1);
            }

            // Add +20 for Egyptian numbers
            formattedNumber = '+20$formattedNumber';
          }

          // Validate phone number format
          if (formattedNumber.isEmpty || formattedNumber.length < 10) {
            print('ERROR: Invalid phone number format: $formattedNumber');
            continue;
          }

          // Log the phone number for debugging purposes
          print('Sending SMS to formatted number: $formattedNumber');

          bool smsSuccess = false;

          // First attempt with DirectSmsService which attempts to use all available SIMs
          try {
            print('Attempting to send SMS with DirectSmsService...');
            final directSmsService = DirectSmsService();

            // Set up a status listener to show more detailed status in logs
            directSmsService.onSmsStatusChanged = (SmsStatus status) {
              if (status.success) {
                print(
                    'SMS status: Sent successfully to ${status.phoneNumber} using SIM ${status.simId}');
              } else {
                print(
                    'SMS status: Failed to send to ${status.phoneNumber} using SIM ${status.simId}. Reason: ${status.errorReason}');
              }
            };

            // First attempt with DirectSmsService - EMERGENCY OPTIMIZED TIMING
            bool directSmsSent = await directSmsService.sendDirectSms(
              phoneNumber: formattedNumber,
              message: message,
              timeout: const Duration(
                  seconds: 30), // Reduced from 120 to 30 seconds for emergency
            );

            if (directSmsSent) {
              print('SMS sent successfully with DirectSmsService');
              smsSuccess = true;
              anySmsSuccess = true;
            } else {
              print(
                  'Failed to send SMS with DirectSmsService on first attempt');

              // EMERGENCY: Reduced wait time for faster response
              await Future.delayed(
                  const Duration(seconds: 3)); // Reduced from 10 to 3 seconds

              print('Retrying SMS with DirectSmsService...');
              directSmsSent = await directSmsService.sendDirectSms(
                phoneNumber: formattedNumber,
                message: message,
                timeout: const Duration(
                    seconds:
                        20), // Reduced from 120 to 20 seconds for emergency
              );

              if (directSmsSent) {
                print(
                    'SMS sent successfully with DirectSmsService on second attempt');
                smsSuccess = true;
                anySmsSuccess = true;
              } else {
                print(
                    'Failed to send SMS with DirectSmsService on second attempt');
              }
            }

            // Clean up the status listener
            directSmsService.onSmsStatusChanged = null;
          } catch (directSmsError) {
            print('Error sending SMS with DirectSmsService: $directSmsError');

            // Fallback to telephony package if DirectSmsService fails
            try {
              print('Falling back to telephony package...');
              await telephony.sendSms(
                to: formattedNumber,
                message: message,
                isMultipart: true, // Use multipart for longer messages
              );
              print('SMS sent successfully with telephony package');
              smsSuccess = true;
              anySmsSuccess = true;
            } catch (telephonyError) {
              print(
                  'Error sending SMS with telephony package: $telephonyError');
            }

            // If both SIM attempts failed, try using the default SMS app as fallback
            if (!smsSuccess) {
              try {
                print('Trying to send via default SMS app...');
                await telephony.sendSmsByDefaultApp(
                  to: formattedNumber,
                  message: message,
                );
                print('Default SMS app opened');
                // We don't set smsSuccess here because we can't guarantee the user will send the message
              } catch (defaultAppError) {
                print('Error opening default SMS app: $defaultAppError');
              }
            }
          }

          // Add small delay between contacts to avoid network congestion (except for last contact)
          if (i < emergencyContacts.length - 1) {
            print('⏱️ Waiting 2 seconds before next contact...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }

        // Return true if at least one SMS was sent successfully
        return anySmsSuccess;
      } else {
        print('ERROR: SMS permissions not granted');
        // You can show a dialog here asking the user to grant SMS permissions.
        return false;
      }
    } catch (e) {
      print('ERROR sending SMS: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Send SMS using the default SMS app as a fallback
  Future<void> _sendSMSViaDefaultApp(String contact, String message) async {
    try {
      // Initialize telephony
      final Telephony telephony = Telephony.instance;

      // Format phone number (remove any non-digit characters)
      String formattedNumber = contact.replaceAll(RegExp(r'[^\d+]'), '');

      // Add Egypt country code (+20) if needed for Egyptian numbers
      if (!formattedNumber.startsWith('+')) {
        // If number starts with 0, remove it before adding country code
        if (formattedNumber.startsWith('0')) {
          formattedNumber = formattedNumber.substring(1);
        }

        // Add +20 for Egyptian numbers
        formattedNumber = '+20$formattedNumber';
      }

      print('Opening SMS app with number: $formattedNumber');

      // Open default SMS app with pre-filled message
      await telephony.sendSmsByDefaultApp(
        to: formattedNumber,
        message: message,
      );
    } catch (e) {
      print('Error opening SMS app: $e');
    }
  }

  Future<void> setUserData(SOSUserData userData) async {
    _userData = userData;
    await _saveUserData();

    // Sync emergency contacts with AuthService
    await syncEmergencyContactsToAuth();
  }

  /// جلب بيانات المستخدم المحفوظة
  Future<SOSUserData?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString('sosUserData');

      if (userDataJson != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(userDataJson);
        return SOSUserData.fromJson(jsonMap);
      }
      return null;
    } catch (e) {
      print('❌ Error loading SOS user data: $e');
      return null;
    }
  }

  /// التحقق من وجود بيانات محفوظة
  Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('sosUserData');
    } catch (e) {
      return false;
    }
  }

  /// مزامنة emergency contacts من SOSUserData إلى AuthService (اتجاه واحد)
  Future<void> syncEmergencyContactsToAuth() async {
    try {
      if (_userData == null) {
        print('⚠️ No SOS user data to sync');
        return;
      }

      final authService = AuthService();
      final sosContacts = _userData!.emergencyContacts;

      if (sosContacts.isNotEmpty) {
        await authService.saveEmergencyContacts(sosContacts);
        print(
            '✅ Synced ${sosContacts.length} emergency contacts from SOS to Auth');
      }
    } catch (e) {
      print('❌ Error syncing emergency contacts to Auth: $e');
    }
  }

  Future<void> _saveUserData() async {
    if (_userData == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(_userData!.toJson());
      await prefs.setString('sosUserData', jsonString);
    } catch (e) {
      print('Error saving SOS user data: $e');
      rethrow; // Rethrow to let the UI handle the error
    }
  }

  void dispose() {
    _resetTimer?.cancel();
    _locationTimer?.cancel();
  }
}
