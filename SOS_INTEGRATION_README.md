# SOS Emergency Button Integration

## Overview

This document describes the integration of the SOS emergency button feature from the `sos_app` folder into the main Road Helper Flutter project.

## Features Integrated

### 1. Core SOS Functionality

- **Emergency SMS Sending**: Automatically sends SMS messages to emergency contacts
- **Location Tracking**: Includes GPS coordinates in emergency messages
- **Dual SIM Support**: Works with both SIM cards on dual SIM devices
- **Battery Status**: Includes battery level in emergency messages

### 2. Trigger Methods

- **Power Button**: Triple press power button to trigger SOS
- **Volume Buttons**: Triple press volume up/down buttons to trigger SOS
- **Manual Button**: Emergency button on home screen and other screens

### 3. User Interface

- **Emergency Contacts Setup**: Screen to configure emergency contact information
- **SOS Settings**: Configure SOS triggers and preferences
- **Emergency Button Widget**: Reusable emergency button component

## Files Added/Modified

### Dart Files Added:

- `lib/models/sos_user_data.dart` - Data model for SOS user information
- `lib/services/sos_service.dart` - Main SOS service handling emergency alerts
- `lib/services/power_button_detector.dart` - Power button detection service

- `lib/services/direct_sms_service.dart` - Direct SMS sending service
- `lib/services/direct_sms_status_listener.dart` - SMS status tracking
- `lib/services/sim_service.dart` - SIM card management service
- `lib/services/power_button_service.dart` - Background power button service
- `lib/services/background_service.dart` - Background service handler
- `lib/ui/screens/sos_emergency_contacts_screen.dart` - Emergency contacts setup
- `lib/ui/screens/sos_settings_screen.dart` - SOS configuration screen
- `lib/ui/widgets/sos_emergency_button.dart` - Emergency button widget

### Android Files Added:

- `android/app/src/main/kotlin/com/example/road_helperr/PowerButtonReceiver.kt` - Power button receiver
- `android/app/src/main/java/com/example/road_helperr/DirectSmsPlugin.java` - SMS plugin
- `android/app/src/main/java/com/example/road_helperr/SimServicePlugin.java` - SIM service plugin
- `android/app/src/main/java/com/example/road_helperr/SmsSentReceiver.java` - SMS status receiver
- `android/app/src/main/java/com/example/road_helperr/SOSAccessibilityService.java` - Accessibility service
- `android/app/src/main/res/xml/accessibility_service_config.xml` - Accessibility config
- `android/app/src/main/res/values/strings.xml` - String resources

### Modified Files:

- `pubspec.yaml` - Added SOS dependencies
- `lib/main.dart` - Added SOS initialization and routes
- `lib/ui/screens/bottomnavigationbar_screes/home_screen.dart` - Added SOS button
- `lib/ui/screens/bottomnavigationbar_screes/profile_screen.dart` - Added SOS options
- `android/app/src/main/AndroidManifest.xml` - Added SOS permissions and services
- `android/app/src/main/kotlin/com/example/road_helperr/MainActivity.kt` - Added SOS plugins

## Dependencies Added

### Flutter Dependencies:

```yaml
battery_plus: ^4.1.0
device_info_plus: ^9.1.2
flutter_background_service: ^5.0.5
flutter_background_service_android: ^6.2.2
flutter_background_service_ios: ^5.0.0
local_auth: ^2.1.8
telephony: (custom package from sos_packages/telephony)
```

### Android Permissions Added:

- `READ_PHONE_STATE` - Read phone state for SIM management
- `READ_CONTACTS` / `WRITE_CONTACTS` - Contact management
- `BIND_ACCESSIBILITY_SERVICE` - Accessibility service for button detection
- `FOREGROUND_SERVICE_REMOTE_MESSAGING` - Background service
- `RECEIVE_SMS` / `READ_SMS` / `BROADCAST_SMS` - SMS handling

## Setup Instructions

### 1. Emergency Contacts Setup

1. Open the app and go to Profile screen
2. Tap "Emergency Contacts"
3. Fill in your personal information (name, age)
4. Add at least one emergency contact (Egyptian mobile numbers: 010, 011, 012, 015)
5. Save the information

### 2. SOS Settings Configuration

1. Go to Profile screen
2. Tap "SOS Settings"
3. Enable/disable SOS service
4. Configure power button trigger
5. Test the SOS functionality

### 3. Accessibility Service (Optional)

For enhanced power button detection:

1. Go to Android Settings > Accessibility
2. Find "SOS Emergency Service"
3. Enable the service

## Usage

### Triggering SOS:

1. **Power Button**: Quickly press power button 3 times within 2 seconds
2. **Manual**: Tap the emergency button on home screen

### Emergency Message Format:

```
SOS! [Name] needs help!
Age: [Age]
Current coordinates: [Latitude], [Longitude]
Battery: [Battery Level]%
IMPORTANT: Copy the coordinates and put them in Google Maps to show the actual location.
```

## Technical Details

### SMS Sending Strategy:

1. Attempts to send via DirectSmsService with all available SIMs
2. Falls back to default SMS manager if direct sending fails
3. Includes retry mechanism for failed messages
4. Supports both single and dual SIM devices

### Background Services:

- Power button detection runs as a background service
- Location tracking updates every minute
- Notification channel for SOS alerts (stealth mode - no sound/vibration)

### Security Features:

- Emergency contacts stored locally with encryption
- No external servers involved in emergency messaging
- Works offline (only requires cellular network for SMS)

## Testing

### Test SOS Functionality:

1. Set up emergency contacts with your own phone number
2. Use the "Test SOS Alert" button in SOS Settings
3. Verify SMS is received with correct information
4. Test power button trigger

### Troubleshooting:

- Ensure SMS permissions are granted
- Check that emergency contacts are properly formatted
- Verify location permissions are enabled
- Test with different SIM cards if available

## Future Enhancements

Potential improvements that could be added:

- Voice call functionality for emergencies
- Integration with emergency services
- Automatic photo capture during emergency
- Emergency contact verification system
- Multi-language emergency messages
- Integration with medical information

## Notes

- The SOS feature is designed to work independently of the main app functionality
- Emergency messages are sent via SMS to ensure maximum compatibility
- The feature respects user privacy - no data is sent to external servers
- Works with Egyptian mobile networks (010, 011, 012, 015 prefixes)
