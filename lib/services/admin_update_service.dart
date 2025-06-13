import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:road_helperr/services/update_service.dart';
import 'package:road_helperr/services/fcm_v1_service.dart';

/// هذه الخدمة مخصصة للمطور فقط لرفع التحديثات
/// لا يتم تضمينها في الإصدار النهائي للتطبيق
class AdminUpdateService {
  // Singleton instance
  static final AdminUpdateService _instance = AdminUpdateService._internal();
  factory AdminUpdateService() => _instance;

  AdminUpdateService._internal();

  /// رفع ملف APK إلى خادم التخزين
  Future<String> uploadApkToStorage(File apkFile, String version) async {
    try {
      // في هذا المثال، نفترض أن لدينا خادم تخزين يمكننا رفع الملفات إليه
      // يمكن استبدال هذا بخدمة تخزين أخرى مثل Amazon S3 أو Google Cloud Storage

      // إنشاء طلب متعدد الأجزاء لرفع الملف
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://your-storage-server.com/upload'),
      );

      // إضافة الملف إلى الطلب
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        apkFile.path,
        filename: 'app-$version.apk',
      ));

      // إرسال الطلب
      final response = await request.send();

      if (response.statusCode == 200) {
        // قراءة الرد
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);

        // استخراج رابط التنزيل من الرد
        final String downloadUrl = jsonData['download_url'];
        return downloadUrl;
      } else {
        throw Exception('فشل في رفع الملف: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('خطأ في رفع ملف APK: $e');
      rethrow;
    }
  }

  /// إنشاء تحديث جديد
  Future<void> createNewUpdate({
    required String version,
    required int versionCode,
    required String downloadUrl,
    required String releaseNotes,
    bool forceUpdate = false,
  }) async {
    try {
      final UpdateInfo updateInfo = UpdateInfo(
        version: version,
        versionCode: versionCode,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
      );

      // حفظ معلومات التحديث في التخزين المحلي للمستخدمين
      await UpdateService().saveUpdateInfo(updateInfo);

      debugPrint('تم إنشاء تحديث جديد بنجاح');
    } catch (e) {
      debugPrint('خطأ في إنشاء تحديث جديد: $e');
      rethrow;
    }
  }

  /// إرسال إشعار للمستخدمين بتوفر تحديث جديد
  Future<void> sendUpdateNotification({
    required String title,
    required String body,
    required String downloadUrl,
    List<String>? userIds, // إضافة قائمة معرفات المستخدمين
  }) async {
    try {
      // استخدام FCM v1 API لإرسال إشعارات التحديث
      final fcmService = FCMv1Service();

      if (userIds != null && userIds.isNotEmpty) {
        // إرسال إشعار لمستخدمين محددين
        final results = await fcmService.sendNotificationToMultipleUsers(
          userIds: userIds,
          title: title,
          body: body,
          data: {
            'type': 'app_update',
            'download_url': downloadUrl,
          },
        );

        final successCount = results.where((result) => result).length;
        debugPrint(
            'تم إرسال الإشعار بنجاح إلى $successCount من ${userIds.length} مستخدم');
      } else {
        debugPrint('لم يتم تحديد معرفات المستخدمين لإرسال إشعار التحديث');
      }
    } catch (e) {
      debugPrint('خطأ في إرسال إشعار التحديث: $e');
      rethrow;
    }
  }
}
