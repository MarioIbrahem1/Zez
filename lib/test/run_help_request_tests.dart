import 'package:flutter/foundation.dart';
import 'comprehensive_help_request_test.dart';
import 'token_management_diagnostic.dart';
import 'help_request_delivery_test.dart';
import 'help_request_system_test.dart';

/// Main test runner for help request functionality
class RunHelpRequestTests {
  
  /// Run all tests with detailed reporting
  static Future<void> runAllTestsWithReporting() async {
    debugPrint('🚀 ===== بدء تشغيل جميع اختبارات نظام طلبات المساعدة =====');
    debugPrint('📅 وقت البدء: ${DateTime.now().toIso8601String()}');
    
    final startTime = DateTime.now();
    final results = <String, dynamic>{};
    
    try {
      // 1. Quick Health Check
      debugPrint('\n🏥 === فحص سريع للصحة العامة ===');
      final quickHealthy = await ComprehensiveHelpRequestTest.runQuickHealthCheck();
      results['quickHealth'] = quickHealthy;
      
      if (!quickHealthy) {
        debugPrint('⚠️ فحص الصحة السريع أظهر مشاكل - سيتم تشغيل التشخيص الكامل');
      }
      
      // 2. Token Management Diagnostic
      debugPrint('\n🔐 === تشخيص إدارة الرموز ===');
      final tokenResults = await TokenManagementDiagnostic.runCompleteDiagnostic();
      results['tokenDiagnostic'] = tokenResults;
      
      // 3. Help Request System Tests
      debugPrint('\n🧪 === اختبارات نظام طلبات المساعدة ===');
      await HelpRequestSystemTest.runAllTests();
      results['systemTests'] = {'completed': true};
      
      // 4. Delivery Tests
      debugPrint('\n📤 === اختبارات التسليم ===');
      final deliveryResults = await HelpRequestDeliveryTest.runCompleteDeliveryTest();
      results['deliveryTests'] = deliveryResults;
      
      // 5. Comprehensive Analysis
      debugPrint('\n📊 === التحليل الشامل ===');
      final comprehensiveResults = await ComprehensiveHelpRequestTest.runAllTests();
      results['comprehensiveAnalysis'] = comprehensiveResults;
      
      // 6. Auto-fix if needed
      final overallHealth = comprehensiveResults['analysis']?['overallHealth'] as Map<String, dynamic>?;
      final healthScore = overallHealth?['score'] as double? ?? 0.0;
      
      if (healthScore < 0.7) {
        debugPrint('\n🔧 === إصلاح تلقائي للمشاكل ===');
        final fixes = await ComprehensiveHelpRequestTest.autoFixCommonIssues();
        results['autoFixes'] = fixes;
        
        // Re-run quick health check after fixes
        debugPrint('\n🔄 === إعادة فحص الصحة بعد الإصلاح ===');
        final healthAfterFix = await ComprehensiveHelpRequestTest.runQuickHealthCheck();
        results['healthAfterFix'] = healthAfterFix;
      }
      
      // 7. Final Report
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      results['testMetadata'] = {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'durationMinutes': duration.inMinutes,
      };
      
      debugPrint('\n📋 ===== تقرير نهائي =====');
      _printFinalReport(results);
      
      debugPrint('\n✅ ===== اكتملت جميع الاختبارات بنجاح =====');
      debugPrint('⏱️ المدة الإجمالية: ${duration.inMinutes} دقيقة و ${duration.inSeconds % 60} ثانية');
      
    } catch (e) {
      debugPrint('\n❌ ===== فشل في تشغيل الاختبارات =====');
      debugPrint('خطأ: $e');
      results['error'] = e.toString();
    }
  }

  /// Run specific test category
  static Future<void> runSpecificTest(String testType) async {
    debugPrint('🎯 ===== تشغيل اختبار محدد: $testType =====');
    
    try {
      switch (testType.toLowerCase()) {
        case 'token':
        case 'tokens':
          await TokenManagementDiagnostic.runCompleteDiagnostic();
          break;
          
        case 'delivery':
          await HelpRequestDeliveryTest.runCompleteDeliveryTest();
          break;
          
        case 'system':
          await HelpRequestSystemTest.runAllTests();
          break;
          
        case 'comprehensive':
        case 'full':
          await ComprehensiveHelpRequestTest.runAllTests();
          break;
          
        case 'quick':
        case 'health':
          await ComprehensiveHelpRequestTest.runQuickHealthCheck();
          break;
          
        case 'fix':
        case 'repair':
          await ComprehensiveHelpRequestTest.autoFixCommonIssues();
          break;
          
        default:
          debugPrint('❌ نوع اختبار غير معروف: $testType');
          debugPrint('الأنواع المتاحة: token, delivery, system, comprehensive, quick, fix');
          return;
      }
      
      debugPrint('✅ اكتمل الاختبار المحدد: $testType');
    } catch (e) {
      debugPrint('❌ فشل الاختبار المحدد: $e');
    }
  }

  /// Run tests for production readiness
  static Future<bool> checkProductionReadiness() async {
    debugPrint('🏭 ===== فحص الجاهزية للإنتاج =====');
    
    try {
      // Run comprehensive test
      final results = await ComprehensiveHelpRequestTest.runAllTests();
      
      // Check overall health
      final analysis = results['analysis'] as Map<String, dynamic>?;
      final overallHealth = analysis?['overallHealth'] as Map<String, dynamic>?;
      final isReady = overallHealth?['readyForProduction'] as bool? ?? false;
      final score = overallHealth?['score'] as double? ?? 0.0;
      
      debugPrint('📊 نتائج فحص الجاهزية:');
      debugPrint('   - النقاط: ${(score * 100).toInt()}%');
      debugPrint('   - جاهز للإنتاج: ${isReady ? 'نعم' : 'لا'}');
      
      // Check critical issues
      final criticalIssues = analysis?['criticalIssues'] as List<String>? ?? [];
      if (criticalIssues.isNotEmpty) {
        debugPrint('\n🚨 مشاكل حرجة تمنع الإنتاج:');
        for (final issue in criticalIssues) {
          debugPrint('   - $issue');
        }
      }
      
      // Recommendations
      if (!isReady) {
        debugPrint('\n💡 توصيات للوصول للجاهزية:');
        final actionItems = analysis?['actionItems'] as List<Map<String, dynamic>>? ?? [];
        for (final item in actionItems) {
          if (item['priority'] == 'HIGH') {
            debugPrint('   - [عالي] ${item['action']}');
          }
        }
      }
      
      return isReady;
    } catch (e) {
      debugPrint('❌ فشل فحص الجاهزية للإنتاج: $e');
      return false;
    }
  }

  /// Run continuous monitoring test
  static Future<void> runContinuousMonitoring({int intervalMinutes = 30}) async {
    debugPrint('🔄 ===== بدء المراقبة المستمرة =====');
    debugPrint('📅 فترة المراقبة: كل $intervalMinutes دقيقة');
    
    int cycleCount = 0;
    
    while (true) {
      try {
        cycleCount++;
        debugPrint('\n🔍 === دورة مراقبة #$cycleCount ===');
        debugPrint('⏰ الوقت: ${DateTime.now().toIso8601String()}');
        
        // Quick health check
        final isHealthy = await ComprehensiveHelpRequestTest.runQuickHealthCheck();
        
        if (!isHealthy) {
          debugPrint('⚠️ تم اكتشاف مشاكل في الصحة - تشغيل إصلاح تلقائي...');
          await ComprehensiveHelpRequestTest.autoFixCommonIssues();
          
          // Re-check after fix
          final healthAfterFix = await ComprehensiveHelpRequestTest.runQuickHealthCheck();
          debugPrint('🔄 الصحة بعد الإصلاح: ${healthAfterFix ? 'سليم' : 'ما زالت توجد مشاكل'}');
        } else {
          debugPrint('✅ النظام سليم');
        }
        
        // Wait for next cycle
        debugPrint('⏳ انتظار $intervalMinutes دقيقة للدورة التالية...');
        await Future.delayed(Duration(minutes: intervalMinutes));
        
      } catch (e) {
        debugPrint('❌ خطأ في دورة المراقبة #$cycleCount: $e');
        // Continue monitoring despite errors
        await Future.delayed(Duration(minutes: intervalMinutes));
      }
    }
  }

  /// Print final report
  static void _printFinalReport(Map<String, dynamic> results) {
    try {
      final metadata = results['testMetadata'] as Map<String, dynamic>?;
      final quickHealth = results['quickHealth'] as bool?;
      final comprehensiveAnalysis = results['comprehensiveAnalysis'] as Map<String, dynamic>?;
      final analysis = comprehensiveAnalysis?['analysis'] as Map<String, dynamic>?;
      
      debugPrint('📊 ملخص النتائج:');
      debugPrint('   - الفحص السريع: ${quickHealth == true ? 'سليم' : 'مشاكل'}');
      debugPrint('   - مدة التشغيل: ${metadata?['durationMs'] ?? 'غير معروف'}ms');
      
      if (analysis != null) {
        final overallHealth = analysis['overallHealth'] as Map<String, dynamic>?;
        final tokenHealth = analysis['tokenManagementHealth'] as Map<String, dynamic>?;
        final deliveryHealth = analysis['deliverySystemHealth'] as Map<String, dynamic>?;
        
        debugPrint('\n🏥 الصحة العامة:');
        debugPrint('   - النقاط: ${((overallHealth?['score'] as double? ?? 0.0) * 100).toInt()}%');
        debugPrint('   - الحالة: ${overallHealth?['status'] ?? 'غير معروف'}');
        debugPrint('   - جاهز للإنتاج: ${overallHealth?['readyForProduction'] == true ? 'نعم' : 'لا'}');
        
        debugPrint('\n🔐 إدارة الرموز:');
        debugPrint('   - النقاط: ${((tokenHealth?['score'] as double? ?? 0.0) * 100).toInt()}%');
        debugPrint('   - الحالة: ${tokenHealth?['status'] ?? 'غير معروف'}');
        
        debugPrint('\n📤 نظام التسليم:');
        debugPrint('   - النقاط: ${((deliveryHealth?['overallScore'] as double? ?? 0.0) * 100).toInt()}%');
        
        final criticalIssues = analysis['criticalIssues'] as List<String>? ?? [];
        if (criticalIssues.isNotEmpty) {
          debugPrint('\n🚨 مشاكل حرجة (${criticalIssues.length}):');
          for (int i = 0; i < criticalIssues.length && i < 3; i++) {
            debugPrint('   ${i + 1}. ${criticalIssues[i]}');
          }
          if (criticalIssues.length > 3) {
            debugPrint('   ... و ${criticalIssues.length - 3} مشاكل أخرى');
          }
        }
      }
      
      // Auto-fix results
      final autoFixes = results['autoFixes'] as Map<String, bool>?;
      if (autoFixes != null) {
        final successCount = autoFixes.values.where((v) => v == true).length;
        final totalCount = autoFixes.length;
        debugPrint('\n🔧 الإصلاح التلقائي: $successCount/$totalCount نجح');
      }
      
    } catch (e) {
      debugPrint('❌ خطأ في طباعة التقرير النهائي: $e');
    }
  }

  /// Get test recommendations
  static List<String> getTestRecommendations() {
    return [
      'تشغيل الفحص السريع يومياً للتأكد من سلامة النظام',
      'تشغيل التشخيص الشامل أسبوعياً لمراقبة الأداء',
      'استخدام الإصلاح التلقائي عند اكتشاف مشاكل',
      'مراقبة نقاط الصحة والحفاظ عليها فوق 80%',
      'التأكد من صحة رموز FCM بانتظام',
      'فحص آلية التسليم الاحتياطية',
      'مراجعة السجلات للأخطاء المتكررة',
    ];
  }
}
