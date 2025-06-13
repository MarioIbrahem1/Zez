import 'package:flutter/material.dart';
import '../services/sos_service.dart';
import '../services/auth_service.dart';
import '../services/power_button_detector.dart';
import '../services/accessibility_service.dart';
import 'power_button_test_widget.dart';
import '../ui/widgets/accessibility_alert_widget.dart';

/// شاشة اختبار خدمات SOS
class SOSTestScreen extends StatefulWidget {
  static const String routeName = '/sos-test';

  const SOSTestScreen({super.key});

  @override
  State<SOSTestScreen> createState() => _SOSTestScreenState();
}

class _SOSTestScreenState extends State<SOSTestScreen> {
  final SOSService _sosService = SOSService();
  final AuthService _authService = AuthService();
  final PowerButtonDetector _powerButtonDetector = PowerButtonDetector();

  bool _isLoading = false;
  String _lastResult = '';
  Map<String, dynamic>? _sessionInfo;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    try {
      final canUseSos = await _authService.canUseSosServices();
      final isLoggedIn = await _authService.isLoggedIn();
      final emergencyContacts = await _authService.getEmergencyContacts();

      setState(() {
        _sessionInfo = {
          'canUseSos': canUseSos,
          'isLoggedIn': isLoggedIn,
          'emergencyContacts': emergencyContacts,
        };
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Error loading session info: $e';
      });
    }
  }

  Future<void> _testSOSAlert() async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Testing SOS Alert...';
    });

    try {
      debugPrint('🧪 SOSTestScreen: Starting SOS alert test...');
      final result = await _sosService.triggerSosAlert();

      setState(() {
        _lastResult = result
            ? '✅ SOS Alert sent successfully!'
            : '❌ SOS Alert failed to send';
        _isLoading = false;
      });

      debugPrint('🧪 SOSTestScreen: SOS test result: $result');
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error during SOS test: $e';
        _isLoading = false;
      });
      debugPrint('🧪 SOSTestScreen: SOS test error: $e');
    }
  }

  Future<void> _testPowerButtonCallback() async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Testing Power Button Callback...';
    });

    try {
      debugPrint('🧪 SOSTestScreen: Testing power button callback...');

      // محاكاة استدعاء الـ callback مباشرة
      await _powerButtonDetector.initialize();
      _powerButtonDetector.setTriplePressCallback(() async {
        debugPrint('🧪 SOSTestScreen: Power button callback triggered!');
        final result = await _sosService.triggerSosAlert();
        setState(() {
          _lastResult = result
              ? '✅ Power Button Callback worked! SOS sent.'
              : '❌ Power Button Callback worked but SOS failed';
          _isLoading = false;
        });
      });

      // محاكاة الضغط الثلاثي
      debugPrint('🧪 SOSTestScreen: Simulating triple press...');
      // يمكننا استدعاء الـ callback مباشرة للاختبار

      setState(() {
        _lastResult =
            '✅ Power Button Callback set successfully. Try triple press now.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error testing power button: $e';
        _isLoading = false;
      });
      debugPrint('🧪 SOSTestScreen: Power button test error: $e');
    }
  }

  Future<void> _addTestEmergencyContacts() async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Adding test emergency contacts...';
    });

    try {
      final testContacts = ['+1234567890', '+0987654321'];
      await _authService.saveEmergencyContacts(testContacts);

      await _loadSessionInfo(); // إعادة تحميل معلومات الجلسة

      setState(() {
        _lastResult = '✅ Test emergency contacts added successfully';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error adding emergency contacts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testAccessibilityService() async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Testing Accessibility Service...';
    });

    try {
      final isEnabled =
          await AccessibilityService.isAccessibilityServiceEnabled();

      setState(() {
        _lastResult = isEnabled
            ? '✅ Accessibility Service is enabled and working!'
            : '⚠️ Accessibility Service is NOT enabled - SOS button detection will not work';
        _isLoading = false;
      });

      if (!isEnabled) {
        // إظهار dialog للمساعدة
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AccessibilityAlertWidget(
              showAsDialog: true,
              onDismiss: () => Navigator.of(context).pop(),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error testing accessibility service: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Test Screen'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // معلومات الجلسة
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_sessionInfo != null) ...[
                      _buildInfoRow(
                          'Logged In', _sessionInfo!['isLoggedIn'].toString()),
                      _buildInfoRow('SOS Available',
                          _sessionInfo!['canUseSos'].toString()),
                      _buildInfoRow('Emergency Contacts',
                          '${(_sessionInfo!['emergencyContacts'] as List).length} contacts'),
                    ] else
                      const Text('Loading session info...'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Power Button Test Widget
            const PowerButtonTestWidget(),

            const SizedBox(height: 16),

            // أزرار الاختبار
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSOSAlert,
              icon: const Icon(Icons.emergency),
              label: const Text('Test SOS Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testPowerButtonCallback,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Test Power Button Callback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _addTestEmergencyContacts,
              icon: const Icon(Icons.contacts),
              label: const Text('Add Test Emergency Contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadSessionInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Session Info'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testAccessibilityService,
              icon: const Icon(Icons.accessibility),
              label: const Text('Test Accessibility Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 16),

            // نتائج الاختبار
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Results',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Testing...'),
                        ],
                      )
                    else
                      Text(
                        _lastResult.isEmpty ? 'No tests run yet' : _lastResult,
                        style: TextStyle(
                          color: _lastResult.startsWith('✅')
                              ? Colors.green
                              : _lastResult.startsWith('❌')
                                  ? Colors.red
                                  : Colors.black,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ملاحظات
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Make sure you have emergency contacts added\n'
                    '• SOS services work even without active login token\n'
                    '• Power button test requires physical triple press\n'
                    '• Check console logs for detailed debugging',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
