import 'package:flutter/material.dart';
import 'package:road_helperr/services/sos_permission_service.dart';
import 'package:road_helperr/ui/widgets/sos_permission_status_widget.dart';
import 'package:road_helperr/utils/app_colors.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Screen for setting up SOS permissions during first-time app setup
class SOSPermissionSetupScreen extends StatefulWidget {
  static const String routeName = '/sos-permission-setup';

  final VoidCallback? onSetupComplete;

  const SOSPermissionSetupScreen({
    super.key,
    this.onSetupComplete,
  });

  @override
  State<SOSPermissionSetupScreen> createState() =>
      _SOSPermissionSetupScreenState();
}

class _SOSPermissionSetupScreenState extends State<SOSPermissionSetupScreen> {
  final SOSPermissionService _permissionService = SOSPermissionService();
  SOSPermissionStatus _permissionStatus = SOSPermissionStatus.disabled;
  bool _isLoading = false;
  bool _setupComplete = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _permissionService.getSOSPermissionStatus();
      setState(() {
        _permissionStatus = status;
        _setupComplete = status == SOSPermissionStatus.fullyEnabled;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ SOS Permission Setup: Error checking status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final granted =
          await _permissionService.requestAllRequiredPermissions(context);

      if (granted) {
        setState(() {
          _setupComplete = true;
        });

        if (mounted) {
          final lang = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ ${lang?.allSOSPermissionsGrantedSuccessfully ?? 'SOS permissions granted successfully!'}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      await _checkPermissionStatus();
    } catch (e) {
      debugPrint('❌ SOS Permission Setup: Error requesting permissions: $e');
      if (mounted) {
        final lang = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ ${lang?.errorRequestingPermissions ?? 'Error requesting permissions. Please try again.'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _completeSetup() {
    widget.onSetupComplete?.call();
    Navigator.of(context).pop();
  }

  void _skipSetup() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lang = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor:
          isLight ? const Color(0xFFF5F8FF) : AppColors.primaryColor,
      appBar: AppBar(
        title: Text(
          lang?.sosEmergencyConfiguration ?? 'SOS Emergency Setup',
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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(lang?.checkingSOSPermissions ??
                      'Setting up SOS permissions...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: isLight
                          ? Border.all(
                              color: const Color(0xFF86A5D9).withOpacity(0.3))
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.security,
                          size: 64,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          lang?.sosEmergencyConfiguration ??
                              'Emergency SOS Setup',
                          style: ArabicFontHelper.getCairoTextStyle(
                            context,
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: isLight
                                ? const Color(0xFF023A87)
                                : Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isTablet ? 16 : 12),
                        Text(
                          lang?.sosEmergencyFeatureRequiresPermissions ??
                              'The SOS emergency feature requires several permissions to function properly and help you in emergency situations.',
                          style: ArabicFontHelper.getTajawalTextStyle(
                            context,
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w400,
                            color: isLight
                                ? const Color(0xFF47609A)
                                : Colors.white70,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Permission Status Widget
                  SOSPermissionStatusWidget(
                    showDetailedStatus: true,
                    onPermissionsChanged: _checkPermissionStatus,
                  ),
                  const SizedBox(height: 24),

                  // Features Explanation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.blue.shade50
                          : Colors.blue.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLight
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              lang?.whatSOSCanDo ?? 'What SOS Can Do',
                              style: ArabicFontHelper.getTajawalTextStyle(
                                context,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isLight
                                    ? Colors.blue.shade800
                                    : Colors.blue.shade200,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          icon: Icons.phone,
                          title: lang?.emergencyCalls ?? 'Emergency Calls',
                          description:
                              lang?.automaticallyCallEmergencyContacts ??
                                  'Automatically call your emergency contacts',
                          isLight: isLight,
                        ),
                        _buildFeatureItem(
                          icon: Icons.sms,
                          title: lang?.locationSMS ?? 'Location SMS',
                          description: lang?.sendExactLocationViaSMS ??
                              'Send your exact location via SMS',
                          isLight: isLight,
                        ),
                        _buildFeatureItem(
                          icon: Icons.power_settings_new,
                          title: lang?.powerButtonTrigger ??
                              'Power Button Trigger',
                          description: lang?.triplePowerButtonSOS ??
                              'Triple-press power button to activate SOS',
                          isLight: isLight,
                        ),
                        _buildFeatureItem(
                          icon: Icons.notifications_active,
                          title: lang?.sendEmergencyNotifications ??
                              'Emergency Alerts',
                          description: lang?.sendEmergencyNotifications ??
                              'Show critical emergency notifications',
                          isLight: isLight,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  if (_setupComplete) ...[
                    // Setup Complete
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang?.allRequiredPermissionsGranted ??
                                  'SOS Emergency feature is ready to use!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _completeSetup,
                        icon: const Icon(Icons.check),
                        label: Text(
                          'Complete Setup', // يمكن إضافة ترجمة لاحقاً
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Setup Required
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _requestPermissions,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.security),
                        label: Text(
                          _isLoading
                              ? (lang?.checkingSOSPermissions ??
                                  'Setting up...')
                              : (lang?.enableSOSPermissions ??
                                  'Grant SOS Permissions'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: _skipSetup,
                        child: Text(
                          'Skip for Now', // يمكن إضافة ترجمة لاحقاً
                          style: TextStyle(
                            fontSize: 16,
                            color: isLight
                                ? const Color(0xFF47609A)
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isLight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: isLight ? Colors.blue.shade600 : Colors.blue.shade300,
            size: 24,
          ),
          const SizedBox(width: 12),
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
                    color:
                        isLight ? Colors.blue.shade800 : Colors.blue.shade200,
                  ),
                ),
                Text(
                  description,
                  style: ArabicFontHelper.getTajawalTextStyle(
                    context,
                    fontSize: 14,
                    color:
                        isLight ? Colors.blue.shade700 : Colors.blue.shade300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
