import 'package:flutter/material.dart';
import '../services/power_button_detector.dart';
import '../services/sos_service.dart';

/// Widget لاختبار الـ Power Button بطريقة سهلة
class PowerButtonTestWidget extends StatefulWidget {
  const PowerButtonTestWidget({super.key});

  @override
  State<PowerButtonTestWidget> createState() => _PowerButtonTestWidgetState();
}

class _PowerButtonTestWidgetState extends State<PowerButtonTestWidget> {
  final PowerButtonDetector _detector = PowerButtonDetector();
  final SOSService _sosService = SOSService();

  String _status = 'Not initialized';
  bool _isListening = false;
  int _testPressCount = 0;

  @override
  void initState() {
    super.initState();
    _initializePowerButton();
  }

  Future<void> _initializePowerButton() async {
    try {
      setState(() {
        _status = 'Initializing...';
      });

      await _detector.initialize();

      _detector.setTriplePressCallback(() async {
        setState(() {
          _status = '🚨 EMERGENCY TRIGGERED! Sending SOS...';
        });

        try {
          final result = await _sosService.triggerSosAlert();
          setState(() {
            _status = result
                ? '✅ SOS Alert sent successfully!'
                : '❌ SOS Alert failed';
          });
        } catch (e) {
          setState(() {
            _status = '❌ Error: $e';
          });
        }
      });

      setState(() {
        _status = '✅ Ready - Triple press power button for emergency';
        _isListening = true;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Failed to initialize: $e';
      });
    }
  }

  void _simulateTriplePress() async {
    setState(() {
      _testPressCount++;
      _status = 'Simulating press $_testPressCount/3...';
    });

    if (_testPressCount >= 3) {
      setState(() {
        _status = '🚨 Simulating EMERGENCY! Sending SOS...';
        _testPressCount = 0;
      });

      try {
        final result = await _sosService.triggerSosAlert();
        setState(() {
          _status = result
              ? '✅ Simulated SOS Alert sent successfully!'
              : '❌ Simulated SOS Alert failed';
        });
      } catch (e) {
        setState(() {
          _status = '❌ Simulation Error: $e';
        });
      }
    } else {
      // Reset after 3 seconds if not completed
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _testPressCount < 3) {
          setState(() {
            _testPressCount = 0;
            _status = '✅ Ready - Triple press power button for emergency';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            Row(
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: _isListening ? Colors.green : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Power Button Emergency Test',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // الحالة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor().withOpacity(0.3)),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // أزرار الاختبار
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _simulateTriplePress,
                    icon: const Icon(Icons.touch_app),
                    label: Text('Simulate Press ($_testPressCount/3)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _testPressCount = 0;
                        _status =
                            '✅ Ready - Triple press power button for emergency';
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // تعليمات
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
                    'Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Physical Test: Press power button 3 times quickly\n'
                    '• Simulation: Use "Simulate Press" button 3 times\n'
                    '• Timing: You have 5 seconds between presses\n'
                    '• Emergency contacts must be configured for SOS to work',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // معلومات إضافية
            if (_isListening)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Power button detection is active and ready',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  Color _getStatusColor() {
    if (_status.contains('✅')) return Colors.green;
    if (_status.contains('❌')) return Colors.red;
    if (_status.contains('🚨')) return Colors.orange;
    return Colors.blue;
  }
}
