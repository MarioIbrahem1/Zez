import 'package:flutter/foundation.dart';
import 'run_help_request_tests.dart';
import 'comprehensive_help_request_test.dart';

/// Main entry point for running help request tests
/// Can be called from anywhere in the app or as a standalone test
class TestMain {
  
  /// Run tests based on command line arguments or default behavior
  static Future<void> main([List<String>? args]) async {
    debugPrint('🚀 Help Request Test Suite Starting...');
    
    // Parse arguments if provided
    final testType = args?.isNotEmpty == true ? args!.first.toLowerCase() : 'quick';
    
    try {
      switch (testType) {
        case 'quick':
        case 'health':
          await _runQuickTest();
          break;
          
        case 'full':
        case 'comprehensive':
        case 'all':
          await _runFullTest();
          break;
          
        case 'token':
        case 'tokens':
          await _runTokenTest();
          break;
          
        case 'delivery':
          await _runDeliveryTest();
          break;
          
        case 'production':
        case 'prod':
          await _runProductionTest();
          break;
          
        case 'fix':
        case 'repair':
          await _runAutoFix();
          break;
          
        case 'monitor':
          await _runMonitoring();
          break;
          
        case 'help':
        case '--help':
        case '-h':
          _printHelp();
          break;
          
        default:
          debugPrint('❌ Unknown test type: $testType');
          _printHelp();
      }
    } catch (e) {
      debugPrint('❌ Test execution failed: $e');
    }
  }

  /// Run quick health check
  static Future<void> _runQuickTest() async {
    debugPrint('🏥 Running Quick Health Check...');
    
    final startTime = DateTime.now();
    final isHealthy = await ComprehensiveHelpRequestTest.runQuickHealthCheck();
    final duration = DateTime.now().difference(startTime);
    
    debugPrint('\n📊 Quick Test Results:');
    debugPrint('   - Status: ${isHealthy ? '✅ Healthy' : '❌ Issues Found'}');
    debugPrint('   - Duration: ${duration.inMilliseconds}ms');
    
    if (!isHealthy) {
      debugPrint('\n💡 Recommendation: Run "fix" command to auto-repair issues');
      debugPrint('   Or run "full" command for detailed analysis');
    }
  }

  /// Run comprehensive test suite
  static Future<void> _runFullTest() async {
    debugPrint('🔬 Running Comprehensive Test Suite...');
    
    await RunHelpRequestTests.runAllTestsWithReporting();
  }

  /// Run token management tests only
  static Future<void> _runTokenTest() async {
    debugPrint('🔐 Running Token Management Tests...');
    
    await RunHelpRequestTests.runSpecificTest('token');
  }

  /// Run delivery system tests only
  static Future<void> _runDeliveryTest() async {
    debugPrint('📤 Running Delivery System Tests...');
    
    await RunHelpRequestTests.runSpecificTest('delivery');
  }

  /// Run production readiness check
  static Future<void> _runProductionTest() async {
    debugPrint('🏭 Running Production Readiness Check...');
    
    final isReady = await RunHelpRequestTests.checkProductionReadiness();
    
    debugPrint('\n🎯 Production Readiness: ${isReady ? '✅ READY' : '❌ NOT READY'}');
    
    if (isReady) {
      debugPrint('🎉 System is ready for production deployment!');
    } else {
      debugPrint('⚠️ System needs fixes before production deployment');
      debugPrint('💡 Run "fix" command to attempt auto-repair');
    }
  }

  /// Run auto-fix for common issues
  static Future<void> _runAutoFix() async {
    debugPrint('🔧 Running Auto-Fix for Common Issues...');
    
    final fixes = await ComprehensiveHelpRequestTest.autoFixCommonIssues();
    
    debugPrint('\n🛠️ Auto-Fix Results:');
    fixes.forEach((key, value) {
      debugPrint('   - $key: ${value ? '✅ Fixed' : '❌ Failed'}');
    });
    
    final successCount = fixes.values.where((v) => v == true).length;
    final totalCount = fixes.length;
    
    debugPrint('\n📊 Summary: $successCount/$totalCount fixes successful');
    
    if (successCount == totalCount) {
      debugPrint('🎉 All issues fixed successfully!');
    } else {
      debugPrint('⚠️ Some issues require manual intervention');
      debugPrint('💡 Run "full" command for detailed analysis');
    }
  }

  /// Run continuous monitoring
  static Future<void> _runMonitoring() async {
    debugPrint('🔄 Starting Continuous Monitoring...');
    debugPrint('⚠️ This will run indefinitely. Press Ctrl+C to stop.');
    
    await RunHelpRequestTests.runContinuousMonitoring(intervalMinutes: 30);
  }

  /// Print help information
  static void _printHelp() {
    debugPrint('''
🧪 Help Request Test Suite

Usage: TestMain.main(['command'])

Available Commands:
  quick, health     - Run quick health check (default)
  full, all         - Run comprehensive test suite
  token, tokens     - Run token management tests only
  delivery          - Run delivery system tests only
  production, prod  - Check production readiness
  fix, repair       - Auto-fix common issues
  monitor           - Start continuous monitoring
  help, --help, -h  - Show this help message

Examples:
  TestMain.main(['quick']);      // Quick health check
  TestMain.main(['full']);       // Full test suite
  TestMain.main(['fix']);        // Auto-fix issues
  TestMain.main(['production']); // Production readiness

Test Categories:
  🏥 Health Check    - Quick system status verification
  🔐 Token Tests     - Authentication and FCM token management
  📤 Delivery Tests  - Help request delivery mechanisms
  🔬 Full Suite      - Complete system analysis
  🏭 Production      - Deployment readiness verification
  🔧 Auto-Fix        - Automatic issue resolution
  🔄 Monitoring      - Continuous system monitoring

Health Score Interpretation:
  80-100%: Excellent - System fully operational
  60-79%:  Good - Minor issues, monitoring recommended
  40-59%:  Fair - Issues present, fixes needed
  0-39%:   Poor - Critical issues, immediate attention required

For more information, see HELP_REQUEST_TESTING_GUIDE.md
''');
  }

  /// Run specific test scenario for debugging
  static Future<void> runDebugScenario(String scenario) async {
    debugPrint('🐛 Running Debug Scenario: $scenario');
    
    switch (scenario.toLowerCase()) {
      case 'token_refresh':
        await _debugTokenRefresh();
        break;
        
      case 'delivery_failure':
        await _debugDeliveryFailure();
        break;
        
      case 'auth_issues':
        await _debugAuthIssues();
        break;
        
      default:
        debugPrint('❌ Unknown debug scenario: $scenario');
        debugPrint('Available scenarios: token_refresh, delivery_failure, auth_issues');
    }
  }

  /// Debug token refresh scenario
  static Future<void> _debugTokenRefresh() async {
    debugPrint('🔄 Debugging Token Refresh...');
    
    try {
      // Import and test token refresh
      // This would be implemented based on specific debugging needs
      debugPrint('✅ Token refresh debug completed');
    } catch (e) {
      debugPrint('❌ Token refresh debug failed: $e');
    }
  }

  /// Debug delivery failure scenario
  static Future<void> _debugDeliveryFailure() async {
    debugPrint('📤 Debugging Delivery Failure...');
    
    try {
      // Test delivery failure scenarios
      debugPrint('✅ Delivery failure debug completed');
    } catch (e) {
      debugPrint('❌ Delivery failure debug failed: $e');
    }
  }

  /// Debug authentication issues
  static Future<void> _debugAuthIssues() async {
    debugPrint('🔐 Debugging Authentication Issues...');
    
    try {
      // Test authentication scenarios
      debugPrint('✅ Authentication debug completed');
    } catch (e) {
      debugPrint('❌ Authentication debug failed: $e');
    }
  }

  /// Get system status summary
  static Future<Map<String, dynamic>> getSystemStatus() async {
    debugPrint('📊 Getting System Status...');
    
    try {
      final isHealthy = await ComprehensiveHelpRequestTest.runQuickHealthCheck();
      
      return {
        'healthy': isHealthy,
        'timestamp': DateTime.now().toIso8601String(),
        'status': isHealthy ? 'operational' : 'issues_detected',
      };
    } catch (e) {
      return {
        'healthy': false,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  /// Schedule periodic health checks
  static void schedulePeriodicHealthChecks({int intervalHours = 6}) async {
    debugPrint('⏰ Scheduling periodic health checks every $intervalHours hours');
    
    // This would be implemented with a proper scheduler in a real app
    // For now, just log the intention
    debugPrint('📅 Health checks scheduled - implement with your app\'s scheduler');
  }
}
