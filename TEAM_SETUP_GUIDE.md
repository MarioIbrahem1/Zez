# دليل إعداد المشروع للفريق الجديد

## المتطلبات الأساسية

1. **Flutter SDK** - تأكد من تثبيت Flutter
2. **Android Studio** أو **VS Code** مع إضافات Flutter
3. **Git** للتحكم في الإصدارات

## خطوات الإعداد

### 1. استنساخ المشروع

```bash
git clone [YOUR_REPOSITORY_URL]
cd RH
```

### 2. تثبيت التبعيات

```bash
flutter pub get
```

### 3. إعداد Firebase

#### أ. إعداد firebase_options.dart

1. انسخ الملف `lib/firebase_options.example.dart` إلى `lib/firebase_options.dart`
2. استبدل القيم التالية بقيم مشروع Firebase الخاص بك:
   - `YOUR_ANDROID_API_KEY_HERE`
   - `YOUR_ANDROID_APP_ID_HERE`
   - `YOUR_MESSAGING_SENDER_ID_HERE`
   - `YOUR_PROJECT_ID_HERE`
   - `YOUR_DATABASE_URL_HERE`
   - `YOUR_STORAGE_BUCKET_HERE`
   - `YOUR_IOS_API_KEY_HERE`
   - `YOUR_IOS_APP_ID_HERE`
   - `YOUR_IOS_BUNDLE_ID_HERE`

#### ب. إعداد Service Account Key

1. انسخ الملف `assets/service-account-key.example.json` إلى `assets/service-account-key.json`
2. استبدل المحتوى بمفتاح Service Account الخاص بمشروع Firebase

### 4. إعداد Android

#### أ. إنشاء local.properties

أنشئ ملف `android/local.properties` مع المحتوى التالي:

```
sdk.dir=PATH_TO_YOUR_ANDROID_SDK
flutter.sdk=PATH_TO_YOUR_FLUTTER_SDK
flutter.buildMode=debug
flutter.versionName=1.0.6
flutter.versionCode=6
```

#### ب. إضافة google-services.json

1. احصل على ملف `google-services.json` من Firebase Console
2. ضعه في مجلد `android/app/`

### 5. إعداد iOS (إذا كنت تطور لـ iOS)

1. احصل على ملف `GoogleService-Info.plist` من Firebase Console
2. ضعه في مجلد `ios/Runner/`

### 6. تشغيل المشروع

```bash
flutter run
```

## ملاحظات مهمة

### الملفات الحساسة

الملفات التالية **لا يجب** رفعها إلى Git:

- `assets/service-account-key.json`
- `android/local.properties`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### إعداد Firebase Database Rules

تأكد من أن قواعد Firebase Database مضبوطة على:

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

### المتغيرات البيئية

إذا كان لديك متغيرات بيئية إضافية، أنشئ ملف `.env` في الجذر.

## استكشاف الأخطاء

### مشاكل شائعة:

1. **خطأ في Firebase**: تأكد من صحة إعداد `firebase_options.dart`
2. **خطأ في Android**: تأكد من وجود `google-services.json` في المكان الصحيح
3. **خطأ في التبعيات**: قم بتشغيل `flutter clean` ثم `flutter pub get`

## Script الإعداد السريع

يمكنك استخدام script الإعداد السريع:

### Windows:

```bash
./setup_project.bat
```

### Linux/Mac:

```bash
chmod +x setup_project.sh
./setup_project.sh
```

## الحصول على المساعدة

إذا واجهت أي مشاكل، تواصل مع فريق التطوير أو راجع الملفات التالية:

- `FIREBASE_SETUP.md`
- `HELP_REQUEST_SYSTEM_STATUS.md`
- `SOS_INTEGRATION_README.md`
