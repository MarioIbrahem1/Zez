#!/bin/bash

echo "========================================"
echo "   Road Helper Project Setup Script"
echo "========================================"
echo

echo "[1/5] Installing Flutter dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Flutter dependencies"
    exit 1
fi
echo "✓ Flutter dependencies installed successfully"
echo

echo "[2/5] Setting up Firebase configuration..."
if [ ! -f "lib/firebase_options.dart" ]; then
    if [ -f "lib/firebase_options.example.dart" ]; then
        cp "lib/firebase_options.example.dart" "lib/firebase_options.dart"
        echo "✓ Created firebase_options.dart from example"
        echo "WARNING: Please update firebase_options.dart with your Firebase configuration"
    else
        echo "ERROR: firebase_options.example.dart not found"
    fi
else
    echo "✓ firebase_options.dart already exists"
fi
echo

echo "[3/5] Setting up Service Account Key..."
if [ ! -f "assets/service-account-key.json" ]; then
    if [ -f "assets/service-account-key.example.json" ]; then
        cp "assets/service-account-key.example.json" "assets/service-account-key.json"
        echo "✓ Created service-account-key.json from example"
        echo "WARNING: Please update service-account-key.json with your actual Firebase service account key"
    else
        echo "ERROR: service-account-key.example.json not found"
    fi
else
    echo "✓ service-account-key.json already exists"
fi
echo

echo "[4/5] Setting up Android local.properties..."
if [ ! -f "android/local.properties" ]; then
    cat > "android/local.properties" << EOF
sdk.dir=$ANDROID_HOME
flutter.sdk=$FLUTTER_ROOT
flutter.buildMode=debug
flutter.versionName=1.0.6
flutter.versionCode=6
EOF
    echo "✓ Created android/local.properties"
    echo "WARNING: Please verify the SDK paths in android/local.properties"
else
    echo "✓ android/local.properties already exists"
fi
echo

echo "[5/5] Cleaning and rebuilding..."
flutter clean
flutter pub get
echo "✓ Project cleaned and dependencies reinstalled"
echo

echo "========================================"
echo "          Setup Complete!"
echo "========================================"
echo
echo "IMPORTANT: Before running the app, make sure to:"
echo "1. Update lib/firebase_options.dart with your Firebase configuration"
echo "2. Update assets/service-account-key.json with your service account key"
echo "3. Add google-services.json to android/app/ directory"
echo "4. Add GoogleService-Info.plist to ios/Runner/ directory (for iOS)"
echo
echo "To run the app: flutter run"
echo
