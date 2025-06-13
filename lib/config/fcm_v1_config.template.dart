/// إعدادات FCM v1 API - Template File
/// انسخ هذا الملف إلى fcm_v1_config.dart وأضف بياناتك الحقيقية
class FCMv1Config {
  // معرف المشروع في Firebase
  static const String projectId = 'YOUR_PROJECT_ID';

  // بيانات Service Account JSON
  // يجب الحصول عليها من Firebase Console → Project Settings → Service accounts
  static const Map<String, dynamic> serviceAccount = {
    "type": "service_account",
    "project_id": "YOUR_PROJECT_ID",
    "private_key_id": "YOUR_PRIVATE_KEY_ID",
    "private_key": "YOUR_PRIVATE_KEY",
    "client_email": "YOUR_CLIENT_EMAIL",
    "client_id": "YOUR_CLIENT_ID",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "YOUR_CLIENT_X509_CERT_URL",
    "universe_domain": "googleapis.com"
  };

  // التحقق من صحة الإعدادات
  static bool get isConfigured {
    return projectId != 'YOUR_PROJECT_ID' &&
        serviceAccount['project_id'] != 'YOUR_PROJECT_ID' &&
        serviceAccount['private_key'] != null &&
        serviceAccount['client_email'] != null;
  }

  // رسالة خطأ في حالة عدم الإعداد
  static String get configurationError {
    if (!isConfigured) {
      return '''
❌ FCM v1 Configuration Error:
Please configure FCM v1 settings in lib/config/fcm_v1_config.dart

Steps to configure:
1. Copy fcm_v1_config.template.dart to fcm_v1_config.dart
2. Go to Firebase Console → Your Project → Project Settings
3. Click on "Service accounts" tab
4. Click "Generate new private key"
5. Download the JSON file
6. Copy the values to fcm_v1_config.dart:
   - project_id → projectId
   - Copy entire JSON → serviceAccount

Current status:
- Project ID configured: ${projectId != 'YOUR_PROJECT_ID'}
- Service Account configured: ${serviceAccount['project_id'] != 'YOUR_PROJECT_ID'}
''';
    }
    return 'FCM v1 is properly configured';
  }
}
