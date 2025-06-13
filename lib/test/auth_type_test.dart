import 'package:flutter/material.dart';
import 'package:road_helperr/services/auth_service.dart';
import 'package:road_helperr/utils/auth_type_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// صفحة اختبار لتحديد نوع المصادقة
class AuthTypeTestScreen extends StatefulWidget {
  const AuthTypeTestScreen({super.key});

  @override
  State<AuthTypeTestScreen> createState() => _AuthTypeTestScreenState();
}

class _AuthTypeTestScreenState extends State<AuthTypeTestScreen> {
  String _currentAuthType = 'غير محدد';
  String _currentEmail = 'غير محدد';
  bool _isLoggedIn = false;
  String _dataApiEndpoint = 'غير محدد';
  String _updateApiEndpoint = 'غير محدد';
  String _imagesApiEndpoint = 'غير محدد';
  String _signupApiEndpoint = 'غير محدد';
  String _apiMethod = 'غير محدد';

  @override
  void initState() {
    super.initState();
    _loadAuthInfo();
  }

  Future<void> _loadAuthInfo() async {
    try {
      final authService = AuthService();

      // جلب معلومات المصادقة
      final authType = await authService.getAuthType();
      final email = await authService.getUserEmail() ?? 'غير محدد';
      final loggedIn = await authService.isLoggedIn();

      // جلب معلومات APIs
      const baseUrl = 'http://81.10.91.96:8132/api';
      final dataEndpoint = await AuthTypeHelper.getDataApiEndpoint(baseUrl);
      final updateEndpoint = await AuthTypeHelper.getUpdateApiEndpoint(baseUrl);
      final imagesEndpoint = await AuthTypeHelper.getImagesApiEndpoint(baseUrl);
      final signupEndpoint = await AuthTypeHelper.getSignupApiEndpoint(baseUrl);
      final method = await AuthTypeHelper.getDataApiMethod();

      setState(() {
        _currentAuthType = authType;
        _currentEmail = email;
        _isLoggedIn = loggedIn;
        _dataApiEndpoint = dataEndpoint;
        _updateApiEndpoint = updateEndpoint;
        _imagesApiEndpoint = imagesEndpoint;
        _signupApiEndpoint = signupEndpoint;
        _apiMethod = method;
      });

      // طباعة معلومات التشخيص
      await AuthTypeHelper.printAuthInfo();
    } catch (e) {
      debugPrint('❌ خطأ في تحميل معلومات المصادقة: $e');
    }
  }

  Future<void> _setGoogleAuth() async {
    try {
      await AuthTypeHelper.setAuthType(true);
      await _loadAuthInfo();
      _showMessage('تم تعيين نوع المصادقة إلى Google');
    } catch (e) {
      _showMessage('خطأ: $e');
    }
  }

  Future<void> _setTraditionalAuth() async {
    try {
      await AuthTypeHelper.setAuthType(false);
      await _loadAuthInfo();
      _showMessage('تم تعيين نوع المصادقة إلى Traditional');
    } catch (e) {
      _showMessage('خطأ: $e');
    }
  }

  Future<void> _validateSettings() async {
    try {
      final isValid = await AuthTypeHelper.validateAuthSettings();
      _showMessage(
          isValid ? 'إعدادات المصادقة صحيحة' : 'إعدادات المصادقة غير صحيحة');
      await _loadAuthInfo();
    } catch (e) {
      _showMessage('خطأ: $e');
    }
  }

  Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_google_sign_in');
      await prefs.remove('logged_in_email');
      await prefs.remove('is_logged_in');
      await _loadAuthInfo();
      _showMessage('تم مسح بيانات المصادقة');
    } catch (e) {
      _showMessage('خطأ: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار نوع المصادقة'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات المصادقة الحالية:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text('نوع المصادقة: $_currentAuthType'),
                    Text('البريد الإلكتروني: $_currentEmail'),
                    Text(
                        'حالة تسجيل الدخول: ${_isLoggedIn ? 'مسجل' : 'غير مسجل'}'),
                    const SizedBox(height: 10),
                    const Text(
                      'APIs المستخدمة:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text('Data API: $_dataApiEndpoint'),
                    Text('Update API: $_updateApiEndpoint'),
                    Text('Images API: $_imagesApiEndpoint'),
                    Text('Signup API: $_signupApiEndpoint'),
                    Text('HTTP Method: $_apiMethod'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'أدوات الاختبار:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: _setGoogleAuth,
                  child: const Text('تعيين Google'),
                ),
                ElevatedButton(
                  onPressed: _setTraditionalAuth,
                  child: const Text('تعيين Traditional'),
                ),
                ElevatedButton(
                  onPressed: _validateSettings,
                  child: const Text('التحقق من الإعدادات'),
                ),
                ElevatedButton(
                  onPressed: _loadAuthInfo,
                  child: const Text('إعادة تحميل'),
                ),
                ElevatedButton(
                  onPressed: _clearAuthData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('مسح البيانات'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
