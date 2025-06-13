import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import '../../utils/arabic_font_helper.dart';
import '../../services/accessibility_service.dart';
import '../../services/sos_permission_service.dart';
import '../../ui/widgets/sos_permission_status_widget.dart';
import 'sos_emergency_contacts_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SOSSettingsScreen extends StatefulWidget {
  static const String routeName = '/sos-settings';

  const SOSSettingsScreen({super.key});

  @override
  State<SOSSettingsScreen> createState() => _SOSSettingsScreenState();
}

class _SOSSettingsScreenState extends State<SOSSettingsScreen> {
  bool _powerButtonEnabled = true;
  bool _sosServiceEnabled = true;
  bool _accessibilityServiceEnabled = false;
  bool _isCheckingAccessibility = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAccessibilityService();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _powerButtonEnabled = prefs.getBool('sos_power_button_enabled') ?? true;
      _sosServiceEnabled = prefs.getBool('sos_service_enabled') ?? true;
    });
  }

  Future<void> _checkAccessibilityService() async {
    setState(() {
      _isCheckingAccessibility = true;
    });

    try {
      final isEnabled =
          await AccessibilityService.isAccessibilityServiceEnabled();
      setState(() {
        _accessibilityServiceEnabled = isEnabled;
        _isCheckingAccessibility = false;
      });
    } catch (e) {
      setState(() {
        _accessibilityServiceEnabled = false;
        _isCheckingAccessibility = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_power_button_enabled', _powerButtonEnabled);
    await prefs.setBool('sos_service_enabled', _sosServiceEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor:
          isLight ? const Color(0xFFF5F8FF) : AppColors.primaryColor,
      appBar: AppBar(
        title: Text(
          lang?.sosSettings ?? 'SOS Settings',
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isLight ? const Color(0xFF023A87) : Colors.white,
          ),
        ),
        backgroundColor:
            isLight ? const Color(0xFF86A5D9) : AppColors.primaryColor,
        foregroundColor: isLight ? const Color(0xFF023A87) : Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            lang?.sosEmergencyConfiguration ?? 'Emergency SOS Configuration',
            style: ArabicFontHelper.getCairoTextStyle(
              context,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isLight ? const Color(0xFF023A87) : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang?.configureEmergencyAlerts ??
                'Configure how you want to trigger emergency alerts',
            style: ArabicFontHelper.getTajawalTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isLight ? const Color(0xFF47609A) : Colors.white70,
            ),
          ),
          const SizedBox(height: 24),

          // SOS Permissions Status
          SOSPermissionStatusWidget(
            showDetailedStatus: true,
            onPermissionsChanged: () {
              // Refresh the screen state when permissions change
              setState(() {});
            },
          ),
          const SizedBox(height: 24),

          // SOS Service Toggle
          _buildSettingTile(
            title: lang?.sosService ?? 'SOS Service',
            subtitle: lang?.enableDisableEmergencySOS ??
                'Enable/disable emergency SOS functionality',
            value: _sosServiceEnabled,
            onChanged: (value) {
              setState(() {
                _sosServiceEnabled = value;
              });
              _saveSettings();
            },
          ),
          const SizedBox(height: 16),

          // Power Button Toggle
          _buildSettingTile(
            title: lang?.powerButtonTrigger ?? 'Power Button Trigger',
            subtitle: lang?.triplePowerButtonSOS ??
                'Triple press power button to send SOS',
            value: _powerButtonEnabled && _sosServiceEnabled,
            onChanged: _sosServiceEnabled
                ? (value) {
                    setState(() {
                      _powerButtonEnabled = value;
                    });
                    _saveSettings();
                  }
                : null,
          ),
          const SizedBox(height: 16),

          // Accessibility Service Instructions (always visible if disabled)
          if (!_accessibilityServiceEnabled)
            _buildAccessibilityInstructions(lang),
          if (!_accessibilityServiceEnabled) const SizedBox(height: 16),

          const SizedBox(height: 16),

          // Emergency Contacts Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context)
                    .pushNamed(SOSEmergencyContactsScreen.routeName);
              },
              icon: const Icon(Icons.contacts),
              label: Text(
                lang?.manageEmergencyContacts ?? 'Manage Emergency Contacts',
                style: ArabicFontHelper.getTajawalTextStyle(
                  context,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: isLight
                  ? Border.all(color: const Color(0xFF86A5D9).withOpacity(0.3))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang?.howToUseSOS ?? 'How to use SOS:',
                  style: ArabicFontHelper.getCairoTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF023A87) : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang?.sosInstructions ??
                      '• Triple press power button quickly to trigger SOS\n'
                          '• Tap the emergency button on the home screen\n'
                          '• Make sure to set up emergency contacts first',
                  style: ArabicFontHelper.getTajawalTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isLight ? const Color(0xFF47609A) : Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withOpacity(0.8)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: isLight
            ? Border.all(color: const Color(0xFF86A5D9).withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ArabicFontHelper.getTajawalTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isLight ? const Color(0xFF023A87) : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: ArabicFontHelper.getTajawalTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isLight ? const Color(0xFF47609A) : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1565C0),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityInstructions(AppLocalizations? lang) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.orange.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.accessibility,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang?.enableSOSEmergencyService ??
                      'Enable SOS Emergency Service',
                  style: TextStyle(
                    color: isLight ? const Color(0xFF023A87) : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lang?.enableAccessibilityServiceSOS ??
                'Enable accessibility service to use SOS power button trigger',
            style: TextStyle(
              color: isLight ? const Color(0xFF47609A) : Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: isLight
                  ? Border.all(color: const Color(0xFF86A5D9).withOpacity(0.3))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isLight ? const Color(0xFF023A87) : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang?.followTheseSteps ?? 'Follow these steps:',
                      style: TextStyle(
                        color: isLight ? const Color(0xFF023A87) : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _InstructionStep(
                  number: '1',
                  text: lang?.androidSettingsAccessibility ??
                      'Go to Android Settings → Accessibility',
                ),
                _InstructionStep(
                  number: '2',
                  text: lang?.findInstalledAppsSection ??
                      'Find "Installed Apps" section',
                ),
                _InstructionStep(
                  number: '3',
                  text: lang?.selectRoadHelper ?? 'Select "Road Helper"',
                ),
                _InstructionStep(
                  number: '4',
                  text: lang?.toggleServiceOn ?? 'Toggle the service ON',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _checkAccessibilityService,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: isLight
                              ? const Color(0xFF86A5D9).withOpacity(0.5)
                              : Colors.white.withOpacity(0.3)),
                    ),
                  ),
                  child: _isCheckingAccessibility
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(isLight
                                ? const Color(0xFF023A87)
                                : Colors.white),
                          ),
                        )
                      : Text(
                          lang?.checkStatus ?? 'Check Status',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF023A87)
                                : Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    await AccessibilityService.openAccessibilitySettings();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(lang?.afterEnablingServiceReturn ??
                              'After enabling the service, return to the app and check status'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    lang?.openSettings ?? 'Open Settings',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isLight ? const Color(0xFF47609A) : Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
