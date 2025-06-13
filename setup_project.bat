@echo off
echo ========================================
echo    Road Helper Project Setup Script
echo ========================================
echo.

echo [1/5] Installing Flutter dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to install Flutter dependencies
    pause
    exit /b 1
)
echo ✓ Flutter dependencies installed successfully
echo.

echo [2/5] Setting up Firebase configuration...
if not exist "lib\firebase_options.dart" (
    if exist "lib\firebase_options.example.dart" (
        copy "lib\firebase_options.example.dart" "lib\firebase_options.dart"
        echo ✓ Created firebase_options.dart from example
        echo WARNING: Please update firebase_options.dart with your Firebase configuration
    ) else (
        echo ERROR: firebase_options.example.dart not found
    )
) else (
    echo ✓ firebase_options.dart already exists
)
echo.

echo [3/5] Setting up Service Account Key...
if not exist "assets\service-account-key.json" (
    if exist "assets\service-account-key.example.json" (
        copy "assets\service-account-key.example.json" "assets\service-account-key.json"
        echo ✓ Created service-account-key.json from example
        echo WARNING: Please update service-account-key.json with your actual Firebase service account key
    ) else (
        echo ERROR: service-account-key.example.json not found
    )
) else (
    echo ✓ service-account-key.json already exists
)
echo.

echo [4/5] Setting up Android local.properties...
if not exist "android\local.properties" (
    echo sdk.dir=%ANDROID_HOME% > "android\local.properties"
    echo flutter.sdk=%FLUTTER_ROOT% >> "android\local.properties"
    echo flutter.buildMode=debug >> "android\local.properties"
    echo flutter.versionName=1.0.6 >> "android\local.properties"
    echo flutter.versionCode=6 >> "android\local.properties"
    echo ✓ Created android/local.properties
    echo WARNING: Please verify the SDK paths in android/local.properties
) else (
    echo ✓ android/local.properties already exists
)
echo.

echo [5/5] Cleaning and rebuilding...
call flutter clean
call flutter pub get
echo ✓ Project cleaned and dependencies reinstalled
echo.

echo ========================================
echo           Setup Complete!
echo ========================================
echo.
echo IMPORTANT: Before running the app, make sure to:
echo 1. Update lib/firebase_options.dart with your Firebase configuration
echo 2. Update assets/service-account-key.json with your service account key
echo 3. Add google-services.json to android/app/ directory
echo 4. Add GoogleService-Info.plist to ios/Runner/ directory (for iOS)
echo.
echo To run the app: flutter run
echo.
pause
