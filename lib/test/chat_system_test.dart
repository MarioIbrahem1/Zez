import 'package:flutter/material.dart';
import 'package:road_helperr/services/chat_service.dart';
import 'package:road_helperr/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test screen for verifying enhanced chat functionality
class ChatSystemTestScreen extends StatefulWidget {
  const ChatSystemTestScreen({super.key});

  static const String routeName = '/chat-test';

  @override
  State<ChatSystemTestScreen> createState() => _ChatSystemTestScreenState();
}

class _ChatSystemTestScreenState extends State<ChatSystemTestScreen> {
  final ChatService _chatService = ChatService();
  bool _isGoogleUser = false;
  bool _isLoading = true;
  List<String> _testResults = [];

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    await _testGoogleUserDetection();
    await _testChatAvailability();
    await _testFirebaseIntegration();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testGoogleUserDetection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isGoogleUser = prefs.getBool('is_google_sign_in') ?? false;
      
      _addTestResult(
        '✅ Google User Detection: ${_isGoogleUser ? 'Google User' : 'Traditional User'}'
      );
    } catch (e) {
      _addTestResult('❌ Google User Detection Failed: $e');
    }
  }

  Future<void> _testChatAvailability() async {
    try {
      final isAvailable = await _chatService.isChatAvailable();
      _addTestResult(
        '${isAvailable ? '✅' : '⚠️'} Chat Availability: ${isAvailable ? 'Available' : 'Not Available'}'
      );
    } catch (e) {
      _addTestResult('❌ Chat Availability Test Failed: $e');
    }
  }

  Future<void> _testFirebaseIntegration() async {
    if (!_isGoogleUser) {
      _addTestResult('⚠️ Firebase Integration: Skipped (Non-Google User)');
      return;
    }

    try {
      // Test getting chat stream
      final stream = await _chatService.getChatStream('test_user_id');
      _addTestResult('✅ Firebase Integration: Chat stream created successfully');
      
      // Test sending a message (this will fail gracefully if no real user)
      final success = await _chatService.sendMessage(
        receiverId: 'test_user_id',
        content: 'Test message from chat system test',
      );
      
      _addTestResult(
        '${success ? '✅' : '⚠️'} Message Sending: ${success ? 'Success' : 'Failed (expected for test)'}'
      );
    } catch (e) {
      _addTestResult('❌ Firebase Integration Test Failed: $e');
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults.add(result);
    });
    debugPrint('Chat Test: $result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat System Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runTests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Running Chat System Tests...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat System Status',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'User Type: ${_isGoogleUser ? 'Google User' : 'Traditional User'}',
                            style: TextStyle(
                              color: _isGoogleUser ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chat Available: ${_isGoogleUser ? 'Yes' : 'No'}',
                            style: TextStyle(
                              color: _isGoogleUser ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Test Results:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _testResults.length,
                      itemBuilder: (context, index) {
                        final result = _testResults[index];
                        final isSuccess = result.startsWith('✅');
                        final isWarning = result.startsWith('⚠️');
                        final isError = result.startsWith('❌');

                        return Card(
                          color: isSuccess
                              ? Colors.green.shade50
                              : isWarning
                                  ? Colors.orange.shade50
                                  : isError
                                      ? Colors.red.shade50
                                      : null,
                          child: ListTile(
                            leading: Icon(
                              isSuccess
                                  ? Icons.check_circle
                                  : isWarning
                                      ? Icons.warning
                                      : isError
                                          ? Icons.error
                                          : Icons.info,
                              color: isSuccess
                                  ? Colors.green
                                  : isWarning
                                      ? Colors.orange
                                      : isError
                                          ? Colors.red
                                          : Colors.blue,
                            ),
                            title: Text(
                              result,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: isSuccess
                                    ? Colors.green.shade800
                                    : isWarning
                                        ? Colors.orange.shade800
                                        : isError
                                            ? Colors.red.shade800
                                            : Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isGoogleUser)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Chat Feature Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The enhanced chat feature is exclusively available for Google-authenticated users. '
                            'Traditional login users will see appropriate messaging when trying to access chat functionality.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
