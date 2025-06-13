import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'help_request_system_test.dart';
import 'token_management_diagnostic.dart';
import 'help_request_delivery_test.dart';
import 'persistent_login_test.dart';

/// Comprehensive test runner for help request functionality
class ComprehensiveHelpRequestTest {
  /// Run all tests and diagnostics
  static Future<Map<String, dynamic>> runAllTests() async {
    debugPrint('🧪 ===== بدء الاختبار الشامل لنظام طلبات المساعدة =====');

    final results = <String, dynamic>{};
    final startTime = DateTime.now();

    try {
      // 1. Token Management Diagnostic
      debugPrint('\n🔍 === Token Management Diagnostic ===');
      final tokenResults =
          await TokenManagementDiagnostic.runCompleteDiagnostic();
      results['tokenManagement'] = tokenResults;

      // 2. Help Request System Tests
      debugPrint('\n🧪 === Help Request System Tests ===');
      await HelpRequestSystemTest.runAllTests();
      results['systemTests'] = {'completed': true};

      // 3. Help Request Delivery Tests
      debugPrint('\n📤 === Help Request Delivery Tests ===');
      final deliveryResults =
          await HelpRequestDeliveryTest.runCompleteDeliveryTest();
      results['deliveryTests'] = deliveryResults;

      // 4. Persistent Login Tests
      debugPrint('\n🔐 === Persistent Login Tests ===');
      await PersistentLoginTest.runAllTests();
      results['persistentLoginTests'] = {'completed': true};

      // 5. Generate comprehensive report
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      results['testMetadata'] = {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'duration': duration.inMilliseconds,
        'testsCompleted': true,
      };

      // 6. Analyze results and provide recommendations
      final analysis = _analyzeResults(results);
      results['analysis'] = analysis;

      debugPrint('✅ ===== الاختبار الشامل مكتمل =====');
      _printComprehensiveReport(results);

      return results;
    } catch (e) {
      debugPrint('❌ ===== فشل الاختبار الشامل: $e =====');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Analyze test results and provide recommendations
  static Map<String, dynamic> _analyzeResults(Map<String, dynamic> results) {
    final analysis = <String, dynamic>{};

    try {
      // Analyze token management
      final tokenMgmt = results['tokenManagement'] as Map<String, dynamic>?;
      if (tokenMgmt != null) {
        final health = tokenMgmt['health'] as Map<String, dynamic>?;
        final healthScore = health?['healthScore'] as double? ?? 0.0;

        analysis['tokenManagementHealth'] = {
          'score': healthScore,
          'status': healthScore >= 0.8
              ? 'excellent'
              : healthScore >= 0.6
                  ? 'good'
                  : healthScore >= 0.4
                      ? 'fair'
                      : 'poor',
          'recommendations': _getTokenRecommendations(healthScore, tokenMgmt),
        };
      }

      // Analyze delivery system
      final delivery = results['deliveryTests'] as Map<String, dynamic>?;
      if (delivery != null) {
        final infrastructure =
            delivery['infrastructure'] as Map<String, dynamic>?;
        final deliveryTest = delivery['delivery'] as Map<String, dynamic>?;

        final infraScore = _calculateInfrastructureScore(infrastructure);
        final deliveryScore = _calculateDeliveryScore(deliveryTest);

        analysis['deliverySystemHealth'] = {
          'infrastructureScore': infraScore,
          'deliveryScore': deliveryScore,
          'overallScore': (infraScore + deliveryScore) / 2,
          'recommendations':
              _getDeliveryRecommendations(infraScore, deliveryScore, delivery),
        };
      }

      // Overall system health
      final tokenScore =
          analysis['tokenManagementHealth']?['score'] as double? ?? 0.0;
      final deliveryScore =
          analysis['deliverySystemHealth']?['overallScore'] as double? ?? 0.0;
      final overallScore = (tokenScore + deliveryScore) / 2;

      analysis['overallHealth'] = {
        'score': overallScore,
        'status': overallScore >= 0.8
            ? 'excellent'
            : overallScore >= 0.6
                ? 'good'
                : overallScore >= 0.4
                    ? 'fair'
                    : 'poor',
        'readyForProduction': overallScore >= 0.7,
      };

      // Critical issues
      final criticalIssues = _identifyCriticalIssues(results);
      analysis['criticalIssues'] = criticalIssues;

      // Action items
      final actionItems = _generateActionItems(results, analysis);
      analysis['actionItems'] = actionItems;
    } catch (e) {
      analysis['error'] = 'Analysis failed: $e';
    }

    return analysis;
  }

  /// Calculate infrastructure score
  static double _calculateInfrastructureScore(
      Map<String, dynamic>? infrastructure) {
    if (infrastructure == null) return 0.0;

    double score = 0.0;
    int checks = 0;

    if (infrastructure['fcmServiceWorking'] == true) {
      score += 1;
      checks++;
    }
    if (infrastructure['currentUserHasToken'] == true) {
      score += 1;
      checks++;
    }
    if (infrastructure['firebaseDatabaseWorking'] == true) {
      score += 1;
      checks++;
    }
    if (infrastructure['tokenValid'] == true) {
      score += 1;
      checks++;
    }

    return checks > 0 ? score / checks : 0.0;
  }

  /// Calculate delivery score
  static double _calculateDeliveryScore(Map<String, dynamic>? delivery) {
    if (delivery == null) return 0.0;

    double score = 0.0;
    int checks = 0;

    if (delivery['testDataPrepared'] == true) {
      score += 1;
      checks++;
    }
    if (delivery['notificationDataCreated'] == true) {
      score += 1;
      checks++;
    }
    if (delivery['firebaseSaveSuccess'] == true) {
      score += 1;
      checks++;
    }

    return checks > 0 ? score / checks : 0.0;
  }

  /// Get token management recommendations
  static List<String> _getTokenRecommendations(
      double score, Map<String, dynamic> tokenData) {
    final recommendations = <String>[];

    if (score < 0.8) {
      final auth = tokenData['authentication'] as Map<String, dynamic>?;
      final fcm = tokenData['fcm'] as Map<String, dynamic>?;

      if (auth?['isLoggedIn'] != true) {
        recommendations.add('User needs to log in to enable help requests');
      }

      if (auth?['isGoogleUser'] != true) {
        recommendations.add(
            'User needs to sign in with Google for help request functionality');
      }

      if (fcm?['hasFCMToken'] != true) {
        recommendations.add('FCM token needs to be generated and saved');
      }

      if (fcm?['hasTokenForCurrentUser'] != true) {
        recommendations.add('FCM token needs to be saved for current user');
      }
    }

    return recommendations;
  }

  /// Get delivery system recommendations
  static List<String> _getDeliveryRecommendations(double infraScore,
      double deliveryScore, Map<String, dynamic> deliveryData) {
    final recommendations = <String>[];

    if (infraScore < 0.8) {
      recommendations.add(
          'Infrastructure needs improvement - check FCM service and Firebase connectivity');
    }

    if (deliveryScore < 0.8) {
      recommendations.add(
          'Delivery mechanism needs optimization - verify notification creation and saving');
    }

    final monitoring = deliveryData['monitoring'] as Map<String, dynamic>?;
    if (monitoring?['monitoringActive'] != true) {
      recommendations.add('Enable delivery monitoring for better reliability');
    }

    final fallback = deliveryData['fallback'] as Map<String, dynamic>?;
    if (fallback?['fallbackSaveSuccess'] != true) {
      recommendations.add('Verify fallback mechanisms are working properly');
    }

    return recommendations;
  }

  /// Identify critical issues
  static List<String> _identifyCriticalIssues(Map<String, dynamic> results) {
    final issues = <String>[];

    try {
      final tokenMgmt = results['tokenManagement'] as Map<String, dynamic>?;
      final auth = tokenMgmt?['authentication'] as Map<String, dynamic>?;

      if (auth?['isLoggedIn'] != true) {
        issues.add('CRITICAL: User not logged in - help requests unavailable');
      }

      if (auth?['isGoogleUser'] != true) {
        issues.add('CRITICAL: Not a Google user - help requests restricted');
      }

      final delivery = results['deliveryTests'] as Map<String, dynamic>?;
      final infrastructure =
          delivery?['infrastructure'] as Map<String, dynamic>?;

      if (infrastructure?['firebaseDatabaseWorking'] != true) {
        issues.add('CRITICAL: Firebase Database connectivity issues');
      }

      final fcm = tokenMgmt?['fcm'] as Map<String, dynamic>?;
      if (fcm?['hasFCMToken'] != true) {
        issues.add(
            'WARNING: No FCM token - notifications will use fallback only');
      }
    } catch (e) {
      issues.add('ERROR: Failed to analyze critical issues - $e');
    }

    return issues;
  }

  /// Generate action items
  static List<Map<String, dynamic>> _generateActionItems(
      Map<String, dynamic> results, Map<String, dynamic> analysis) {
    final actionItems = <Map<String, dynamic>>[];

    try {
      final criticalIssues = analysis['criticalIssues'] as List<String>? ?? [];
      final overallHealth = analysis['overallHealth'] as Map<String, dynamic>?;

      // High priority actions
      for (final issue in criticalIssues) {
        if (issue.startsWith('CRITICAL:')) {
          actionItems.add({
            'priority': 'HIGH',
            'action': issue.replaceFirst('CRITICAL: ', ''),
            'category': 'Authentication',
          });
        }
      }

      // Medium priority actions
      if (overallHealth?['score'] != null && overallHealth!['score'] < 0.7) {
        actionItems.add({
          'priority': 'MEDIUM',
          'action': 'Improve overall system health score',
          'category': 'System Health',
        });
      }

      // Low priority actions
      final tokenRecommendations = analysis['tokenManagementHealth']
              ?['recommendations'] as List<String>? ??
          [];
      for (final recommendation in tokenRecommendations) {
        actionItems.add({
          'priority': 'LOW',
          'action': recommendation,
          'category': 'Token Management',
        });
      }
    } catch (e) {
      actionItems.add({
        'priority': 'HIGH',
        'action': 'Fix action item generation error: $e',
        'category': 'System Error',
      });
    }

    return actionItems;
  }

  /// Print comprehensive report
  static void _printComprehensiveReport(Map<String, dynamic> results) {
    debugPrint('\n📋 ===== تقرير شامل لنظام طلبات المساعدة =====');

    try {
      final analysis = results['analysis'] as Map<String, dynamic>?;
      final metadata = results['testMetadata'] as Map<String, dynamic>?;

      // Test execution info
      debugPrint('⏱️ Test Execution:');
      debugPrint('   - Duration: ${metadata?['duration'] ?? 'Unknown'}ms');
      debugPrint('   - Completed: ${metadata?['testsCompleted'] ?? false}');

      // Overall health
      final overallHealth = analysis?['overallHealth'] as Map<String, dynamic>?;
      debugPrint('\n💚 Overall Health:');
      debugPrint('   - Score: ${overallHealth?['score'] ?? 'Unknown'}');
      debugPrint('   - Status: ${overallHealth?['status'] ?? 'Unknown'}');
      debugPrint(
          '   - Production Ready: ${overallHealth?['readyForProduction'] ?? false}');

      // Token management
      final tokenHealth =
          analysis?['tokenManagementHealth'] as Map<String, dynamic>?;
      debugPrint('\n🔐 Token Management:');
      debugPrint('   - Score: ${tokenHealth?['score'] ?? 'Unknown'}');
      debugPrint('   - Status: ${tokenHealth?['status'] ?? 'Unknown'}');

      // Delivery system
      final deliveryHealth =
          analysis?['deliverySystemHealth'] as Map<String, dynamic>?;
      debugPrint('\n📤 Delivery System:');
      debugPrint(
          '   - Infrastructure Score: ${deliveryHealth?['infrastructureScore'] ?? 'Unknown'}');
      debugPrint(
          '   - Delivery Score: ${deliveryHealth?['deliveryScore'] ?? 'Unknown'}');
      debugPrint(
          '   - Overall Score: ${deliveryHealth?['overallScore'] ?? 'Unknown'}');

      // Critical issues
      final criticalIssues = analysis?['criticalIssues'] as List<String>? ?? [];
      if (criticalIssues.isNotEmpty) {
        debugPrint('\n🚨 Critical Issues:');
        for (final issue in criticalIssues) {
          debugPrint('   - $issue');
        }
      }

      // Action items
      final actionItems =
          analysis?['actionItems'] as List<Map<String, dynamic>>? ?? [];
      if (actionItems.isNotEmpty) {
        debugPrint('\n📝 Action Items:');
        for (final item in actionItems) {
          debugPrint(
              '   - [${item['priority']}] ${item['action']} (${item['category']})');
        }
      }
    } catch (e) {
      debugPrint('❌ Error printing comprehensive report: $e');
    }

    debugPrint('\n================================');
  }

  /// Run quick health check
  static Future<bool> runQuickHealthCheck() async {
    debugPrint('🚀 ===== فحص سريع للصحة العامة =====');

    try {
      // Quick token diagnostic
      final tokenResults =
          await TokenManagementDiagnostic.runCompleteDiagnostic();
      final tokenHealth = tokenResults['health'] as Map<String, dynamic>?;
      final tokenScore = tokenHealth?['healthScore'] as double? ?? 0.0;

      // Quick delivery check
      final deliveryOk = await HelpRequestDeliveryTest.runQuickDeliveryCheck();

      // Overall assessment
      final overallHealthy = tokenScore >= 0.7 && deliveryOk;

      debugPrint('📊 Quick Health Results:');
      debugPrint('   - Token Health Score: $tokenScore');
      debugPrint('   - Delivery System: ${deliveryOk ? 'OK' : 'Issues'}');
      debugPrint('   - Overall Healthy: $overallHealthy');

      if (!overallHealthy) {
        debugPrint('\n⚠️ Issues detected - run full diagnostic for details');
      }

      return overallHealthy;
    } catch (e) {
      debugPrint('❌ Quick health check failed: $e');
      return false;
    }
  }

  /// Fix common issues automatically
  static Future<Map<String, bool>> autoFixCommonIssues() async {
    debugPrint('🔧 ===== إصلاح تلقائي للمشاكل الشائعة =====');

    final fixes = <String, bool>{};

    try {
      // Run token management fixes
      final tokenFixes = await TokenManagementDiagnostic.fixCommonIssues();
      fixes.addAll(tokenFixes);

      // Additional fixes can be added here

      debugPrint('✅ Auto-fix completed');
      debugPrint('📊 Fix Results: $fixes');
    } catch (e) {
      debugPrint('❌ Auto-fix failed: $e');
      fixes['autoFixError'] = false;
    }

    return fixes;
  }
}
