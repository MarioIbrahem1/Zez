import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_helperr/services/release_mode_user_sync_service.dart';
import 'package:road_helperr/services/firebase_help_request_service.dart';
import 'package:road_helperr/services/firebase_user_location_service.dart';
import 'package:road_helperr/utils/release_mode_diagnostics.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// أداة اختبار شاملة لحلول Release Mode
class ReleaseModeTestHelper {
  /// اختبار شامل لجميع الحلول المطبقة
  static Future<Map<String, dynamic>> runComprehensiveTest() async {
    final results = <String, dynamic>{};

    try {
      if (kReleaseMode) {
        print('🧪 ========== RELEASE MODE COMPREHENSIVE TEST ==========');

        // 1. اختبار التشخيص الأساسي
        results['diagnostics'] = await _testBasicDiagnostics();

        // 2. اختبار مزامنة المستخدمين
        results['user_sync'] = await _testUserSync();

        // 3. اختبار تحديث المواقع
        results['location_update'] = await _testLocationUpdate();

        // 4. اختبار Help Requests
        results['help_requests'] = await _testHelpRequests();

        // 5. اختبار المستخدمين المختلطين
        results['mixed_users'] = await _testMixedUsers();

        // 6. تقييم النتائج الإجمالية
        results['overall_status'] = _evaluateOverallResults(results);

        print('🧪 ========== TEST RESULTS SUMMARY ==========');
        results.forEach((key, value) {
          if (value is Map && value.containsKey('status')) {
            print('🧪 $key: ${value['status']}');
          } else {
            print('🧪 $key: $value');
          }
        });
        print('🧪 ==========================================');
      } else {
        results['error'] = 'Not running in Release Mode';
      }
    } catch (e) {
      print('❌ ReleaseModeTestHelper: Comprehensive test failed: $e');
      results['error'] = e.toString();
    }

    return results;
  }

  /// اختبار التشخيص الأساسي
  static Future<Map<String, dynamic>> _testBasicDiagnostics() async {
    final result = <String, dynamic>{};

    try {
      print('🔍 Testing basic diagnostics...');

      // تشغيل التشخيص الشامل
      final diagnostics = await ReleaseModeDignostics.runFullDiagnostics();

      // فحص المشاكل الحرجة
      final criticalIssues = await ReleaseModeDignostics.getCriticalIssues();

      result['diagnostics_completed'] = diagnostics.isNotEmpty;
      result['critical_issues_count'] = criticalIssues.length;
      result['critical_issues'] = criticalIssues;
      result['status'] = criticalIssues.isEmpty ? 'healthy' : 'issues_found';

      print('✅ Basic diagnostics test completed');
    } catch (e) {
      print('❌ Basic diagnostics test failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
    }

    return result;
  }

  /// اختبار مزامنة المستخدمين
  static Future<Map<String, dynamic>> _testUserSync() async {
    final result = <String, dynamic>{};

    try {
      print('👤 Testing user sync...');

      final userSyncService = ReleaseModeUserSyncService();

      // اختبار مزامنة المستخدم الحالي
      final syncResult = await userSyncService.syncCurrentUserToFirebase();
      result['sync_successful'] = syncResult;

      // اختبار التحقق من صحة البيانات
      final validationResult =
          await userSyncService.validateUserDataInFirebase();
      result['validation_successful'] = validationResult;

      // اختبار إصلاح المشاكل
      final fixResults = await userSyncService.fixReleaseModeUserIssues();
      result['fix_results'] = fixResults;
      result['overall_fix_success'] = fixResults['overall_success'] ?? false;

      result['status'] =
          (syncResult && validationResult) ? 'healthy' : 'issues_found';

      print('✅ User sync test completed');
    } catch (e) {
      print('❌ User sync test failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
    }

    return result;
  }

  /// اختبار تحديث المواقع
  static Future<Map<String, dynamic>> _testLocationUpdate() async {
    final result = <String, dynamic>{};

    try {
      print('📍 Testing location update...');

      final locationService = FirebaseUserLocationService();

      // اختبار تحديث موقع وهمي
      const testLocation = LatLng(30.0444, 31.2357); // القاهرة

      await locationService.updateUserLocation(testLocation);
      result['location_update_successful'] = true;

      // اختبار الحصول على المستخدمين القريبين
      final nearbyUsersStream =
          locationService.listenToNearbyUsers(testLocation, 10.0);

      // اختبار لمدة 5 ثوانٍ
      final nearbyUsers = await nearbyUsersStream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

      result['nearby_users_count'] = nearbyUsers.length;
      result['nearby_users_working'] = true;

      result['status'] = 'healthy';

      print('✅ Location update test completed');
    } catch (e) {
      print('❌ Location update test failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
      result['location_update_successful'] = false;
      result['nearby_users_working'] = false;
    }

    return result;
  }

  /// اختبار Help Requests
  static Future<Map<String, dynamic>> _testHelpRequests() async {
    final result = <String, dynamic>{};

    try {
      print('🆘 Testing help requests...');

      // Help requests are now only available for Google authenticated users
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        result['status'] = 'skipped';
        result['reason'] = 'Help requests only available for Google users';
        result['incoming_requests_working'] = false;
        result['sent_requests_working'] = false;
        return result;
      }

      final helpRequestService = FirebaseHelpRequestService();

      // اختبار الاستماع للطلبات الواردة
      final incomingRequestsStream =
          helpRequestService.listenToIncomingHelpRequests();
      final incomingRequests = await incomingRequestsStream.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );

      result['incoming_requests_working'] = true;
      result['incoming_requests_count'] = incomingRequests.length;

      // اختبار الاستماع للطلبات المرسلة
      final sentRequestsStream = helpRequestService.listenToSentHelpRequests();
      final sentRequests = await sentRequestsStream.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );

      result['sent_requests_working'] = true;
      result['sent_requests_count'] = sentRequests.length;

      result['status'] = 'healthy';

      print('✅ Help requests test completed');
    } catch (e) {
      print('❌ Help requests test failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
      result['incoming_requests_working'] = false;
      result['sent_requests_working'] = false;
    }

    return result;
  }

  /// اختبار المستخدمين المختلطين
  static Future<Map<String, dynamic>> _testMixedUsers() async {
    final result = <String, dynamic>{};

    try {
      print('🔀 Testing mixed users (SQL + Firebase)...');

      // فحص نوع المستخدم الحالي
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final sqlUserId = prefs.getString('user_id');

      if (firebaseUser != null) {
        result['current_user_type'] = 'firebase';
        result['current_user_id'] = firebaseUser.uid;
        result['current_user_email'] = firebaseUser.email;
      } else if (sqlUserId != null) {
        result['current_user_type'] = 'sql';
        result['current_user_id'] = sqlUserId;
        result['current_user_email'] = prefs.getString('user_email');
      } else {
        result['current_user_type'] = 'none';
      }

      // فحص وجود البيانات في Firebase Database
      if (result['current_user_id'] != null) {
        final database = FirebaseDatabase.instance;
        final userRef = database.ref('users/${result['current_user_id']}');
        final snapshot = await userRef.get();

        result['user_data_in_firebase'] = snapshot.exists;
        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;
          result['user_data_complete'] = userData.containsKey('name') &&
              userData.containsKey('email') &&
              userData.containsKey('userType');
        }
      }

      result['status'] =
          result['user_data_in_firebase'] == true ? 'healthy' : 'needs_sync';

      print('✅ Mixed users test completed');
    } catch (e) {
      print('❌ Mixed users test failed: $e');
      result['status'] = 'failed';
      result['error'] = e.toString();
    }

    return result;
  }

  /// تقييم النتائج الإجمالية
  static String _evaluateOverallResults(Map<String, dynamic> results) {
    try {
      int healthyCount = 0;
      int totalTests = 0;

      results.forEach((key, value) {
        if (key != 'overall_status' &&
            value is Map &&
            value.containsKey('status')) {
          totalTests++;
          if (value['status'] == 'healthy') {
            healthyCount++;
          }
        }
      });

      if (totalTests == 0) return 'no_tests';

      final healthyPercentage = (healthyCount / totalTests) * 100;

      if (healthyPercentage >= 80) {
        return 'excellent';
      } else if (healthyPercentage >= 60) {
        return 'good';
      } else if (healthyPercentage >= 40) {
        return 'fair';
      } else {
        return 'poor';
      }
    } catch (e) {
      print('❌ Error evaluating overall results: $e');
      return 'error';
    }
  }

  /// اختبار سريع للمشاكل الحرجة فقط
  static Future<List<String>> quickCriticalIssuesCheck() async {
    try {
      if (!kReleaseMode) {
        return ['Not running in Release Mode'];
      }

      return await ReleaseModeDignostics.getCriticalIssues();
    } catch (e) {
      return ['Error checking critical issues: $e'];
    }
  }

  /// طباعة تقرير مبسط
  static void printSimpleReport(Map<String, dynamic> results) {
    if (!kReleaseMode) return;

    print('📊 ========== SIMPLE RELEASE MODE REPORT ==========');
    print('📊 Overall Status: ${results['overall_status'] ?? 'unknown'}');

    if (results['diagnostics'] != null) {
      final diag = results['diagnostics'] as Map;
      print('📊 Critical Issues: ${diag['critical_issues_count'] ?? 0}');
    }

    if (results['user_sync'] != null) {
      final sync = results['user_sync'] as Map;
      print('📊 User Sync: ${sync['status'] ?? 'unknown'}');
    }

    if (results['mixed_users'] != null) {
      final mixed = results['mixed_users'] as Map;
      print('📊 User Type: ${mixed['current_user_type'] ?? 'unknown'}');
      print('📊 Data in Firebase: ${mixed['user_data_in_firebase'] ?? false}');
    }

    print('📊 ================================================');
  }
}
