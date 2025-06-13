# 🧪 كيفية الوصول لشاشة اختبار Help Request

## 📍 **مكان الشاشة:**
```
lib/ui/screens/help_request_test_screen.dart
```

## 🔑 **طرق الوصول:**

### **الطريقة 1: من شاشة Profile (الأسهل)**
1. **افتح التطبيق كمستخدم Google** (مهم جداً!)
2. **اذهب لشاشة Profile** (آخر تاب في الأسفل)
3. **ابحث عن "Help Request Test"** في قائمة الإعدادات
4. **اضغط عليها** لفتح شاشة الاختبار

> **ملاحظة:** الزر يظهر فقط في وضع التطوير (Debug Mode) ولمستخدمي Google فقط

### **الطريقة 2: Navigation مباشر**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const HelpRequestTestScreen(),
  ),
);
```

### **الطريقة 3: إضافة Route**
```dart
// في main.dart
routes: {
  '/help-request-test': (context) => const HelpRequestTestScreen(),
  // ... باقي الـ routes
}

// للانتقال
Navigator.pushNamed(context, '/help-request-test');
```

---

## 🧪 **ما يمكن اختباره في الشاشة:**

### **1. System Diagnostics**
- ✅ فحص Google Authentication
- ✅ فحص FCM Token Management
- ✅ فحص User Data Sync
- ✅ فحص Firebase Database Connectivity
- ✅ فحص User Visibility on Map
- ✅ اختبار Help Request Flow
- ✅ اختبار Notification Delivery

### **2. Test Actions**
- 🔧 **Test FCM Token Save** - اختبار حفظ FCM token
- 📱 **Test Notification Send** - اختبار إرسال إشعار
- 🆘 **Test Help Request Flow** - اختبار تدفق طلب المساعدة الكامل

### **3. Test Results**
- 📊 عرض نتائج الاختبارات
- ✅ حالة النجاح/الفشل
- 📝 تفاصيل الأخطاء إن وجدت

---

## 🎯 **الاختبار الأساسي:**

### **خطوات الاختبار السريع:**
1. **افتح شاشة Help Request Test**
2. **اضغط "Test Help Request Flow"**
3. **انتظر النتيجة**
4. **اذهب لشاشة Notifications**
5. **تأكد من وصول الإشعار**

### **النتيجة المتوقعة:**
```
✅ Test help request sent successfully
Request ID: test_1234567890
```

---

## 🔧 **استكشاف الأخطاء:**

### **إذا لم تجد الزر:**
- ✅ تأكد أنك مسجل دخول كمستخدم Google
- ✅ تأكد أن التطبيق في وضع Debug Mode
- ✅ أعد تشغيل التطبيق

### **إذا فشل الاختبار:**
- 📱 تأكد من اتصال الإنترنت
- 🔑 تأكد من صحة Google Authentication
- 🔥 تأكد من تشغيل Firebase Functions
- 📍 تأكد من أذونات الموقع

---

## 📞 **للمساعدة:**

إذا واجهت أي مشاكل:
1. **تحقق من Console logs** في Android Studio/VS Code
2. **راجع Firebase Console** للتأكد من Functions
3. **تأكد من FCM Configuration** في Firebase

---

**🎉 النظام جاهز للاختبار الآن!**
