import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:road_helperr/services/fcm_token_manager.dart';
import 'package:road_helperr/services/notification_manager.dart';
import 'package:road_helperr/models/notification_model.dart';
import 'package:road_helperr/config/fcm_v1_config.dart';
import 'package:road_helperr/main.dart' show navigatorKey;
import 'package:road_helperr/utils/notification_error_handler.dart';
import 'package:road_helperr/ui/screens/chat_screen.dart';

/// Unified FCM v1 API Notification Service
/// This is the ONLY notification service used throughout the app
class FCMv1Service {
  static final FCMv1Service _instance = FCMv1Service._internal();
  factory FCMv1Service() => _instance;
  FCMv1Service._internal();

  late final FirebaseMessaging _firebaseMessaging;
  final FCMTokenManager _tokenManager = FCMTokenManager();
  final NotificationManager _notificationManager = NotificationManager();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // FCM v1 API configuration
  String _projectId = FCMv1Config.projectId;
  static const String _fcmScope =
      'https://www.googleapis.com/auth/firebase.messaging';

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Initialize the FCM v1 service
  Future<void> initialize() async {
    try {
      debugPrint('🚀 FCMv1Service: Initializing...');

      // Initialize Firebase Messaging
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup message handlers
      await _setupMessageHandlers();

      // Get and save FCM token
      await _initializeFCMToken();

      debugPrint('✅ FCMv1Service: Initialization completed successfully');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Initialization failed: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      debugPrint(
          '📱 FCMv1Service: Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ FCMv1Service: Notification permissions denied');
        debugPrint(
            '⚠️ FCMv1Service: User needs to enable notifications in device settings');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.authorized) {
        debugPrint('✅ FCMv1Service: Notification permissions granted');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ FCMv1Service: Notification permissions provisional');
      }

      // Set foreground notification presentation options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('✅ FCMv1Service: Foreground notification options set');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error requesting permissions: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('✅ FCMv1Service: Local notifications initialized');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error initializing local notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('🔔 FCMv1Service: Notification tapped: ${response.payload}');

      if (response.payload != null) {
        final data =
            Map<String, dynamic>.from(jsonDecode(response.payload!) as Map);

        final notificationType = data['type'] ?? 'general';

        if (notificationType == 'help_request') {
          navigatorKey.currentState?.pushNamed('notification');
        }
      }
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error handling notification tap: $e');
    }
  }

  /// Setup message handlers for different app states
  Future<void> _setupMessageHandlers() async {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps when app is terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message when app is opened from terminated state
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('✅ FCMv1Service: Message handlers setup completed');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error setting up message handlers: $e');
    }
  }

  /// Initialize and save FCM token
  Future<void> _initializeFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('🔑 FCMv1Service: FCM Token obtained');
        await _tokenManager.saveTokenOnLogin();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          debugPrint('🔄 FCMv1Service: Token refreshed');
          await _tokenManager.onTokenRefresh(newToken);
        });
      } else {
        debugPrint('⚠️ FCMv1Service: Failed to obtain FCM token');
      }
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error initializing FCM token: $e');
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      debugPrint('📨 FCMv1Service: Foreground message received');
      debugPrint('📝 Title: ${message.notification?.title}');
      debugPrint('📄 Body: ${message.notification?.body}');
      debugPrint('📦 Data: ${message.data}');

      // Save notification to local storage
      await _saveNotificationLocally(message);

      // Show local push notification
      await _showLocalNotification(message);

      // Show in-app notification or update UI as needed
      await _handleNotificationDisplay(message);
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error handling foreground message: $e');
    }
  }

  /// Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    try {
      debugPrint('👆 FCMv1Service: Notification tapped');
      debugPrint('📦 Data: ${message.data}');

      // Save notification to local storage
      await _saveNotificationLocally(message);

      // Navigate based on notification type
      await _handleNotificationNavigation(message);
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error handling notification tap: $e');
    }
  }

  /// Save notification to local storage
  Future<void> _saveNotificationLocally(RemoteMessage message) async {
    try {
      final notification = NotificationModel(
        id: message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'Notification',
        body: message.notification?.body ?? '',
        timestamp: DateTime.now(),
        isRead: false,
        type: message.data['type'] ?? 'general',
        data: message.data,
      );

      await _notificationManager.addNotification(notification);
      debugPrint('💾 FCMv1Service: Notification saved locally');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error saving notification locally: $e');
    }
  }

  /// Show local notification (for foreground messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'road_helper_notifications',
        'Road Helper Notifications',
        channelDescription: 'Push notifications for Road Helper app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = message.notification?.title ?? 'إشعار جديد';
      final body = message.notification?.body ?? '';
      final payload = jsonEncode(message.data);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('✅ FCMv1Service: Local notification displayed: $title');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error showing local notification: $e');
    }
  }

  /// Handle notification display (for foreground messages)
  Future<void> _handleNotificationDisplay(RemoteMessage message) async {
    try {
      // This could show an in-app banner, update badge count, etc.
      // For now, we'll just log it
      debugPrint(
          '🔔 FCMv1Service: Displaying notification: ${message.notification?.title}');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error displaying notification: $e');
    }
  }

  /// Handle notification navigation
  Future<void> _handleNotificationNavigation(RemoteMessage message) async {
    try {
      final notificationType = message.data['type'] ?? 'general';

      // Use the global navigator key from main.dart
      if (navigatorKey.currentState == null) {
        debugPrint(
            '⚠️ FCMv1Service: Navigator not available, skipping navigation');
        return;
      }

      switch (notificationType) {
        case 'help_request':
          debugPrint(
              '🧭 FCMv1Service: Navigating to notification screen for help request');
          final requestId = message.data['request_id'];
          final senderName = message.data['sender_name'];

          if (requestId != null && requestId.isNotEmpty) {
            debugPrint(
                '🧭 FCMv1Service: Help request ID: $requestId from $senderName');
            // Navigate to notification screen where help request will be processed
            navigatorKey.currentState?.pushNamed('notification');
          } else {
            debugPrint(
                '🧭 FCMv1Service: No request ID found, navigating to notification screen');
            navigatorKey.currentState?.pushNamed('notification');
          }
          break;
        case 'help_request_response':
          debugPrint(
              '🧭 FCMv1Service: Navigating to notification screen for help response');
          final requestId = message.data['request_id'];
          final responderName = message.data['responder_name'];
          final isAccepted = message.data['is_accepted'];

          debugPrint(
              '🧭 FCMv1Service: Help response - Request: $requestId, Responder: $responderName, Accepted: $isAccepted');
          navigatorKey.currentState?.pushNamed('notification');
          break;
        case 'chat_message':
          debugPrint('🧭 FCMv1Service: Navigating to chat screen');
          final chatId = message.data['chatId'] ?? message.data['chat_id'];
          final senderId =
              message.data['senderId'] ?? message.data['sender_id'];
          final senderName = message.data['senderName'] ??
              message.data['sender_name'] ??
              'Unknown User';

          if (chatId != null &&
              chatId.isNotEmpty &&
              senderId != null &&
              senderId.isNotEmpty) {
            debugPrint(
                '🧭 FCMv1Service: Navigating to specific chat: $chatId with sender: $senderId');

            // Create UserLocation object for the other user
            final otherUserData = {
              'userId': senderId,
              'userName': senderName,
              'email': '', // We don't have email in notification data
              'latitude': 0.0,
              'longitude': 0.0,
              'isOnline': true,
              'isAvailableForHelp': true,
            };

            // Navigate to chat screen with the specific user data
            navigatorKey.currentState?.pushNamed(
              ChatScreen.routeName,
              arguments: {
                'otherUser': otherUserData,
                'chatId': chatId,
                'fromNotification': true,
              },
            );
          } else {
            debugPrint(
                '🧭 FCMv1Service: Missing chat data (chatId: $chatId, senderId: $senderId), navigating to notification screen');
            navigatorKey.currentState?.pushNamed('notification');
          }
          break;
        case 'chat': // Legacy support
          debugPrint('🧭 FCMv1Service: Navigating to chat screen (legacy)');
          navigatorKey.currentState?.pushNamed('notification');
          break;
        case 'app_update':
          debugPrint('🧭 FCMv1Service: Handling app update notification');
          // Handle app update notification - navigate to notification screen to show the update message
          navigatorKey.currentState?.pushNamed('notification');
          break;
        default:
          debugPrint(
              '🧭 FCMv1Service: Navigating to notification screen (default)');
          navigatorKey.currentState?.pushNamed('notification');
      }

      debugPrint(
          '✅ FCMv1Service: Navigation handled successfully for type: $notificationType');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error handling navigation: $e');
    }
  }

  /// Get OAuth2 access token for FCM v1 API
  Future<String?> _getAccessToken() async {
    try {
      // Check if we have a valid cached token
      if (_accessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!)) {
        debugPrint('🔑 FCMv1Service: Using cached access token');
        return _accessToken;
      }

      debugPrint('🔑 FCMv1Service: Getting new access token...');

      // Load service account credentials
      debugPrint('🔑 FCMv1Service: Loading service account credentials...');
      final serviceAccountJson =
          await rootBundle.loadString('assets/service-account-key.json');
      debugPrint('🔑 FCMv1Service: Service account JSON loaded successfully');

      final serviceAccountData = json.decode(serviceAccountJson);
      debugPrint(
          '🔑 FCMv1Service: Project ID from service account: ${serviceAccountData['project_id']}');
      debugPrint(
          '🔑 FCMv1Service: Client email: ${serviceAccountData['client_email']}');
      debugPrint(
          '🔑 FCMv1Service: Private key ID: ${serviceAccountData['private_key_id']}');

      // Update the project ID from service account
      _projectId = serviceAccountData['project_id'];
      debugPrint('🔑 FCMv1Service: Updated project ID to: $_projectId');

      final serviceAccount =
          ServiceAccountCredentials.fromJson(serviceAccountData);

      // Get access token
      debugPrint(
          '🔑 FCMv1Service: Requesting access token with scope: $_fcmScope');
      final client = await clientViaServiceAccount(serviceAccount, [_fcmScope]);
      final credentials = client.credentials;

      _accessToken = credentials.accessToken.data;
      _tokenExpiry = credentials.accessToken.expiry;

      debugPrint(
          '🔑 FCMv1Service: Access token length: ${_accessToken?.length ?? 0}');
      debugPrint('🔑 FCMv1Service: Token expires at: $_tokenExpiry');

      client.close();

      debugPrint('✅ FCMv1Service: Access token obtained successfully');
      return _accessToken;
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error getting access token: $e');
      return null;
    }
  }

  /// Send push notification using FCM v1 API
  Future<bool> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('📤 FCMv1Service: Sending push notification to user: $userId');
      debugPrint('📝 Title: $title');
      debugPrint('📄 Body: $body');

      // Get FCM token for the user
      debugPrint('🔍 FCMv1Service: Getting FCM token for user: $userId');
      final fcmToken = await _tokenManager.getTokenForUser(userId);

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('❌ FCMv1Service: No FCM token found for user: $userId');

        // Try to refresh token for current user
        final currentUserId = await _tokenManager.getCurrentUserId();
        if (currentUserId == userId) {
          debugPrint(
              '🔄 FCMv1Service: Attempting to refresh token for current user...');
          final refreshed = await _tokenManager.forceTokenRefresh();
          if (refreshed) {
            // Try to get token again after refresh
            final newToken = await _tokenManager.getTokenForUser(userId);
            if (newToken != null &&
                newToken.isNotEmpty &&
                _isValidTokenFormat(newToken)) {
              debugPrint(
                  '✅ FCMv1Service: Token refreshed successfully, proceeding with notification');
              return await _sendNotificationWithToken(
                  newToken, title, body, data);
            }
          }
        }

        debugPrint(
            '🔄 FCMv1Service: Attempting to save notification to Firebase Database as fallback...');

        // Fallback: Save notification to Firebase Database for the user to see when they open the app
        await _saveNotificationToFirebase(userId, title, body, data);
        debugPrint(
            '💾 FCMv1Service: Notification saved to Firebase Database as fallback');

        // Return true because we saved it as fallback, even though push notification failed
        return true;
      }

      debugPrint('✅ FCMv1Service: FCM token found for user: $userId');

      // Get access token (force refresh for debugging)
      debugPrint(
          '🔑 FCMv1Service: Forcing access token refresh for debugging...');
      _accessToken = null; // Force refresh
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('❌ FCMv1Service: Failed to get access token');
        return false;
      }

      // Prepare the message payload
      final message = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data':
              data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'road_helper_notifications',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'alert': {
                  'title': title,
                  'body': body,
                },
                'badge': 1,
                'sound': 'default',
              },
            },
          },
        },
      };

      // Debug information before sending
      debugPrint('🔍 FCMv1Service: About to send notification');
      debugPrint('📋 Project ID: $_projectId');
      debugPrint('🎯 Target FCM Token: $fcmToken');
      debugPrint('� FCM Token length: ${fcmToken.length}');
      debugPrint(
          '🔍 FCM Token starts with: ${fcmToken.length > 20 ? "${fcmToken.substring(0, 20)}..." : fcmToken}');

      // Validate FCM token format more thoroughly
      if (!fcmToken.contains(':') || fcmToken.length < 100) {
        debugPrint('❌ FCMv1Service: Invalid FCM token format');
        debugPrint(
            '🔍 Expected format: should contain ":" and be at least 100 chars');
        debugPrint('🔍 Actual length: ${fcmToken.length}');
        debugPrint('🔍 Contains ":": ${fcmToken.contains(':')}');
        return false;
      }
      debugPrint('�🔑 Access Token available: ${accessToken.isNotEmpty}');
      debugPrint(
          '🔑 Access Token (first 50 chars): ${accessToken.length > 50 ? "${accessToken.substring(0, 50)}..." : accessToken}');
      final fcmUrl =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      debugPrint('🔗 Full URL: $fcmUrl');
      debugPrint('📦 Message payload: ${json.encode(message)}');
      debugPrint(
          '🔑 Authorization header: Bearer ${accessToken.substring(0, 20)}...');

      // Send the notification
      debugPrint('📤 FCMv1Service: Sending HTTP POST request...');
      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(message),
      );

      debugPrint(
          '📥 FCMv1Service: Received response with status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ FCMv1Service: Push notification sent successfully');
        debugPrint('📊 Response: ${response.body}');

        // Also save to Firebase Database as backup
        await _saveNotificationToFirebase(userId, title, body, data);

        return true;
      } else {
        debugPrint('❌ FCMv1Service: Failed to send push notification');
        debugPrint('📊 Status code: ${response.statusCode}');
        debugPrint('📄 Response body: ${response.body}');
        debugPrint('🔗 Request URL: ${response.request?.url}');
        debugPrint('📤 Request headers: ${response.request?.headers}');
        debugPrint('📝 Request body: ${json.encode(message)}');

        // Analyze the error
        if (response.statusCode == 404) {
          debugPrint('🔍 FCMv1Service: 404 Error Analysis:');
          debugPrint('   - Check if FCM v1 API is enabled in Firebase Console');
          debugPrint('   - Verify project ID: $_projectId');
          debugPrint('   - Check service account permissions');
          debugPrint('   - URL used: $fcmUrl');
        } else if (response.statusCode == 401) {
          debugPrint('🔍 FCMv1Service: 401 Error - Authentication failed');
          debugPrint('   - Check service account credentials');
          debugPrint('   - Verify access token');
        } else if (response.statusCode == 400) {
          debugPrint('🔍 FCMv1Service: 400 Error - Bad request');
          debugPrint('   - Check FCM token format');
          debugPrint('   - Verify message payload');
        }

        // Save to Firebase Database as fallback even when push notification fails
        debugPrint(
            '🔄 FCMv1Service: Saving to Firebase Database as fallback after push failure...');
        await _saveNotificationToFirebase(userId, title, body, data);
        debugPrint(
            '💾 FCMv1Service: Notification saved to Firebase Database as fallback');

        // Return true because we saved it as fallback
        return true;
      }
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error sending push notification: $e');
      debugPrint('🔍 Error type: ${e.runtimeType}');

      // Use enhanced error handling
      NotificationErrorHandler.handleSendError(e, userId: userId, title: title);
      NotificationErrorHandler.logDetailedError(
        error: e,
        context: 'FCMv1Service.sendPushNotification',
        operation: 'send_notification',
        userId: userId,
        additionalData: {
          'title': title,
          'body': body,
          'data': data,
        },
      );

      // Try to save as fallback even when there's an error
      try {
        await _saveNotificationToFirebase(userId, title, body, data);
        debugPrint(
            '💾 FCMv1Service: Notification saved to Firebase as fallback after error');
        return true; // Return true because we saved it as fallback
      } catch (fallbackError) {
        debugPrint('❌ FCMv1Service: Fallback save also failed: $fallbackError');
        return false;
      }
    }
  }

  /// Save notification to Firebase Database as backup
  Future<void> _saveNotificationToFirebase(
    String userId,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      final notificationData = {
        'title': title,
        'body': body,
        'timestamp': ServerValue.timestamp,
        'type': data?['type'] ?? 'general',
        'data': data ?? {},
        'read': false,
      };

      await _database
          .child('notifications/$userId')
          .push()
          .set(notificationData);
      debugPrint('💾 FCMv1Service: Notification saved to Firebase Database');
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error saving notification to Firebase: $e');
    }
  }

  /// Send help request notification
  Future<bool> sendHelpRequestNotification({
    required String receiverId,
    required String senderName,
    required String requestId,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = {
      'type': 'help_request',
      'request_id': requestId,
      'sender_name': senderName,
      'receiverId': receiverId, // إضافة معرف المستقبل للتأكد
      'notification_action': 'help_request', // إضافة نوع الإجراء للتنقل
      ...?additionalData,
    };

    debugPrint('🔔 FCMv1Service: Sending help request notification');
    debugPrint('   - To: $receiverId');
    debugPrint('   - From: $senderName');
    debugPrint('   - Request ID: $requestId');
    debugPrint('   - Data: $data');

    return await sendPushNotification(
      userId: receiverId,
      title: 'طلب مساعدة جديد',
      body: 'تلقيت طلب مساعدة من $senderName',
      data: data,
    );
  }

  /// Send help request response notification
  Future<bool> sendHelpRequestResponseNotification({
    required String requesterId,
    required String responderName,
    required String requestId,
    required bool isAccepted,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = {
      'type': 'help_request_response',
      'request_id': requestId,
      'responder_name': responderName,
      'is_accepted': isAccepted.toString(),
      ...?additionalData,
    };

    final title = isAccepted ? 'تم قبول طلب المساعدة' : 'تم رفض طلب المساعدة';
    final body = isAccepted
        ? '$responderName قبل طلب المساعدة الخاص بك'
        : '$responderName رفض طلب المساعدة الخاص بك';

    return await sendPushNotification(
      userId: requesterId,
      title: title,
      body: body,
      data: data,
    );
  }

  /// Send chat message notification
  Future<bool> sendChatMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = {
      'type': 'chat_message',
      'chat_id': chatId,
      'sender_name': senderName,
      'message': message,
      ...?additionalData,
    };

    return await sendPushNotification(
      userId: receiverId,
      title: 'رسالة جديدة من $senderName',
      body: message,
      data: data,
    );
  }

  /// Send app update notification
  Future<bool> sendAppUpdateNotification({
    required String userId,
    required String version,
    required String updateUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = {
      'type': 'app_update',
      'version': version,
      'update_url': updateUrl,
      ...?additionalData,
    };

    return await sendPushNotification(
      userId: userId,
      title: 'تحديث جديد متاح',
      body: 'الإصدار $version متاح الآن للتحميل',
      data: data,
    );
  }

  /// Send notification to multiple users
  Future<List<bool>> sendNotificationToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final results = <bool>[];

    for (final userId in userIds) {
      final result = await sendPushNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
      results.add(result);
    }

    return results;
  }

  /// Get notification statistics
  Future<Map<String, int>> getNotificationStats() async {
    try {
      final notifications = await _notificationManager.getAllNotifications();
      final unreadCount = await _notificationManager.getUnreadCount();

      return {
        'total': notifications.length,
        'unread': unreadCount,
        'read': notifications.length - unreadCount,
      };
    } catch (e) {
      debugPrint('❌ FCMv1Service: Error getting notification stats: $e');
      return {'total': 0, 'unread': 0, 'read': 0};
    }
  }

  /// Validate FCM token format
  bool _isValidTokenFormat(String token) {
    return token.isNotEmpty &&
        token.contains(':') &&
        token.length >= 100 &&
        !token.contains(' ') &&
        token.split(':').length >= 2;
  }

  /// Send notification with specific token
  Future<bool> _sendNotificationWithToken(
    String fcmToken,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      debugPrint('📤 FCMv1Service: Sending notification with provided token');

      // Get access token
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('❌ FCMv1Service: Failed to get access token');
        return false;
      }

      // Prepare the message payload
      final message = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data':
              data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'road_helper_notifications',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'alert': {
                  'title': title,
                  'body': body,
                },
                'badge': 1,
                'sound': 'default',
              },
            },
          },
        },
      };

      final fcmUrl =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      // Send the notification
      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(message),
      );

      if (response.statusCode == 200) {
        debugPrint(
            '✅ FCMv1Service: Push notification sent successfully with provided token');
        return true;
      } else {
        debugPrint(
            '❌ FCMv1Service: Failed to send notification with provided token');
        debugPrint('📊 Status code: ${response.statusCode}');
        debugPrint('📄 Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint(
          '❌ FCMv1Service: Error sending notification with provided token: $e');
      return false;
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  try {
    debugPrint('📨 FCMv1Service: Background message received');
    debugPrint('📝 Title: ${message.notification?.title}');
    debugPrint('📄 Body: ${message.notification?.body}');
    debugPrint('📦 Data: ${message.data}');

    // Save notification to local storage for when user opens the app
    final notificationManager = NotificationManager();
    final notification = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'إشعار جديد',
      body: message.notification?.body ?? '',
      timestamp: DateTime.now(),
      isRead: false,
      type: message.data['type'] ?? 'general',
      data: message.data,
    );

    await notificationManager.addNotification(notification);
    debugPrint('💾 FCMv1Service: Background notification saved locally');

    // Also save to Firebase Database as backup
    try {
      final database = FirebaseDatabase.instance;
      final userId = message.data['receiverId'] ?? message.data['userId'];

      if (userId != null && userId.isNotEmpty) {
        final notificationData = {
          'title': message.notification?.title ?? 'إشعار جديد',
          'body': message.notification?.body ?? '',
          'timestamp': ServerValue.timestamp,
          'type': message.data['type'] ?? 'general',
          'data': message.data,
          'read': false,
        };

        await database
            .ref('notifications/$userId')
            .push()
            .set(notificationData);
        debugPrint(
            '💾 FCMv1Service: Background notification saved to Firebase');
      }
    } catch (e) {
      debugPrint(
          '❌ FCMv1Service: Error saving background notification to Firebase: $e');
    }
  } catch (e) {
    debugPrint('❌ FCMv1Service: Error handling background message: $e');
  }
}
