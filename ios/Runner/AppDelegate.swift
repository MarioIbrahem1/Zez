import UIKit
import Flutter
import GoogleMaps
import Firebase
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import CoreLocation
import MessageUI

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  // Method channels for iOS-specific functionality
  private var powerButtonChannel: FlutterMethodChannel?
  private var accessibilityChannel: FlutterMethodChannel?
  private var sosChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Configure Firebase
    FirebaseApp.configure()

    // Configure Google Maps
    GMSServices.provideAPIKey("AIzaSyDrP9YA-D4xFrLi-v1klPXvtoEuww6kmBo")

    // Configure push notifications
    configureNotifications(application)

    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Setup method channels
    setupMethodChannels()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Notifications Configuration
  private func configureNotifications(_ application: UIApplication) {
    // Set messaging delegate
    Messaging.messaging().delegate = self

    // Set UNUserNotificationCenter delegate
    UNUserNotificationCenter.current().delegate = self

    // Request notification permissions
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { granted, error in
        print("iOS Notification permission granted: \(granted)")
        if let error = error {
          print("iOS Notification permission error: \(error)")
        }
      }
    )

    application.registerForRemoteNotifications()
  }

  // MARK: - Method Channels Setup
  private func setupMethodChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    // Power Button Detection Channel (iOS equivalent)
    powerButtonChannel = FlutterMethodChannel(
      name: "com.example.road_helperr/power_button",
      binaryMessenger: controller.binaryMessenger
    )

    // Accessibility Service Channel (iOS equivalent)
    accessibilityChannel = FlutterMethodChannel(
      name: "com.example.road_helperr/accessibility",
      binaryMessenger: controller.binaryMessenger
    )
    accessibilityChannel?.setMethodCallHandler(handleAccessibilityCall)

    // SOS Service Channel
    sosChannel = FlutterMethodChannel(
      name: "com.example.road_helperr/sos_ios",
      binaryMessenger: controller.binaryMessenger
    )
    sosChannel?.setMethodCallHandler(handleSOSCall)
  }

  // MARK: - Method Call Handlers
  private func handleAccessibilityCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAccessibilityServiceEnabled":
      // iOS doesn't have accessibility services like Android
      // Return true as iOS handles emergency features differently
      result(true)
    case "openAccessibilitySettings":
      // Open iOS Settings app
      if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsUrl)
        result("iOS Settings opened")
      } else {
        result(FlutterError(code: "SETTINGS_ERROR", message: "Cannot open settings", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleSOSCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sendEmergencySMS":
      // iOS SMS sending implementation
      handleEmergencySMS(call, result: result)
    case "triggerEmergencyAlert":
      // iOS emergency alert implementation
      triggerEmergencyAlert(call, result: result)
    case "checkEmergencyPermissions":
      // Check iOS emergency permissions
      checkEmergencyPermissions(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Emergency SMS Implementation
  private func handleEmergencySMS(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let phoneNumbers = args["phoneNumbers"] as? [String],
          let message = args["message"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    // iOS SMS implementation using MessageUI
    sendSMSMessages(phoneNumbers: phoneNumbers, message: message) { success in
      result(success)
    }
  }

  private func sendSMSMessages(phoneNumbers: [String], message: String, completion: @escaping (Bool) -> Void) {
    // iOS implementation for sending SMS
    // Note: iOS has restrictions on sending SMS programmatically
    // This opens the Messages app with pre-filled content

    var urlComponents = URLComponents(string: "sms:")
    urlComponents?.queryItems = [
      URLQueryItem(name: "body", value: message)
    ]

    if phoneNumbers.count == 1 {
      urlComponents?.path = phoneNumbers[0]
    } else {
      // For multiple recipients, join with comma
      urlComponents?.path = phoneNumbers.joined(separator: ",")
    }

    guard let smsURL = urlComponents?.url else {
      completion(false)
      return
    }

    if UIApplication.shared.canOpenURL(smsURL) {
      UIApplication.shared.open(smsURL) { success in
        completion(success)
      }
    } else {
      completion(false)
    }
  }

  // MARK: - Emergency Alert Implementation
  private func triggerEmergencyAlert(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let title = args["title"] as? String,
          let body = args["body"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    // Create emergency notification
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .defaultCritical
    content.categoryIdentifier = "EMERGENCY_ALERT"

    // Create trigger for immediate delivery
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

    // Create request
    let request = UNNotificationRequest(
      identifier: "emergency_alert_\(Date().timeIntervalSince1970)",
      content: content,
      trigger: trigger
    )

    // Add notification
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("Error showing emergency notification: \(error)")
        result(false)
      } else {
        print("Emergency notification scheduled successfully")
        result(true)
      }
    }
  }

  // MARK: - Permission Checking
  private func checkEmergencyPermissions(_ result: @escaping FlutterResult) {
    var permissions: [String: Bool] = [:]

    // Check notification permissions
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      permissions["notifications"] = settings.authorizationStatus == .authorized

      // Check location permissions
      let locationStatus = CLLocationManager().authorizationStatus
      permissions["location"] = locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse

      // Return results on main thread
      DispatchQueue.main.async {
        result(permissions)
      }
    }
  }

  // MARK: - Remote Notifications
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("iOS: Successfully registered for remote notifications")
    Messaging.messaging().apnsToken = deviceToken
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("iOS: Failed to register for remote notifications: \(error)")
  }

  // MARK: - Background App Refresh
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // Handle background fetch for emergency services
    print("iOS: Background fetch triggered")
    completionHandler(.newData)
  }
}

// MARK: - Firebase Messaging Delegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("iOS: Firebase registration token: \(fcmToken ?? "nil")")

    // Send token to Flutter
    if let token = fcmToken {
      let tokenData: [String: Any] = ["token": token]
      // You can send this to Flutter via method channel if needed
    }
  }
}

// MARK: - User Notifications Delegate
extension AppDelegate: UNUserNotificationCenterDelegate {
  // Handle notification when app is in foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    print("iOS: Notification received in foreground")

    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Handle notification tap
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("iOS: Notification tapped")

    let userInfo = response.notification.request.content.userInfo

    // Handle different notification types
    if let notificationType = userInfo["type"] as? String {
      switch notificationType {
      case "help_request":
        // Handle help request notification
        print("iOS: Help request notification tapped")
      case "chat_message":
        // Handle chat message notification
        print("iOS: Chat message notification tapped")
      case "emergency_alert":
        // Handle emergency alert notification
        print("iOS: Emergency alert notification tapped")
      default:
        print("iOS: Unknown notification type: \(notificationType)")
      }
    }

    completionHandler()
  }
}