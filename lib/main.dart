import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:road_helperr/providers/settings_provider.dart';
import 'package:road_helperr/providers/signup_provider.dart';
import 'package:road_helperr/services/auth_service.dart';

import 'package:road_helperr/ui/screens/about_screen.dart';
import 'package:road_helperr/ui/screens/faq_screen.dart';
import 'package:road_helperr/ui/screens/privacy_policy_screen.dart';
import 'package:road_helperr/ui/screens/ai_chat.dart';
import 'package:road_helperr/ui/screens/ai_welcome_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/home_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/map_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/notification_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/profile_screen.dart'
    as profile;
import 'package:road_helperr/ui/screens/edit_profile_screen.dart';
import 'package:road_helperr/ui/screens/email_screen.dart';
import 'package:road_helperr/ui/screens/on_boarding.dart';
import 'package:road_helperr/ui/screens/onboarding.dart';
import 'package:road_helperr/ui/screens/otp_expired_screen.dart';
import 'package:road_helperr/ui/screens/otp_screen.dart';
import 'package:road_helperr/ui/screens/signin_screen.dart';
import 'package:road_helperr/ui/screens/signupScreen.dart';

import 'package:road_helperr/ui/screens/license_capture_screen.dart';
import 'package:road_helperr/ui/screens/google_license_capture_screen.dart';
import 'package:road_helperr/models/profile_data.dart';
import 'package:road_helperr/utils/theme_provider.dart';
import 'package:road_helperr/ui/screens/car_google.dart';
import 'utils/location_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:road_helperr/utils/update_helper.dart';
import 'package:road_helperr/services/fcm_v1_service.dart';
import 'package:road_helperr/services/fcm_token_manager.dart';
import 'package:road_helperr/services/help_request_delivery_monitor.dart';
import 'package:road_helperr/ui/screens/accepted_help_request_details_screen.dart';
import 'package:road_helperr/test/persistent_login_test.dart';
import 'package:road_helperr/test/sos_test_screen.dart';
import 'package:road_helperr/services/accessibility_checker.dart';
import 'package:road_helperr/ui/screens/sos_emergency_contacts_screen.dart';
import 'package:road_helperr/ui/screens/sos_settings_screen.dart';
import 'package:road_helperr/test/auth_type_test.dart';
import 'package:road_helperr/ui/screens/chat_screen.dart';
import 'package:road_helperr/models/user_location.dart';
import 'package:road_helperr/test/chat_system_test.dart';
import 'package:road_helperr/ui/screens/sos_permission_setup_screen.dart';
import 'package:road_helperr/test/sos_permission_test_screen.dart';

import 'package:road_helperr/services/release_mode_helper.dart';
import 'package:road_helperr/utils/release_mode_diagnostics.dart';
import 'package:road_helperr/config/release_mode_config.dart';
import 'package:road_helperr/services/release_mode_user_sync_service.dart';
import 'package:flutter/foundation.dart';

// SOS Emergency Feature Imports
import 'package:road_helperr/services/sos_service.dart';
import 'package:road_helperr/services/power_button_detector.dart';

// Global navigator key for accessing the navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase (مع التحقق من عدم التهيئة المسبقة)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('⚠️ Firebase already initialized, skipping...');
    } else {
      debugPrint('❌ Error initializing Firebase: $e');
      rethrow;
    }
  }

  // Help request system is now only available for Google authenticated users
  // Traditional SQL users will see appropriate messaging when trying to use help requests
  debugPrint('✅ Help request system configured for Google users only');

  // تحسين Firebase للعمل في Release Mode
  await ReleaseModeHelper.optimizeFirebaseForReleaseMode();

  // طباعة معلومات التشخيص
  ReleaseModeHelper.printReleaseModeDiagnostics();

  // طباعة إعدادات Release Mode
  ReleaseModeConfig.printConfiguration();

  // تشغيل تشخيص شامل في Release Mode
  if (kReleaseMode) {
    try {
      final diagnostics = await ReleaseModeDignostics.runFullDiagnostics();
      ReleaseModeDignostics.printDetailedReport(diagnostics);

      // فحص المشاكل الحرجة
      final criticalIssues = await ReleaseModeDignostics.getCriticalIssues();
      if (criticalIssues.isNotEmpty) {
        debugPrint('🚨 CRITICAL ISSUES FOUND:');
        for (final issue in criticalIssues) {
          debugPrint('🚨 - $issue');
        }
      } else {
        debugPrint('✅ No critical issues found in Release Mode');
      }

      // إصلاح مشاكل المستخدمين المختلطين في Release Mode
      final userSyncService = ReleaseModeUserSyncService();
      final userFixResults = await userSyncService.fixReleaseModeUserIssues();
      debugPrint('🔧 User sync results: $userFixResults');

      // اختبار شامل اختياري (يمكن تعطيله في الإنتاج)
      // final testResults = await ReleaseModeTestHelper.runComprehensiveTest();
      // ReleaseModeTestHelper.printSimpleReport(testResults);
    } catch (e) {
      debugPrint('❌ Release Mode diagnostics failed: $e');
    }
  }

  // تهيئة خدمة الإشعارات الموحدة (FCM v1 API only)
  try {
    await FCMv1Service().initialize();
    debugPrint('✅ Main: FCM v1 Service initialized successfully');
  } catch (e) {
    debugPrint('❌ Main: Failed to initialize FCM v1 Service: $e');
    // Continue app startup even if FCM fails
  }

  // حفظ FCM token للمستخدم الحالي إذا كان مسجل دخول
  try {
    final fcmTokenManager = FCMTokenManager();
    final tokenSaved = await fcmTokenManager.saveTokenOnLogin();
    if (tokenSaved) {
      debugPrint('✅ Main: FCM token saved successfully on app startup');
    } else {
      debugPrint(
          '⚠️ Main: FCM token save returned false - user might not be logged in');
    }
  } catch (e) {
    debugPrint('❌ Main: Could not save FCM token on startup: $e');
    // Continue app startup even if token save fails
  }

  // التحقق من حالة تسجيل الدخول قبل بدء التطبيق (مع إمكانية استعادة الجلسة)
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  final canUseSos = await authService.canUseSosServices();

  // بدء مراقبة تسليم طلبات المساعدة إذا كان المستخدم مسجل دخول
  if (isLoggedIn) {
    HelpRequestDeliveryMonitor().startMonitoring();
    debugPrint('✅ Help request delivery monitoring started');
  }

  debugPrint('=== حالة تسجيل الدخول عند بدء التطبيق ===');
  debugPrint('المستخدم مسجل الدخول: $isLoggedIn');
  debugPrint('خدمات SOS متاحة: $canUseSos');
  debugPrint(
      'Persistent Login: ${await authService.isPersistentLoginEnabled()}');
  debugPrint('=========================================');

  // تشغيل اختبار سريع للنظام الجديد في Debug Mode
  if (kDebugMode) {
    try {
      await PersistentLoginTest.runQuickTest();
      debugPrint('ℹ️ SOS Test Screen available at: /sos-test');
    } catch (e) {
      debugPrint('❌ Persistent Login Test failed: $e');
    }
  }

  // تهيئة خدمات SOS الطارئة
  await _initializeSOSServices();

  // بدء التطبيق
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SignupProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MyApp(isUserLoggedIn: isLoggedIn),
    ),
  );

  // إذا كان المستخدم مسجل دخول، تأكد من بدء تتبع الموقع (بعد بدء التطبيق)
  if (isLoggedIn) {
    _startLocationTrackingInBackground();
  }

  // تأكد من أن خدمات SOS تعمل حتى لو لم يكن المستخدم مسجل دخول
  // (طالما أن لديه emergency contacts محفوظة)
  if (canUseSos) {
    debugPrint('✅ SOS services are available and ready');
  } else {
    debugPrint('⚠️ SOS services not available - emergency contacts needed');
  }

  // مزامنة emergency contacts بين SOSService و AuthService
  try {
    final sosService = SOSService();
    await sosService.syncEmergencyContactsToAuth();
    debugPrint('✅ Emergency contacts synced between services');
  } catch (e) {
    debugPrint('⚠️ Failed to sync emergency contacts: $e');
  }

  // التحقق من حالة Accessibility Service للـ SOS
  try {
    final accessibilityChecker = AccessibilityChecker();

    // التحقق من الحالة الحالية قبل إعادة التعيين
    debugPrint('🔍 Main: Checking current accessibility session state...');
    await accessibilityChecker.debugAccessibilityKeys();
    final currentSessionState =
        await accessibilityChecker.isSessionNotificationShown();
    debugPrint(
        '🔍 Main: Current session notification shown: $currentSessionState');

    // إعادة تعيين حالة الجلسة عند بدء التطبيق (جلسة جديدة)
    await accessibilityChecker.resetSessionState();
    debugPrint('🔄 Main: Reset accessibility session state on app start');

    // التحقق من الحالة بعد إعادة التعيين
    final afterResetState =
        await accessibilityChecker.isSessionNotificationShown();
    debugPrint('🔍 Main: Session state after reset: $afterResetState');

    // إعادة تعيين حالة التذكير إذا كانت الخدمة غير مفعلة (للتأكد من ظهور التنبيه)
    final isAccessibilityEnabled = await accessibilityChecker.checkOnAppStart();
    debugPrint(
        '🔍 Main: Accessibility Service enabled: $isAccessibilityEnabled');

    if (!isAccessibilityEnabled) {
      // إعادة تعيين حالة التذكير لضمان ظهور التنبيه
      await accessibilityChecker.resetReminderState();
      debugPrint('🔄 Main: Reset reminder state for accessibility service');

      final shouldShowReminder =
          await accessibilityChecker.shouldShowReminder();
      debugPrint(
          '📢 Main: Should show accessibility reminder: $shouldShowReminder');
    }

    // بدء التحقق الدوري
    await accessibilityChecker.startPeriodicCheck();
  } catch (e) {
    debugPrint('⚠️ Failed to check accessibility service: $e');
  }
}

/// بدء تتبع الموقع في الخلفية بدون تأثير على UI
void _startLocationTrackingInBackground() {
  Future.delayed(const Duration(seconds: 2), () async {
    try {
      debugPrint('🔄 Starting background location tracking...');

      // Note: Location tracking is now only available for Google authenticated users
      // Traditional users will see a message about this limitation
      debugPrint(
          'ℹ️ Location tracking is only available for Google authenticated users');

      debugPrint('✅ Background location tracking check completed');
    } catch (e) {
      debugPrint('❌ Error starting background location tracking: $e');
    }
  });
}

/// تهيئة خدمات SOS الطارئة
Future<void> _initializeSOSServices() async {
  try {
    debugPrint('🚨 Initializing SOS Emergency Services...');

    // تهيئة خدمة SOS الرئيسية
    await SOSService().initialize();
    debugPrint('✅ SOS Service initialized');

    // تهيئة خدمة كشف زر الطاقة
    try {
      final powerButtonDetector = PowerButtonDetector();
      await powerButtonDetector.initialize();
      powerButtonDetector.setTriplePressCallback(() async {
        debugPrint('🚨 MAIN: ===== EMERGENCY TRIGGERED BY POWER BUTTON! =====');
        debugPrint('🚨 MAIN: Callback function called successfully');
        debugPrint('🚨 MAIN: Starting SOS alert process...');

        try {
          debugPrint('🚨 MAIN: Calling SOSService().triggerSosAlert()...');
          bool notificationSent = await SOSService().triggerSosAlert();
          debugPrint(
              '🚨 MAIN: SOSService().triggerSosAlert() returned: $notificationSent');

          if (notificationSent) {
            debugPrint(
                '✅ MAIN: SOS notification sent successfully from power button');
          } else {
            debugPrint(
                '❌ MAIN: Failed to send SOS notification from power button');
            if (navigatorKey.currentContext != null) {
              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                const SnackBar(
                  content:
                      Text('Failed to send emergency alert. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('❌ MAIN: Error during SOS alert: $e');
        }

        debugPrint('🚨 MAIN: ===== SOS PROCESS COMPLETED =====');
      });
      debugPrint('✅ Power Button Detector initialized');
    } catch (e) {
      debugPrint('❌ Error initializing power button detector: $e');
    }

    // ملاحظة: خدمة الخلفية معطلة مؤقتاً لتجنب مشاكل foreground service
    // يمكن تفعيلها لاحقاً بعد إصلاح إعدادات notification channels
    debugPrint(
        'ℹ️ Background service disabled to avoid foreground service notification issues');

    debugPrint('✅ SOS Emergency Services initialization completed');
  } catch (e) {
    debugPrint('❌ Error initializing SOS services: $e');
  }
}

class MyApp extends StatefulWidget {
  final bool isUserLoggedIn;

  const MyApp({super.key, required this.isUserLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final LocationService _locationService = LocationService();
  final UpdateHelper _updateHelper = UpdateHelper();

  // المسار الأولي للتطبيق
  late String _initialRoute;

  @override
  void initState() {
    super.initState();
    // تعيين المسار الأولي بناءً على حالة تسجيل الدخول
    _initialRoute = widget.isUserLoggedIn
        ? HomeScreen.routeName
        : OnboardingScreen.routeName;

    debugPrint('=== المسار الأولي للتطبيق ===');
    debugPrint('المستخدم مسجل الدخول: ${widget.isUserLoggedIn}');
    debugPrint('المسار الأولي: $_initialRoute');
    debugPrint('============================');

    _checkLocation();
    _initializeUpdateHelper();
    _initializeFirebaseNotifications();

    // Delay update check to ensure the app is fully loaded
    Future.delayed(const Duration(seconds: 2), () {
      _checkForUpdates();
    });
  }

  Future<void> _initializeFirebaseNotifications() async {
    // FCM v1 service is already initialized in main()
    // No additional initialization needed here
    debugPrint('✅ FCM v1 Service already initialized');
  }

  Future<void> _initializeUpdateHelper() async {
    await _updateHelper.initialize();
  }

  Future<void> _checkLocation() async {
    await _locationService.checkLocationPermission();
    bool isLocationEnabled = await _locationService.isLocationServiceEnabled();
    if (!isLocationEnabled) {
      _showLocationDisabledMessage();
    }
  }

  Future<void> _checkForUpdates() async {
    // تأخير التحقق من التحديثات للتأكد من أن MaterialApp جاهز
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        try {
          await _updateHelper.checkForUpdatesOnStartup(context);

          // إعداد التحقق الدوري من التحديثات
          if (mounted) {
            await _updateHelper.setupPeriodicUpdateCheck(context);
          }
        } catch (e) {
          debugPrint('❌ Error in update check: $e');
        }
      }
    });
  }

  void _showLocationDisabledMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text('Please enable location services to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey, // إضافة مفتاح التنقل للإشعارات
      debugShowCheckedModeBanner: false,
      title: 'Road Helper App',
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      themeMode: themeProvider.themeMode,

      // Localization setup
      locale: Locale(settingsProvider.currentLocale),
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      routes: {
        AboutScreen.routeName: (context) => const AboutScreen(),
        FaqScreen.routeName: (context) => const FaqScreen(),
        PrivacyPolicyScreen.routeName: (context) => const PrivacyPolicyScreen(),
        SignupScreen.routeName: (context) => const SignupScreen(),
        SignInScreen.routeName: (context) => const SignInScreen(),
        AiWelcomeScreen.routeName: (context) => const AiWelcomeScreen(),
        AiChat.routeName: (context) => const AiChat(),
        HomeScreen.routeName: (context) => const HomeScreen(),
        MapScreen.routeName: (context) => const MapScreen(),
        NotificationScreen.routeName: (context) => const NotificationScreen(),
        profile.ProfileScreen.routeName: (context) =>
            const profile.ProfileScreen(),
        OtpScreen.routeName: (context) => const OtpScreen(),
        OnBoarding.routeName: (context) => const OnBoarding(),
        OnboardingScreen.routeName: (context) => const OnboardingScreen(),
        OtpExpiredScreen.routeName: (context) => const OtpExpiredScreen(),
        CarGoogleScreen.routeName: (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return CarGoogleScreen(
            userData: args ?? {},
          );
        },
        EditProfileScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          if (args == null) {
            // إذا لم تكن هناك arguments، ارجع إلى الصفحة السابقة
            Navigator.of(context).pop();
            return Container(); // مؤقت
          }
          return EditProfileScreen(
            email: args['email'] as String,
            initialData: args['initialData'] as ProfileData?,
          );
        },
        EmailScreen.routeName: (context) => const EmailScreen(),
        LicenseCaptureScreen.routeName: (context) =>
            const LicenseCaptureScreen(),
        GoogleLicenseCaptureScreen.routeName: (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return GoogleLicenseCaptureScreen(
            userData: args ?? {},
          );
        },
        AcceptedHelpRequestDetailsScreen.routeName: (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return AcceptedHelpRequestDetailsScreen(requestData: args);
        },
        SOSEmergencyContactsScreen.routeName: (context) =>
            const SOSEmergencyContactsScreen(),
        SOSSettingsScreen.routeName: (context) => const SOSSettingsScreen(),
        SOSTestScreen.routeName: (context) => const SOSTestScreen(),
        '/auth-test': (context) => const AuthTypeTestScreen(),
        '/chat-test': (context) => const ChatSystemTestScreen(),
        '/sos-permission-test': (context) => const SOSPermissionTestScreen(),
        SOSPermissionSetupScreen.routeName: (context) =>
            const SOSPermissionSetupScreen(),
        ChatScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          if (args == null) {
            // If no arguments, navigate back
            Navigator.of(context).pop();
            return Container();
          }
          return ChatScreen(
            otherUser: UserLocation.fromMap(args['otherUser'] ?? {}),
          );
        },
      },
      initialRoute: _initialRoute,
    );
  }
}
