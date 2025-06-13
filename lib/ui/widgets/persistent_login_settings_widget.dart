import 'package:flutter/material.dart';
import '../../services/persistent_login_manager.dart';

/// Widget لإعدادات الـ Persistent Login في صفحة الـ Profile
class PersistentLoginSettingsWidget extends StatefulWidget {
  const PersistentLoginSettingsWidget({super.key});

  @override
  State<PersistentLoginSettingsWidget> createState() => _PersistentLoginSettingsWidgetState();
}

class _PersistentLoginSettingsWidgetState extends State<PersistentLoginSettingsWidget> {
  final PersistentLoginManager _loginManager = PersistentLoginManager();
  bool _persistentLoginEnabled = true;
  bool _isLoading = true;
  Map<String, dynamic>? _sessionInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await _loginManager.isPersistentLoginEnabled();
      final sessionInfo = await _loginManager.getSessionInfo();
      
      if (mounted) {
        setState(() {
          _persistentLoginEnabled = enabled;
          _sessionInfo = sessionInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePersistentLogin(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loginManager.setPersistentLoginEnabled(value);
      
      if (mounted) {
        setState(() {
          _persistentLoginEnabled = value;
          _isLoading = false;
        });

        // إظهار رسالة تأكيد
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value 
                ? 'تم تمكين البقاء مسجل دخول - التطبيق سيبقى يعمل للطوارئ'
                : 'تم تعطيل البقاء مسجل دخول - ستحتاج لتسجيل الدخول مرة أخرى',
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تغيير الإعدادات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _forceTokenRenewal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _loginManager.forceTokenRenewal();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? 'تم تجديد الجلسة بنجاح'
                : 'فشل في تجديد الجلسة - قد تحتاج لتسجيل الدخول مرة أخرى',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          _loadSettings(); // إعادة تحميل معلومات الجلسة
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان الرئيسي
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'إعدادات الأمان والجلسة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // إعداد البقاء مسجل دخول
            SwitchListTile(
              title: const Text('البقاء مسجل دخول'),
              subtitle: const Text(
                'يحافظ على تشغيل التطبيق للطوارئ حتى لو انتهت صلاحية الجلسة',
              ),
              value: _persistentLoginEnabled,
              onChanged: _togglePersistentLogin,
              secondary: Icon(
                _persistentLoginEnabled ? Icons.lock_open : Icons.lock,
                color: _persistentLoginEnabled ? Colors.green : Colors.grey,
              ),
            ),

            const Divider(),

            // معلومات الجلسة
            if (_sessionInfo != null) ...[
              Text(
                'معلومات الجلسة',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              _buildSessionInfoRow(
                'حالة تسجيل الدخول',
                _sessionInfo!['isLoggedIn'] == true ? 'مسجل دخول' : 'غير مسجل',
                _sessionInfo!['isLoggedIn'] == true ? Colors.green : Colors.red,
              ),
              
              _buildSessionInfoRow(
                'خدمات الطوارئ',
                _sessionInfo!['canUseSos'] == true ? 'متاحة' : 'غير متاحة',
                _sessionInfo!['canUseSos'] == true ? Colors.green : Colors.orange,
              ),

              if (_sessionInfo!['tokenValid'] == true)
                _buildSessionInfoRow(
                  'صلاحية الجلسة',
                  '${(_sessionInfo!['daysUntilTokenExpiry'] as double).toStringAsFixed(1)} يوم متبقي',
                  Colors.blue,
                ),

              const SizedBox(height: 16),

              // زر تجديد الجلسة
              if (_persistentLoginEnabled)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _forceTokenRenewal,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تجديد الجلسة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 8),

            // ملاحظة مهمة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تمكين هذا الإعداد يضمن عمل خدمات الطوارئ (SOS) حتى لو انتهت صلاحية الجلسة',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
