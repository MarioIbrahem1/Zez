import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/help_request_diagnostics.dart';
import '../../services/firebase_help_request_service.dart';
import '../../services/fcm_v1_service.dart';
import '../../services/fcm_token_manager.dart';

/// Test screen for Help Request system diagnostics and testing
class HelpRequestTestScreen extends StatefulWidget {
  const HelpRequestTestScreen({super.key});

  @override
  State<HelpRequestTestScreen> createState() => _HelpRequestTestScreenState();
}

class _HelpRequestTestScreenState extends State<HelpRequestTestScreen> {
  Map<String, dynamic>? _diagnosticResults;
  bool _isRunningDiagnostics = false;
  bool _isSendingTestRequest = false;
  String _testResults = '';

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunningDiagnostics = true;
    });

    try {
      final results = await HelpRequestDiagnostics.runDiagnostics();
      setState(() {
        _diagnosticResults = results;
        _isRunningDiagnostics = false;
      });

      // Print results to console
      HelpRequestDiagnostics.printResults(results);
    } catch (e) {
      setState(() {
        _isRunningDiagnostics = false;
        _testResults = 'Diagnostics failed: $e';
      });
    }
  }

  Future<void> _testFCMTokenSave() async {
    setState(() {
      _testResults = 'Testing FCM token save...';
    });

    try {
      final tokenManager = FCMTokenManager();
      final result = await tokenManager.saveTokenOnLogin();

      setState(() {
        _testResults = result
            ? '✅ FCM token saved successfully'
            : '❌ FCM token save failed';
      });
    } catch (e) {
      setState(() {
        _testResults = '❌ FCM token test error: $e';
      });
    }
  }

  Future<void> _testNotificationSend() async {
    setState(() {
      _testResults = 'Testing notification send...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _testResults = '❌ No authenticated user for notification test';
        });
        return;
      }

      // أولاً: التحقق من أذونات الإشعارات
      setState(() {
        _testResults = 'Checking notification permissions...';
      });

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        setState(() {
          _testResults =
              '❌ Notification permissions denied.\n\n📱 Please enable notifications:\n1. Go to Settings > Apps > Road Helper\n2. Enable Notifications\n3. Try the test again';
        });

        // Show dialog to open app settings
        if (mounted) {
          _showNotificationSettingsDialog();
        }
        return;
      }

      setState(() {
        _testResults = 'Permissions OK. Sending test notification...';
      });

      final fcmService = FCMv1Service();
      final result = await fcmService.sendHelpRequestNotification(
        receiverId: currentUser.uid, // Send to self for testing
        senderName: currentUser.displayName ?? 'Test User',
        requestId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        additionalData: {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _testResults = result
            ? '✅ Test notification sent successfully\n📱 Check your device notifications!'
            : '❌ Test notification send failed';
      });
    } catch (e) {
      setState(() {
        _testResults = '❌ Notification test error: $e';
      });
    }
  }

  Future<void> _testHelpRequestFlow() async {
    setState(() {
      _isSendingTestRequest = true;
      _testResults = 'Testing help request flow...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _testResults = '❌ No authenticated user for help request test';
          _isSendingTestRequest = false;
        });
        return;
      }

      // Create a test help request to self
      final helpRequestService = FirebaseHelpRequestService();
      const testLocation = LatLng(24.7136, 46.6753); // Riyadh coordinates

      final requestId = await helpRequestService.sendHelpRequest(
        receiverId: currentUser.uid, // Send to self for testing
        receiverName: currentUser.displayName ?? 'Test Receiver',
        senderLocation: testLocation,
        receiverLocation: testLocation,
        message: 'This is a test help request for system validation',
      );

      setState(() {
        _testResults =
            '✅ Test help request sent successfully\nRequest ID: $requestId';
        _isSendingTestRequest = false;
      });
    } catch (e) {
      setState(() {
        _testResults = '❌ Help request test error: $e';
        _isSendingTestRequest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Request System Test'),
        backgroundColor: const Color(0xFF023A87),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diagnostics Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Diagnostics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isRunningDiagnostics)
                      const Center(child: CircularProgressIndicator())
                    else if (_diagnosticResults != null)
                      _buildDiagnosticsResults()
                    else
                      const Text('No diagnostics data available'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isRunningDiagnostics ? null : _runDiagnostics,
                      child: const Text('Run Diagnostics Again'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Actions Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // FCM Token Test
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _testFCMTokenSave,
                        child: const Text('Test FCM Token Save'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Notification Test
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _testNotificationSend,
                        child: const Text('Test Notification Send'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Help Request Test
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isSendingTestRequest ? null : _testHelpRequestFlow,
                        child: _isSendingTestRequest
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test Help Request Flow'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Results Section
            if (_testResults.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _testResults,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _diagnosticResults!.entries.map((entry) {
        final key = entry.key;
        final value = entry.value;

        if (value is Map<String, dynamic>) {
          return ExpansionTile(
            title: Text(
              key.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: value.entries.map((subEntry) {
              return ListTile(
                dense: true,
                title: Text(subEntry.key.replaceAll('_', ' ')),
                trailing: _buildStatusIcon(subEntry.value),
                subtitle: Text(subEntry.value.toString()),
              );
            }).toList(),
          );
        } else {
          return ListTile(
            title: Text(key.replaceAll('_', ' ').toUpperCase()),
            trailing: _buildStatusIcon(value),
            subtitle: Text(value.toString()),
          );
        }
      }).toList(),
    );
  }

  Widget _buildStatusIcon(dynamic value) {
    if (value is bool) {
      return Icon(
        value ? Icons.check_circle : Icons.error,
        color: value ? Colors.green : Colors.red,
      );
    } else if (value is String && value.toLowerCase().contains('error')) {
      return const Icon(Icons.error, color: Colors.red);
    } else if (value != null && value.toString().isNotEmpty) {
      return const Icon(Icons.info, color: Colors.blue);
    } else {
      return const Icon(Icons.warning, color: Colors.orange);
    }
  }

  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🔔 Enable Notifications'),
          content: const Text(
            'To receive push notifications, please:\n\n'
            '1. Go to Settings > Apps > Road Helper\n'
            '2. Tap on "Notifications"\n'
            '3. Enable "Allow notifications"\n'
            '4. Return to the app and try again',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
