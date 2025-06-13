import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Service for managing SOS emergency feature permissions
class SOSPermissionService {
  static final SOSPermissionService _instance =
      SOSPermissionService._internal();
  factory SOSPermissionService() => _instance;
  SOSPermissionService._internal();

  // Required permissions for SOS functionality
  static const List<Permission> _requiredPermissions = [
    Permission.phone, // Make emergency calls
    Permission.sms, // Send emergency SMS
    Permission.location, // Get current location for emergency
    Permission.contacts, // Access emergency contacts
    Permission.notification, // Show SOS notifications
  ];

  // Optional permissions that enhance SOS functionality
  static const List<Permission> _optionalPermissions = [
    Permission.camera, // Take emergency photos
    Permission.microphone, // Record emergency audio
    Permission.storage, // Store emergency data
  ];

  /// Check if all required SOS permissions are granted
  Future<bool> hasAllRequiredPermissions() async {
    try {
      for (final permission in _requiredPermissions) {
        final status = await permission.status;
        if (!status.isGranted) {
          debugPrint('❌ SOS Permission: ${permission.toString()} not granted');
          return false;
        }
      }
      debugPrint('✅ SOS Permission: All required permissions granted');
      return true;
    } catch (e) {
      debugPrint('❌ SOS Permission: Error checking permissions: $e');
      return false;
    }
  }

  /// Get the status of all SOS-related permissions
  Future<Map<Permission, PermissionStatus>> getAllPermissionStatuses() async {
    final Map<Permission, PermissionStatus> statuses = {};

    try {
      // Check required permissions
      for (final permission in _requiredPermissions) {
        statuses[permission] = await permission.status;
      }

      // Check optional permissions
      for (final permission in _optionalPermissions) {
        statuses[permission] = await permission.status;
      }
    } catch (e) {
      debugPrint('❌ SOS Permission: Error getting permission statuses: $e');
    }

    return statuses;
  }

  /// Request all required SOS permissions with user-friendly dialogs
  Future<bool> requestAllRequiredPermissions(BuildContext context) async {
    try {
      debugPrint('🔐 SOS Permission: Starting permission request flow');

      // Check if we should show rationale first
      final shouldShowRationale = await _shouldShowPermissionRationale();

      if (shouldShowRationale && context.mounted) {
        final userAgreed = await _showPermissionRationaleDialog(context);
        if (!userAgreed) {
          debugPrint('⚠️ SOS Permission: User declined permission rationale');
          return false;
        }
      }

      // Request permissions one by one with explanations
      for (final permission in _requiredPermissions) {
        final status = await permission.status;

        if (!status.isGranted && context.mounted) {
          final granted = await _requestSinglePermission(context, permission);
          if (!granted) {
            debugPrint('❌ SOS Permission: ${permission.toString()} denied');
            if (context.mounted) {
              await _handlePermissionDenied(context, permission);
            }
            return false;
          }
        }
      }

      // Mark that we've shown the permission flow
      await _markPermissionFlowShown();

      debugPrint('✅ SOS Permission: All required permissions granted');
      return true;
    } catch (e) {
      debugPrint('❌ SOS Permission: Error requesting permissions: $e');
      return false;
    }
  }

  /// Request a single permission with explanation
  Future<bool> _requestSinglePermission(
      BuildContext context, Permission permission) async {
    try {
      // Show explanation dialog before requesting permission
      if (!context.mounted) return false;

      final userUnderstands =
          await _showPermissionExplanationDialog(context, permission);
      if (!userUnderstands) {
        return false;
      }

      // Request the permission
      final status = await permission.request();

      return status.isGranted;
    } catch (e) {
      debugPrint(
          '❌ SOS Permission: Error requesting ${permission.toString()}: $e');
      return false;
    }
  }

  /// Show rationale dialog explaining why SOS needs permissions
  Future<bool> _showPermissionRationaleDialog(BuildContext context) async {
    final lang = AppLocalizations.of(context);

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.security, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang?.sosEmergencyPermissions ??
                          'SOS Emergency Permissions',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang?.sosEmergencyFeatureRequiresPermissions ??
                            'The SOS emergency feature requires several permissions to function properly and help you in emergency situations.',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lang?.thesePermissionsAllowAppTo ??
                            'These permissions allow the app to:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDialogPermissionItem(
                        lang?.makeEmergencyCallsToContacts ??
                            'Make emergency calls to your contacts',
                        Icons.phone,
                      ),
                      _buildDialogPermissionItem(
                        lang?.sendEmergencySMSWithLocation ??
                            'Send emergency SMS with your location',
                        Icons.sms,
                      ),
                      _buildDialogPermissionItem(
                        lang?.accessLocationForRescue ??
                            'Access your location for rescue services',
                        Icons.location_on,
                      ),
                      _buildDialogPermissionItem(
                        lang?.sendEmergencyNotifications ??
                            'Show critical emergency notifications',
                        Icons.notifications,
                      ),
                      _buildDialogPermissionItem(
                        lang?.contactsPermissionUsage ??
                            'Access your emergency contacts',
                        Icons.contacts,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lang?.usedOnlyDuringEmergencies ??
                              'Your privacy is protected - these permissions are only used during emergency situations.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(lang?.cancel ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(lang?.continueButton ?? 'Continue'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Show explanation dialog for a specific permission
  Future<bool> _showPermissionExplanationDialog(
      BuildContext context, Permission permission) async {
    final lang = AppLocalizations.of(context);
    final permissionInfo = _getPermissionInfo(context, permission);

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(permissionInfo['icon'], color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      permissionInfo['title'],
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        permissionInfo['description'],
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                permissionInfo['usage'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(lang?.skip ?? 'Skip'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(lang?.grantPermission ?? 'Grant Permission'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Get user-friendly information about a permission
  Map<String, dynamic> _getPermissionInfo(
      BuildContext context, Permission permission) {
    final lang = AppLocalizations.of(context);

    switch (permission) {
      case Permission.phone:
        return {
          'title': lang?.phonePermissionTitle ?? 'Phone Permission',
          'icon': Icons.phone,
          'description': lang?.phonePermissionDescription ??
              'Allow the app to make emergency phone calls to your emergency contacts when SOS is triggered.',
          'usage': lang?.phonePermissionUsage ??
              'Used only during emergency situations to call for help.',
        };
      case Permission.sms:
        return {
          'title': lang?.smsPermissionTitle ?? 'SMS Permission',
          'icon': Icons.sms,
          'description': lang?.smsPermissionDescription ??
              'Allow the app to send emergency SMS messages with your location to your emergency contacts.',
          'usage': lang?.smsPermissionUsage ??
              'Used only during emergencies to send your location and alert message.',
        };
      case Permission.location:
        return {
          'title': lang?.locationPermissionTitle ?? 'Location Permission',
          'icon': Icons.location_on,
          'description': lang?.locationPermissionDescription ??
              'Allow the app to access your current location to include in emergency messages.',
          'usage': lang?.locationPermissionUsage ??
              'Used only during emergencies to share your location with helpers.',
        };
      case Permission.contacts:
        return {
          'title': lang?.contactsPermissionTitle ?? 'Contacts Permission',
          'icon': Icons.contacts,
          'description': lang?.contactsPermissionDescription ??
              'Allow the app to access your saved emergency contacts to call them.',
          'usage': lang?.contactsPermissionUsage ??
              'Used only to access your pre-defined emergency contacts.',
        };
      case Permission.notification:
        return {
          'title':
              lang?.notificationPermissionTitle ?? 'Notification Permission',
          'icon': Icons.notifications,
          'description': lang?.notificationPermissionDescription ??
              'Allow the app to show critical emergency notifications and SOS status updates.',
          'usage': lang?.notificationPermissionUsage ??
              'Used to show emergency alerts and SOS service status.',
        };
      default:
        return {
          'title': lang?.permissionRequired ?? 'Permission Required',
          'icon': Icons.security,
          'description': lang?.permissionRequiredDescription ??
              'This permission is required for SOS emergency functionality.',
          'usage': lang?.usedOnlyDuringEmergencies ??
              'Used only during emergency situations.',
        };
    }
  }

  /// Handle permission denial with guidance
  Future<void> _handlePermissionDenied(
      BuildContext context, Permission permission) async {
    final status = await permission.status;

    if (!context.mounted) return;

    if (status.isPermanentlyDenied) {
      await _showPermanentlyDeniedDialog(context, permission);
    } else {
      await _showPermissionDeniedDialog(context, permission);
    }
  }

  /// Show dialog for permanently denied permissions
  Future<void> _showPermanentlyDeniedDialog(
      BuildContext context, Permission permission) async {
    final lang = AppLocalizations.of(context);
    final permissionInfo = _getPermissionInfo(context, permission);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang?.permissionRequired ?? 'Permission Required',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${permissionInfo['title']} ${lang?.hasBeenPermanentlyDenied ?? 'has been permanently denied. To enable SOS emergency functionality, please:'}',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang?.tapOpenSettingsBelow ??
                              '1. Tap "Open Settings" below',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang?.findRoadHelperInAppList ??
                              '2. Find "Road Helper" in the app list',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang?.tapPermissions ?? '3. Tap "Permissions"',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang?.enableRequiredPermission ??
                              '4. Enable the required permission',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang?.returnToApp ?? '5. Return to the app',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(lang?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text(lang?.openSettings ?? 'Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog for denied permissions (not permanent)
  Future<void> _showPermissionDeniedDialog(
      BuildContext context, Permission permission) async {
    final lang = AppLocalizations.of(context);
    final permissionInfo = _getPermissionInfo(context, permission);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(lang?.permissionNeeded ?? 'Permission Needed'),
            ],
          ),
          content: Text(
            '${permissionInfo['title']} ${lang?.isRequiredForSOSFunctionality ?? 'is required for SOS emergency functionality. Without this permission, the SOS feature may not work properly in emergency situations.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(lang?.ok ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// Check if we should show permission rationale
  Future<bool> _shouldShowPermissionRationale() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('sos_permission_flow_shown') ?? false);
  }

  /// Mark that permission flow has been shown
  Future<void> _markPermissionFlowShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_permission_flow_shown', true);
  }

  /// Check if SOS can function with current permissions
  Future<SOSPermissionStatus> getSOSPermissionStatus() async {
    final statuses = await getAllPermissionStatuses();

    int grantedRequired = 0;
    int totalRequired = _requiredPermissions.length;

    for (final permission in _requiredPermissions) {
      if (statuses[permission]?.isGranted ?? false) {
        grantedRequired++;
      }
    }

    if (grantedRequired == totalRequired) {
      return SOSPermissionStatus.fullyEnabled;
    } else if (grantedRequired > 0) {
      return SOSPermissionStatus.partiallyEnabled;
    } else {
      return SOSPermissionStatus.disabled;
    }
  }

  /// Build permission item for dialog
  Widget _buildDialogPermissionItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '• $text',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// SOS permission status enum
enum SOSPermissionStatus {
  fullyEnabled, // All required permissions granted
  partiallyEnabled, // Some permissions granted
  disabled, // No permissions granted
}
