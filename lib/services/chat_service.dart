import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:road_helperr/models/chat_message.dart';
import 'package:road_helperr/services/fcm_v1_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // Firebase Database instance
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controllers for each chat
  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};
  final Map<String, StreamSubscription> _chatSubscriptions = {};

  // Notification service
  final FCMv1Service _fcmService = FCMv1Service();

  // Check if user is Google authenticated
  Future<bool> _isGoogleUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_google_sign_in') ?? false;
  }

  // Check if chat features are available for current user
  Future<bool> isChatAvailable() async {
    return await _isGoogleUser();
  }

  // Get current user ID
  Future<String> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    // Try multiple possible user ID keys
    String? userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      userId = prefs.getString('current_user_id');
    }
    if (userId == null || userId.isEmpty) {
      // Generate a temporary user ID based on email if available
      final email = prefs.getString('user_email');
      if (email != null && email.isNotEmpty) {
        userId = email.replaceAll('@', '_').replaceAll('.', '_');
      }
    }
    if (userId == null || userId.isEmpty) {
      // Fallback to a temporary ID
      userId = 'temp_user_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('user_id', userId);
    }
    return userId;
  }

  // Get current user name
  Future<String> _getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();

    // First check if user is Google authenticated
    final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

    if (isGoogleSignIn) {
      // For Google users, try to get name from Firebase Auth first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.displayName != null &&
          currentUser.displayName!.isNotEmpty) {
        debugPrint(
            '💬 ChatService: Using Google user display name: ${currentUser.displayName}');
        return currentUser.displayName!;
      }

      // Fallback: try to get from API data stored in SharedPreferences
      final googleUserData = prefs.getString('google_user_data');
      if (googleUserData != null) {
        try {
          final userData = jsonDecode(googleUserData);
          final name = userData['name'] ?? userData['firstName'];
          if (name != null && name.isNotEmpty) {
            debugPrint(
                '💬 ChatService: Using Google user name from API data: $name');
            return name;
          }
        } catch (e) {
          debugPrint('❌ ChatService: Error parsing Google user data: $e');
        }
      }
    }

    // For traditional users or fallback
    String? userName = prefs.getString('user_name');
    if (userName == null || userName.isEmpty) {
      // Try to get from email
      final email = prefs.getString('user_email');
      if (email != null && email.isNotEmpty) {
        userName = email.split('@')[0]; // Use part before @ as name
      }
    }

    final finalName = userName ?? 'مستخدم';
    debugPrint('💬 ChatService: Final user name: $finalName');
    return finalName;
  }

  // Send notification to user about new message
  Future<void> _sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String messageContent,
  }) async {
    try {
      debugPrint(
          '💬 ChatService: Sending notification to $receiverId from $senderName');

      final success = await _fcmService.sendChatMessageNotification(
        receiverId: receiverId,
        senderName: senderName,
        message: messageContent,
        chatId: _getChatId(await _getCurrentUserId(), receiverId),
        additionalData: {
          'senderId': await _getCurrentUserId(),
        },
      );

      if (success) {
        debugPrint('✅ ChatService: Notification sent successfully');
      } else {
        debugPrint('❌ ChatService: Failed to send notification');
      }
    } catch (e) {
      debugPrint('❌ ChatService: Error sending notification: $e');
    }
  }

  // Get chat ID from user IDs
  String _getChatId(String userId1, String userId2) {
    // Sort IDs to ensure consistent chat ID regardless of who initiates
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Get stream for a specific chat
  Future<Stream<List<ChatMessage>>> getChatStream(String otherUserId) async {
    try {
      // Check if user is Google authenticated
      if (!await _isGoogleUser()) {
        debugPrint('❌ ChatService: Chat not available for non-Google users');
        final controller = StreamController<List<ChatMessage>>.broadcast();
        Future.microtask(() => controller.add([]));
        return controller.stream;
      }

      final currentUserId = await _getCurrentUserId();
      debugPrint(
          '💬 ChatService: Getting chat stream for current user: $currentUserId, other user: $otherUserId');

      final chatId = _getChatId(currentUserId, otherUserId);
      debugPrint('💬 ChatService: Chat ID: $chatId');

      if (!_chatControllers.containsKey(chatId)) {
        debugPrint(
            '💬 ChatService: Creating new stream controller for chat: $chatId');
        _chatControllers[chatId] =
            StreamController<List<ChatMessage>>.broadcast();

        // Set up Firebase listener for real-time updates
        await _setupFirebaseListener(chatId);
      } else {
        debugPrint(
            '💬 ChatService: Using existing stream controller for chat: $chatId');
      }

      return _chatControllers[chatId]!.stream;
    } catch (e) {
      debugPrint('❌ ChatService: Error getting chat stream: $e');
      // Return a stream with empty list in case of error
      final controller = StreamController<List<ChatMessage>>.broadcast();
      Future.microtask(() => controller.add([]));
      return controller.stream;
    }
  }

  // Setup Firebase listener for real-time chat updates
  Future<void> _setupFirebaseListener(String chatId) async {
    try {
      debugPrint(
          '🔥 ChatService: Setting up Firebase listener for chat: $chatId');

      // Cancel existing subscription if any
      if (_chatSubscriptions.containsKey(chatId)) {
        await _chatSubscriptions[chatId]!.cancel();
      }

      // Create Firebase reference for this chat
      final chatRef = _database.ref('chats/$chatId/messages');

      // Listen to changes
      final subscription = chatRef.orderByChild('timestamp').onValue.listen(
        (event) {
          try {
            final data = event.snapshot.value;
            final List<ChatMessage> messages = [];

            if (data != null && data is Map) {
              final messagesMap = Map<String, dynamic>.from(data);

              for (final entry in messagesMap.entries) {
                try {
                  final messageData = Map<String, dynamic>.from(entry.value);
                  messageData['id'] =
                      entry.key; // Add the Firebase key as message ID
                  final message = ChatMessage.fromJson(messageData);
                  messages.add(message);
                } catch (e) {
                  debugPrint('❌ ChatService: Error parsing message: $e');
                }
              }

              // Sort messages by timestamp
              messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }

            debugPrint(
                '💬 ChatService: Received ${messages.length} messages from Firebase');

            // Update stream
            if (_chatControllers.containsKey(chatId)) {
              _chatControllers[chatId]!.add(messages);
            }
          } catch (e) {
            debugPrint('❌ ChatService: Error processing Firebase data: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ ChatService: Firebase listener error: $error');
        },
      );

      _chatSubscriptions[chatId] = subscription;
      debugPrint(
          '✅ ChatService: Firebase listener setup complete for chat: $chatId');
    } catch (e) {
      debugPrint('❌ ChatService: Error setting up Firebase listener: $e');
    }
  }

  // Send a message
  Future<bool> sendMessage({
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      // Check if user is Google authenticated
      if (!await _isGoogleUser()) {
        debugPrint(
            '❌ ChatService: Message sending not available for non-Google users');
        return false;
      }

      final currentUserId = await _getCurrentUserId();
      final currentUserName = await _getCurrentUserName();
      final chatId = _getChatId(currentUserId, receiverId);

      debugPrint(
          '💬 ChatService: Sending message from $currentUserId to $receiverId');
      debugPrint('💬 ChatService: Message content: $content');
      debugPrint('💬 ChatService: Chat ID: $chatId');

      // Create a new message
      final messageId = const Uuid().v4();
      final timestamp = DateTime.now();

      final messageData = {
        'senderId': currentUserId,
        'receiverId': receiverId,
        'content': content,
        'type': type.toString().split('.').last,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isRead': false,
        'createdAt': timestamp.toIso8601String(),
      };

      // Save to Firebase
      final chatRef = _database.ref('chats/$chatId/messages/$messageId');
      await chatRef.set(messageData);

      // Update chat metadata
      await _updateChatMetadata(
          chatId, currentUserId, receiverId, content, timestamp);

      debugPrint('✅ ChatService: Message saved to Firebase successfully');

      // Send notification to receiver
      await _sendMessageNotification(
        receiverId: receiverId,
        senderName: currentUserName,
        messageContent: content,
      );

      return true;
    } catch (e) {
      debugPrint('❌ ChatService: Error sending message: $e');
      return false;
    }
  }

  // Update chat metadata for chat list and last message tracking
  Future<void> _updateChatMetadata(
    String chatId,
    String senderId,
    String receiverId,
    String lastMessage,
    DateTime timestamp,
  ) async {
    try {
      final chatMetadata = {
        'chatId': chatId,
        'participants': [senderId, receiverId],
        'lastMessage': lastMessage,
        'lastMessageTime': timestamp.millisecondsSinceEpoch,
        'lastMessageSender': senderId,
        'updatedAt': timestamp.toIso8601String(),
      };

      // Update metadata for both users
      await _database.ref('userChats/$senderId/$chatId').set(chatMetadata);
      await _database.ref('userChats/$receiverId/$chatId').set(chatMetadata);

      debugPrint('✅ ChatService: Chat metadata updated successfully');
    } catch (e) {
      debugPrint('❌ ChatService: Error updating chat metadata: $e');
    }
  }

  // Send a location message
  Future<bool> sendLocationMessage({
    required String receiverId,
    required double latitude,
    required double longitude,
  }) async {
    return sendMessage(
      receiverId: receiverId,
      content: '$latitude,$longitude',
      type: MessageType.location,
    );
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String otherUserId) async {
    try {
      // Check if user is Google authenticated
      if (!await _isGoogleUser()) {
        debugPrint(
            '❌ ChatService: Mark as read not available for non-Google users');
        return;
      }

      final currentUserId = await _getCurrentUserId();
      final chatId = _getChatId(currentUserId, otherUserId);

      debugPrint('💬 ChatService: Marking messages as read for chat: $chatId');

      // Update all unread messages in Firebase
      final chatRef = _database.ref('chats/$chatId/messages');
      final snapshot =
          await chatRef.orderByChild('receiverId').equalTo(currentUserId).get();

      if (snapshot.exists && snapshot.value != null) {
        final messagesMap = Map<String, dynamic>.from(snapshot.value as Map);
        final updates = <String, dynamic>{};

        for (final entry in messagesMap.entries) {
          final messageData = Map<String, dynamic>.from(entry.value);
          if (messageData['isRead'] == false) {
            updates['chats/$chatId/messages/${entry.key}/isRead'] = true;
          }
        }

        if (updates.isNotEmpty) {
          await _database.ref().update(updates);
          debugPrint(
              '✅ ChatService: ${updates.length} messages marked as read');
        }
      }
    } catch (e) {
      debugPrint('❌ ChatService: Error marking messages as read: $e');
    }
  }

  // Get unread message count
  Future<int> getUnreadMessageCount(String otherUserId) async {
    try {
      // Check if user is Google authenticated
      if (!await _isGoogleUser()) {
        return 0;
      }

      final currentUserId = await _getCurrentUserId();
      final chatId = _getChatId(currentUserId, otherUserId);

      final chatRef = _database.ref('chats/$chatId/messages');
      final snapshot =
          await chatRef.orderByChild('receiverId').equalTo(currentUserId).get();

      if (snapshot.exists && snapshot.value != null) {
        final messagesMap = Map<String, dynamic>.from(snapshot.value as Map);
        int unreadCount = 0;

        for (final entry in messagesMap.entries) {
          final messageData = Map<String, dynamic>.from(entry.value);
          if (messageData['isRead'] == false) {
            unreadCount++;
          }
        }

        return unreadCount;
      }

      return 0;
    } catch (e) {
      debugPrint('❌ ChatService: Error getting unread count: $e');
      return 0;
    }
  }

  // Get user's chat list
  Future<List<Map<String, dynamic>>> getUserChats() async {
    try {
      // Check if user is Google authenticated
      if (!await _isGoogleUser()) {
        return [];
      }

      final currentUserId = await _getCurrentUserId();
      final userChatsRef = _database.ref('userChats/$currentUserId');
      final snapshot = await userChatsRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final chatsMap = Map<String, dynamic>.from(snapshot.value as Map);
        final chatsList = <Map<String, dynamic>>[];

        for (final entry in chatsMap.entries) {
          final chatData = Map<String, dynamic>.from(entry.value);
          chatsList.add(chatData);
        }

        // Sort by last message time
        chatsList.sort((a, b) {
          final timeA = a['lastMessageTime'] ?? 0;
          final timeB = b['lastMessageTime'] ?? 0;
          return timeB.compareTo(timeA);
        });

        return chatsList;
      }

      return [];
    } catch (e) {
      debugPrint('❌ ChatService: Error getting user chats: $e');
      return [];
    }
  }

  // Create chat room when help request is accepted
  Future<void> createChatFromHelpRequest({
    required String helpRequestId,
    required String senderId,
    required String receiverId,
    required String senderName,
    required String receiverName,
  }) async {
    try {
      // Check if user is Google authenticated
      if (!await _isGoogleUser()) {
        debugPrint(
            '❌ ChatService: Chat creation not available for non-Google users');
        return;
      }

      final chatId = _getChatId(senderId, receiverId);
      final timestamp = DateTime.now();

      // Create initial system message
      final systemMessageId = const Uuid().v4();
      final systemMessage = {
        'senderId': 'system',
        'receiverId': receiverId,
        'content': 'تم قبول طلب المساعدة. يمكنكم الآن التواصل مع بعضكم البعض.',
        'type': 'system',
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isRead': false,
        'createdAt': timestamp.toIso8601String(),
        'helpRequestId': helpRequestId,
      };

      // Save system message to Firebase
      await _database
          .ref('chats/$chatId/messages/$systemMessageId')
          .set(systemMessage);

      // Update chat metadata for both users
      await _updateChatMetadata(
        chatId,
        'system',
        receiverId,
        'تم قبول طلب المساعدة. يمكنكم الآن التواصل مع بعضكم البعض.',
        timestamp,
      );

      debugPrint(
          '✅ ChatService: Chat room created for help request: $helpRequestId');
    } catch (e) {
      debugPrint('❌ ChatService: Error creating chat from help request: $e');
    }
  }

  // Dispose resources
  void dispose() {
    // Cancel all Firebase subscriptions
    for (final subscription in _chatSubscriptions.values) {
      subscription.cancel();
    }
    _chatSubscriptions.clear();

    // Close all stream controllers
    for (final controller in _chatControllers.values) {
      controller.close();
    }
    _chatControllers.clear();
  }
}
