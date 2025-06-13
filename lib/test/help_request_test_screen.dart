import 'package:flutter/material.dart';
import 'comprehensive_help_request_test.dart';
import 'token_management_diagnostic.dart';
import 'help_request_delivery_test.dart';

/// Test screen for help request functionality
class HelpRequestTestScreen extends StatefulWidget {
  const HelpRequestTestScreen({super.key});

  @override
  State<HelpRequestTestScreen> createState() => _HelpRequestTestScreenState();
}

class _HelpRequestTestScreenState extends State<HelpRequestTestScreen> {
  bool _isRunningTest = false;
  String _testResults = '';
  Map<String, dynamic>? _lastTestResults;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار نظام طلبات المساعدة'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حالة النظام',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(_getSystemStatus()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Test Buttons
            const Text(
              'اختبارات النظام:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: _isRunningTest ? null : _runQuickHealthCheck,
                  child: const Text('فحص سريع'),
                ),
                ElevatedButton(
                  onPressed: _isRunningTest ? null : _runTokenDiagnostic,
                  child: const Text('تشخيص الرموز'),
                ),
                ElevatedButton(
                  onPressed: _isRunningTest ? null : _runDeliveryTest,
                  child: const Text('اختبار التسليم'),
                ),
                ElevatedButton(
                  onPressed: _isRunningTest ? null : _runComprehensiveTest,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('اختبار شامل'),
                ),
                ElevatedButton(
                  onPressed: _isRunningTest ? null : _autoFixIssues,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('إصلاح تلقائي'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Results Section
            const Text(
              'نتائج الاختبار:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults.isEmpty ? 'لم يتم تشغيل أي اختبار بعد' : _testResults,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearResults,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('مسح النتائج'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _lastTestResults != null ? _showDetailedResults : null,
                    child: const Text('تفاصيل النتائج'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSystemStatus() {
    if (_lastTestResults == null) {
      return 'لم يتم فحص النظام بعد';
    }

    final analysis = _lastTestResults!['analysis'] as Map<String, dynamic>?;
    final overallHealth = analysis?['overallHealth'] as Map<String, dynamic>?;
    
    if (overallHealth != null) {
      final score = overallHealth['score'] as double? ?? 0.0;
      final status = overallHealth['status'] as String? ?? 'Unknown';
      final ready = overallHealth['readyForProduction'] as bool? ?? false;
      
      return 'النقاط: ${(score * 100).toInt()}% | الحالة: $status | جاهز للإنتاج: ${ready ? 'نعم' : 'لا'}';
    }
    
    return 'بيانات الحالة غير متوفرة';
  }

  Future<void> _runQuickHealthCheck() async {
    setState(() {
      _isRunningTest = true;
      _testResults = 'جاري تشغيل الفحص السريع...\n';
    });

    try {
      final isHealthy = await ComprehensiveHelpRequestTest.runQuickHealthCheck();
      
      setState(() {
        _testResults += '\n✅ الفحص السريع مكتمل\n';
        _testResults += 'النتيجة: ${isHealthy ? 'النظام سليم' : 'توجد مشاكل'}\n';
        _isRunningTest = false;
      });
    } catch (e) {
      setState(() {
        _testResults += '\n❌ فشل الفحص السريع: $e\n';
        _isRunningTest = false;
      });
    }
  }

  Future<void> _runTokenDiagnostic() async {
    setState(() {
      _isRunningTest = true;
      _testResults = 'جاري تشغيل تشخيص الرموز...\n';
    });

    try {
      final results = await TokenManagementDiagnostic.runCompleteDiagnostic();
      
      setState(() {
        _testResults += '\n✅ تشخيص الرموز مكتمل\n';
        _testResults += _formatTokenResults(results);
        _isRunningTest = false;
      });
    } catch (e) {
      setState(() {
        _testResults += '\n❌ فشل تشخيص الرموز: $e\n';
        _isRunningTest = false;
      });
    }
  }

  Future<void> _runDeliveryTest() async {
    setState(() {
      _isRunningTest = true;
      _testResults = 'جاري تشغيل اختبار التسليم...\n';
    });

    try {
      final results = await HelpRequestDeliveryTest.runCompleteDeliveryTest();
      
      setState(() {
        _testResults += '\n✅ اختبار التسليم مكتمل\n';
        _testResults += _formatDeliveryResults(results);
        _isRunningTest = false;
      });
    } catch (e) {
      setState(() {
        _testResults += '\n❌ فشل اختبار التسليم: $e\n';
        _isRunningTest = false;
      });
    }
  }

  Future<void> _runComprehensiveTest() async {
    setState(() {
      _isRunningTest = true;
      _testResults = 'جاري تشغيل الاختبار الشامل...\n';
    });

    try {
      final results = await ComprehensiveHelpRequestTest.runAllTests();
      _lastTestResults = results;
      
      setState(() {
        _testResults += '\n✅ الاختبار الشامل مكتمل\n';
        _testResults += _formatComprehensiveResults(results);
        _isRunningTest = false;
      });
    } catch (e) {
      setState(() {
        _testResults += '\n❌ فشل الاختبار الشامل: $e\n';
        _isRunningTest = false;
      });
    }
  }

  Future<void> _autoFixIssues() async {
    setState(() {
      _isRunningTest = true;
      _testResults = 'جاري الإصلاح التلقائي...\n';
    });

    try {
      final fixes = await ComprehensiveHelpRequestTest.autoFixCommonIssues();
      
      setState(() {
        _testResults += '\n✅ الإصلاح التلقائي مكتمل\n';
        _testResults += _formatFixResults(fixes);
        _isRunningTest = false;
      });
    } catch (e) {
      setState(() {
        _testResults += '\n❌ فشل الإصلاح التلقائي: $e\n';
        _isRunningTest = false;
      });
    }
  }

  String _formatTokenResults(Map<String, dynamic> results) {
    final auth = results['authentication'] as Map<String, dynamic>?;
    final fcm = results['fcm'] as Map<String, dynamic>?;
    final health = results['health'] as Map<String, dynamic>?;
    
    String output = '';
    output += 'المصادقة:\n';
    output += '  - مسجل الدخول: ${auth?['isLoggedIn'] ?? 'غير معروف'}\n';
    output += '  - مستخدم Google: ${auth?['isGoogleUser'] ?? 'غير معروف'}\n';
    output += '  - يملك رمز مصادقة: ${auth?['hasAuthToken'] ?? 'غير معروف'}\n';
    
    output += '\nرموز FCM:\n';
    output += '  - يملك رمز FCM: ${fcm?['hasFCMToken'] ?? 'غير معروف'}\n';
    output += '  - محفوظ للمستخدم: ${fcm?['hasTokenForCurrentUser'] ?? 'غير معروف'}\n';
    
    output += '\nالصحة العامة:\n';
    output += '  - النقاط: ${health?['healthScore'] ?? 'غير معروف'}\n';
    output += '  - سليم: ${health?['overallHealthy'] ?? 'غير معروف'}\n';
    
    return output;
  }

  String _formatDeliveryResults(Map<String, dynamic> results) {
    final infrastructure = results['infrastructure'] as Map<String, dynamic>?;
    final delivery = results['delivery'] as Map<String, dynamic>?;
    final monitoring = results['monitoring'] as Map<String, dynamic>?;
    
    String output = '';
    output += 'البنية التحتية:\n';
    output += '  - خدمة FCM: ${infrastructure?['fcmServiceWorking'] ?? 'غير معروف'}\n';
    output += '  - قاعدة البيانات: ${infrastructure?['firebaseDatabaseWorking'] ?? 'غير معروف'}\n';
    
    output += '\nالتسليم:\n';
    output += '  - إعداد البيانات: ${delivery?['testDataPrepared'] ?? 'غير معروف'}\n';
    output += '  - إنشاء الإشعار: ${delivery?['notificationDataCreated'] ?? 'غير معروف'}\n';
    
    output += '\nالمراقبة:\n';
    output += '  - نشطة: ${monitoring?['monitoringActive'] ?? 'غير معروف'}\n';
    
    return output;
  }

  String _formatComprehensiveResults(Map<String, dynamic> results) {
    final analysis = results['analysis'] as Map<String, dynamic>?;
    final overallHealth = analysis?['overallHealth'] as Map<String, dynamic>?;
    final criticalIssues = analysis?['criticalIssues'] as List<String>? ?? [];
    
    String output = '';
    output += 'الصحة العامة:\n';
    output += '  - النقاط: ${((overallHealth?['score'] as double? ?? 0.0) * 100).toInt()}%\n';
    output += '  - الحالة: ${overallHealth?['status'] ?? 'غير معروف'}\n';
    output += '  - جاهز للإنتاج: ${overallHealth?['readyForProduction'] ?? false ? 'نعم' : 'لا'}\n';
    
    if (criticalIssues.isNotEmpty) {
      output += '\nالمشاكل الحرجة:\n';
      for (final issue in criticalIssues) {
        output += '  - $issue\n';
      }
    }
    
    return output;
  }

  String _formatFixResults(Map<String, bool> fixes) {
    String output = '';
    fixes.forEach((key, value) {
      output += '$key: ${value ? 'نجح' : 'فشل'}\n';
    });
    return output;
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
      _lastTestResults = null;
    });
  }

  void _showDetailedResults() {
    if (_lastTestResults == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل النتائج'),
        content: SingleChildScrollView(
          child: Text(
            _lastTestResults.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
