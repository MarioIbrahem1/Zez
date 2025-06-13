# iOS Setup and Build Guide for Road Helper App

This guide provides step-by-step instructions for building and deploying the Road Helper Flutter app on iOS devices.

## Prerequisites

### 1. Development Environment
- **macOS** (required for iOS development)
- **Xcode 14.0+** (latest stable version recommended)
- **Flutter SDK** (latest stable version)
- **CocoaPods** (for dependency management)

### 2. Apple Developer Account
- Apple Developer Program membership (for device testing and App Store deployment)
- Valid iOS Development Certificate
- Provisioning Profiles for the app

## Initial Setup

### 1. Install Required Tools

```bash
# Install Xcode from App Store (if not already installed)
# Install Xcode Command Line Tools
xcode-select --install

# Install CocoaPods
sudo gem install cocoapods

# Verify Flutter installation
flutter doctor
```

### 2. Clone and Setup Project

```bash
# Navigate to project directory
cd /path/to/RH

# Get Flutter dependencies
flutter pub get

# Install iOS dependencies
cd ios
pod install
cd ..
```

## iOS Configuration

### 1. Bundle Identifier Setup
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project in the navigator
3. Go to the "Signing & Capabilities" tab
4. Set Bundle Identifier to: `com.example.roadHelperr`
5. Select your development team

### 2. Signing Configuration
1. In Xcode, under "Signing & Capabilities":
   - Enable "Automatically manage signing"
   - Select your Apple Developer Team
   - Ensure provisioning profile is selected

### 3. Capabilities Configuration
The following capabilities are already configured in the project:
- ✅ Push Notifications
- ✅ Background Modes (Location, Background Fetch, Remote Notifications)
- ✅ Associated Domains (if needed)

## Firebase Configuration

### 1. Firebase Project Setup
The Firebase configuration is already included:
- `GoogleService-Info.plist` is in `ios/Runner/`
- Firebase options are configured in `lib/firebase_options.dart`

### 2. Verify Firebase Setup
1. Open `ios/Runner.xcworkspace` in Xcode
2. Ensure `GoogleService-Info.plist` is in the Runner target
3. Check that Firebase pods are installed via CocoaPods

## Building the App

### 1. Debug Build (for testing)

```bash
# Build for iOS simulator
flutter build ios --debug --simulator

# Build for physical device
flutter build ios --debug
```

### 2. Release Build (for distribution)

```bash
# Build release version
flutter build ios --release

# Build IPA for distribution
flutter build ipa --release
```

### 3. Running on Device

```bash
# Run on connected iOS device
flutter run -d ios

# Run on specific device
flutter devices  # List available devices
flutter run -d [device-id]
```

## iOS-Specific Features

### 1. Emergency Detection
The iOS version includes alternative emergency detection methods:
- **Volume Button Detection**: Rapid volume up/down presses (6 times)
- **App State Detection**: Quick background/foreground transitions
- **Shake Gesture**: Device shake detection
- **Manual Trigger**: Emergency button in app

### 2. SMS Functionality
iOS SMS implementation:
- Uses `MessageUI` framework
- Opens native Messages app with pre-filled content
- Supports multiple recipients

### 3. Push Notifications
- Firebase Cloud Messaging (FCM) configured
- Critical alerts supported
- Background notification handling

## Permissions

The following permissions are configured in `Info.plist`:
- Location (Always and When In Use)
- Camera and Photo Library
- Microphone
- Contacts
- Notifications
- Face ID/Touch ID
- Motion and Fitness
- Bluetooth (for emergency beacons)
- Speech Recognition
- Siri Integration

## Testing

### 1. Device Testing
1. Connect iOS device via USB
2. Trust the computer on the device
3. Run: `flutter run -d ios`

### 2. Emergency Features Testing
1. Test volume button emergency trigger
2. Test app state emergency trigger
3. Test manual emergency button
4. Verify SMS functionality
5. Test push notifications

### 3. Firebase Testing
1. Verify Firebase connection
2. Test real-time database
3. Test FCM notifications
4. Test Google authentication

## Deployment

### 1. App Store Connect
1. Create app record in App Store Connect
2. Upload build using Xcode or Application Loader
3. Configure app metadata
4. Submit for review

### 2. TestFlight (Beta Testing)
1. Upload build to App Store Connect
2. Add beta testers
3. Distribute via TestFlight

### 3. Enterprise Distribution (if applicable)
1. Use enterprise provisioning profile
2. Build with enterprise certificate
3. Distribute via MDM or direct download

## Troubleshooting

### Common Issues

1. **Pod Install Fails**
   ```bash
   cd ios
   pod deintegrate
   pod install
   ```

2. **Signing Issues**
   - Verify Apple Developer account
   - Check provisioning profiles
   - Ensure bundle ID matches

3. **Firebase Issues**
   - Verify `GoogleService-Info.plist` is in project
   - Check Firebase project configuration
   - Ensure iOS app is added to Firebase project

4. **Build Errors**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter build ios
   ```

### Performance Optimization

1. **Release Build Optimizations**
   - Enable bitcode (already configured)
   - Use release mode for final builds
   - Test on actual devices

2. **App Size Optimization**
   - Remove unused assets
   - Optimize images
   - Use tree shaking

## Security Considerations

1. **API Keys**: Ensure all API keys are properly secured
2. **Certificates**: Keep development certificates secure
3. **Provisioning**: Use appropriate provisioning profiles
4. **Code Signing**: Verify code signing is working correctly

## Support and Resources

- [Flutter iOS Documentation](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Xcode Documentation](https://developer.apple.com/xcode/)

## Contact

For technical issues or questions about the iOS build process, please refer to this guide or contact the development team.

---

**Note**: This guide assumes you have the necessary Apple Developer credentials and access. Some steps may require additional configuration based on your specific setup and requirements.
