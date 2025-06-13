# نظام Persistent Login للحفاظ على تشغيل التطبيق

## نظرة عامة

تم تطوير نظام Persistent Login لضمان استمرار عمل التطبيق وخدمات الطوارئ (SOS) حتى لو انتهت صلاحية الـ token أو أعيد تشغيل التطبيق.

## المميزات الجديدة

### 1. حفظ آخر Login Token
- **حفظ تلقائي**: يتم حفظ آخر token تلقائياً مع تاريخ انتهاء الصلاحية
- **مدة الصلاحية**: 30 يوم افتراضياً
- **تجديد تلقائي**: محاولة تجديد الـ token باستخدام remember me credentials

### 2. Persistent Login
- **تمكين/تعطيل**: يمكن للمستخدم التحكم في هذه الميزة
- **افتراضي مفعل**: النظام مفعل افتراضياً لضمان عمل خدمات الطوارئ
- **استعادة الجلسة**: استعادة تلقائية للجلسة عند بدء التطبيق

### 3. خدمات SOS المحسنة
- **عمل مستقل**: تعمل حتى لو انتهت صلاحية الـ token
- **Emergency Contacts**: حفظ مستقل لجهات الاتصال الطارئة
- **تحقق ذكي**: التحقق من توفر الخدمات قبل الاستخدام

## الملفات المضافة/المحدثة

### ملفات جديدة:
1. `lib/services/persistent_login_manager.dart` - مدير الـ Persistent Login
2. `lib/ui/widgets/persistent_login_settings_widget.dart` - واجهة الإعدادات
3. `lib/test/persistent_login_test.dart` - اختبارات النظام

### ملفات محدثة:
1. `lib/services/auth_service.dart` - تحسينات على إدارة المصادقة
2. `lib/services/sos_service.dart` - تحسينات على خدمات الطوارئ
3. `lib/main.dart` - تهيئة النظام الجديد
4. `lib/services/api_service.dart` - دعم الـ persistent login
5. `lib/ui/screens/signin_screen.dart` - حفظ حالة "تذكرني"

## كيفية الاستخدام

### للمطورين:

```dart
// الحصول على مدير الـ Persistent Login
final loginManager = PersistentLoginManager();

// تمكين/تعطيل الـ persistent login
await loginManager.setPersistentLoginEnabled(true);

// التحقق من الحالة
bool enabled = await loginManager.isPersistentLoginEnabled();

// الحصول على معلومات الجلسة
Map<String, dynamic> sessionInfo = await loginManager.getSessionInfo();

// تجديد الـ token يدوياً
bool renewed = await loginManager.forceTokenRenewal();
```

### للمستخدمين:

1. **في صفحة الإعدادات**: يمكن تمكين/تعطيل "البقاء مسجل دخول"
2. **تلقائي**: النظام يعمل تلقائياً في الخلفية
3. **خدمات الطوارئ**: تبقى متاحة حتى لو انتهت الجلسة

## التحسينات التقنية

### 1. إدارة الـ Tokens
```dart
// مفاتيح جديدة في SharedPreferences
static const String _tokenExpiryKey = 'token_expiry';
static const String _lastLoginTimeKey = 'last_login_time';
static const String _persistentLoginKey = 'persistent_login_enabled';
static const String _sosEmergencyContactsKey = 'sos_emergency_contacts';
```

### 2. التحقق الذكي من الجلسة
```dart
// التحقق من صلاحية الـ token
final isTokenValid = currentTime < tokenExpiry;

if (!isTokenValid && persistentLoginEnabled) {
    // محاولة تجديد الـ token
    final canRenewToken = await _attemptTokenRenewal();
}
```

### 3. خدمات SOS المستقلة
```dart
// التحقق من إمكانية استخدام SOS
Future<bool> canUseSosServices() async {
    final userEmail = prefs.getString(_userEmailKey);
    final emergencyContacts = await getEmergencyContacts();
    
    return userEmail != null && 
           userEmail.isNotEmpty && 
           emergencyContacts.isNotEmpty;
}
```

## الاختبارات

### تشغيل الاختبارات:
```dart
// اختبار شامل
await PersistentLoginTest.runAllTests();

// اختبار سريع
await PersistentLoginTest.runQuickTest();
```

### أنواع الاختبارات:
1. **Basic Functionality**: تمكين/تعطيل الـ persistent login
2. **Token Expiry**: التعامل مع انتهاء صلاحية الـ tokens
3. **SOS Services**: خدمات الطوارئ
4. **Session Info**: معلومات الجلسة
5. **Export/Import**: تصدير/استيراد الإعدادات

## الأمان

### 1. حماية البيانات
- **تشفير محلي**: البيانات الحساسة محمية
- **انتهاء صلاحية**: الـ tokens لها مدة صلاحية محددة
- **تنظيف تلقائي**: مسح البيانات المنتهية الصلاحية

### 2. التحكم في الخصوصية
- **اختياري**: المستخدم يتحكم في تمكين/تعطيل الميزة
- **شفافية**: عرض معلومات الجلسة للمستخدم
- **مسح آمن**: إمكانية مسح جميع البيانات

## استكشاف الأخطاء

### مشاكل شائعة:

1. **فشل تجديد الـ Token**:
   - تحقق من وجود remember me credentials
   - تحقق من اتصال الإنترنت
   - تحقق من صحة بيانات الخادم

2. **خدمات SOS غير متاحة**:
   - تحقق من وجود emergency contacts
   - تحقق من وجود user email
   - تحقق من أذونات التطبيق

3. **مشاكل في الجلسة**:
   - استخدم `cleanupExpiredSessions()`
   - أعد تسجيل الدخول يدوياً
   - تحقق من إعدادات الـ persistent login

### سجلات التشخيص:
```dart
// تمكين السجلات المفصلة
debugPrint('=== حالة تسجيل الدخول المحسنة ===');
debugPrint('persistent login enabled: $persistentLoginEnabled');
debugPrint('token expiry: ${DateTime.fromMillisecondsSinceEpoch(tokenExpiry)}');
```

## الخطوات التالية

### تحسينات مستقبلية:
1. **إشعارات التجديد**: تذكير المستخدم قبل انتهاء الصلاحية
2. **نسخ احتياطية**: حفظ الإعدادات في السحابة
3. **تحليلات**: مراقبة أداء النظام
4. **أمان متقدم**: تشفير أقوى للبيانات الحساسة

### ملاحظات للتطوير:
- النظام متوافق مع Google و Traditional authentication
- يدعم جميع خدمات التطبيق الحالية
- لا يؤثر على الأداء العام للتطبيق
- قابل للتوسع والتخصيص

---

**تاريخ الإنشاء**: ديسمبر 2024  
**الإصدار**: 1.0.0  
**المطور**: Road Helper Team
