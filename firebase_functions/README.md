# 🔥 Firebase Functions للإشعارات - Road Helper App

## 📋 نظرة عامة

هذه Firebase Functions مصممة لإرسال الإشعارات في تطبيق Road Helper بدون الحاجة لـ FCM Server Key.

## 🚀 المميزات

- ✅ **إرسال إشعارات عامة** - `sendPushNotification`
- ✅ **إشعارات طلبات المساعدة** - `sendHelpRequestNotification`
- ✅ **إشعارات ردود المساعدة** - `sendHelpResponseNotification`
- ✅ **إشعارات رسائل الشات** - `sendChatMessageNotification`
- ✅ **اختبار الإشعارات** - `testNotification`

## 🛠️ التثبيت والنشر

### 1. تثبيت Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. تسجيل الدخول لـ Firebase

```bash
firebase login
```

### 3. تهيئة المشروع

```bash
cd firebase_functions
firebase init
```

### 4. تثبيت Dependencies

```bash
cd functions
npm install
```

### 5. نشر Functions

```bash
firebase deploy --only functions
```

## 📡 استخدام Functions

### إرسال إشعار عام

```javascript
POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendPushNotification

{
  "userId": "temp_user_449806221",
  "title": "عنوان الإشعار",
  "body": "محتوى الإشعار",
  "data": {
    "type": "general",
    "customData": "value"
  }
}
```

### إرسال إشعار طلب مساعدة

```javascript
POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendHelpRequestNotification

{
  "receiverId": "user_123",
  "senderName": "أحمد محمد",
  "requestId": "req_456",
  "additionalData": {
    "location": "القاهرة"
  }
}
```

### إرسال إشعار رد على طلب المساعدة

```javascript
POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendHelpResponseNotification

{
  "senderId": "user_123",
  "responderName": "محمد علي",
  "requestId": "req_456",
  "accepted": true,
  "additionalData": {
    "contact": "+201234567890"
  }
}
```

### إرسال إشعار رسالة شات

```javascript
POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendChatMessageNotification

{
  "receiverId": "user_123",
  "senderName": "أحمد محمد",
  "messageContent": "مرحبا، هل تحتاج مساعدة؟",
  "chatId": "chat_789",
  "additionalData": {
    "messageId": "msg_101"
  }
}
```

### اختبار الإشعارات

```javascript
POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/testNotification

{
  "userId": "temp_user_449806221"
}
```

## 🔧 التكوين

### 1. تحديث URL في التطبيق

في ملف `firebase_functions_notification_service.dart`:

```dart
static const String _functionsBaseUrl = 
    'https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net';
```

### 2. تحديث قواعد قاعدة البيانات

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

## 📊 مراقبة Functions

### عرض Logs

```bash
firebase functions:log
```

### مراقبة الأداء

- اذهب إلى Firebase Console
- Functions → Logs
- راقب الاستخدام والأخطاء

## 🔒 الأمان

- ✅ CORS مفعل للتطبيق
- ✅ التحقق من البيانات المطلوبة
- ✅ معالجة الأخطاء الشاملة
- ⚠️ للإنتاج: أضف Authentication

## 🐛 استكشاف الأخطاء

### خطأ "FCM token not found"

```javascript
// تأكد من حفظ FCM token في قاعدة البيانات
users/{userId}/fcmToken: "FCM_TOKEN_HERE"
```

### خطأ "Method not allowed"

```javascript
// تأكد من استخدام POST method
fetch(url, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(data)
})
```

### خطأ CORS

```javascript
// تأكد من إضافة CORS headers في Function
res.set('Access-Control-Allow-Origin', '*');
```

## 📈 التحسينات المستقبلية

- [ ] إضافة Authentication
- [ ] Rate Limiting
- [ ] Batch Notifications
- [ ] Analytics Integration
- [ ] Error Reporting

## 🆘 الدعم

للمساعدة أو الإبلاغ عن مشاكل:
1. تحقق من Firebase Console Logs
2. راجع قاعدة البيانات للـ FCM tokens
3. اختبر Functions محلياً أولاً

---

**ملاحظة**: هذه Functions تحتاج نشر على Firebase لتعمل. استخدم Local Notifications كـ fallback.
