import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:road_helperr/services/sos_permission_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Widget that displays SOS permission status and allows users to manage permissions
class SOSPermissionStatusWidget extends StatefulWidget {
  final VoidCallback? onPermissionsChanged;
  final bool showDetailedStatus;

  const SOSPermissionStatusWidget({
    super.key,
    this.onPermissionsChanged,
    this.showDetailedStatus = false,
  });

  @override
  State<SOSPermissionStatusWidget> createState() =>
      _SOSPermissionStatusWidgetState();
}

class _SOSPermissionStatusWidgetState extends State<SOSPermissionStatusWidget> {
  final SOSPermissionService _permissionService = SOSPermissionService();
  SOSPermissionStatus _status = SOSPermissionStatus.disabled;
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _isLoading = true;

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
      final statuses = await _permissionService.getAllPermissionStatuses();

      setState(() {
        _status = status;
        _permissionStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ SOS Permission Widget: Error checking status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final granted =
          await _permissionService.requestAllRequiredPermissions(context);

      if (granted && mounted) {
        final lang = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ${lang?.allSOSPermissionsGrantedSuccessfully ?? 'All SOS permissions granted successfully!'}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _checkPermissionStatus();
      widget.onPermissionsChanged?.call();
    } catch (e) {
      debugPrint('❌ SOS Permission Widget: Error requesting permissions: $e');
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context);

    if (_isLoading) {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lang?.checkingSOSPermissions ?? 'Checking SOS permissions...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // إخفاء الـ widget عندما تكون جميع الأذونات مُمنوحة
    // إلا إذا كان showDetailedStatus مفعل (في صفحة الإعدادات)
    if (_status == SOSPermissionStatus.fullyEnabled &&
        !widget.showDetailedStatus) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 16),
            _buildStatusDescription(),
            if (widget.showDetailedStatus) ...[
              const SizedBox(height: 20),
              _buildDetailedPermissionList(),
            ],
            const SizedBox(height: 20),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final lang = AppLocalizations.of(context);
    IconData icon;
    Color color;
    String title;

    switch (_status) {
      case SOSPermissionStatus.fullyEnabled:
        icon = Icons.check_circle;
        color = Colors.green;
        title = lang?.sosFullyEnabled ?? 'SOS Fully Enabled';
        break;
      case SOSPermissionStatus.partiallyEnabled:
        icon = Icons.warning;
        color = Colors.orange;
        title = lang?.sosPartiallyEnabled ?? 'SOS Partially Enabled';
        break;
      case SOSPermissionStatus.disabled:
        icon = Icons.error;
        color = Colors.red;
        title = lang?.sosDisabled ?? 'SOS Disabled';
        break;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDescription() {
    final lang = AppLocalizations.of(context);
    String description;

    switch (_status) {
      case SOSPermissionStatus.fullyEnabled:
        description = lang?.allRequiredPermissionsGranted ??
            'All required permissions are granted. SOS emergency feature is ready to use.';
        break;
      case SOSPermissionStatus.partiallyEnabled:
        description = lang?.somePermissionsMissing ??
            'Some permissions are missing. SOS functionality may be limited.';
        break;
      case SOSPermissionStatus.disabled:
        description = lang?.sosPermissionsNotGranted ??
            'SOS permissions are not granted. Emergency features will not work.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        description,
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey[700],
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDetailedPermissionList() {
    final lang = AppLocalizations.of(context);
    final requiredPermissions = [
      Permission.phone,
      Permission.sms,
      Permission.location,
      Permission.contacts,
      Permission.notification,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                lang?.permissionDetails ?? 'Permission Details:',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...requiredPermissions
              .map((permission) => _buildPermissionItem(permission)),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(Permission permission) {
    final lang = AppLocalizations.of(context);
    final status = _permissionStatuses[permission] ?? PermissionStatus.denied;
    final isGranted = status.isGranted;

    String permissionName;
    IconData permissionIcon;

    switch (permission) {
      case Permission.phone:
        permissionName = lang?.phonePermission ?? 'Phone Calls';
        permissionIcon = Icons.phone;
        break;
      case Permission.sms:
        permissionName = lang?.smsPermission ?? 'SMS Messages';
        permissionIcon = Icons.sms;
        break;
      case Permission.location:
        permissionName = lang?.locationPermission ?? 'Location Access';
        permissionIcon = Icons.location_on;
        break;
      case Permission.contacts:
        permissionName = lang?.contactsPermission ?? 'Contacts Access';
        permissionIcon = Icons.contacts;
        break;
      case Permission.notification:
        permissionName = lang?.notificationPermission ?? 'Notifications';
        permissionIcon = Icons.notifications;
        break;
      default:
        permissionName = permission.toString().split('.').last;
        permissionIcon = Icons.security;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGranted
            ? Colors.green.withOpacity(0.05)
            : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGranted
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              permissionIcon,
              size: 22,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              permissionName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isGranted ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGranted ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isGranted
                      ? (lang?.granted ?? 'Granted')
                      : (lang?.denied ?? 'Denied'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final lang = AppLocalizations.of(context);

    switch (_status) {
      case SOSPermissionStatus.fullyEnabled:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _checkPermissionStatus,
            icon: const Icon(Icons.refresh, size: 20),
            label: Text(
              lang?.refreshStatus ?? 'Refresh Status',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case SOSPermissionStatus.partiallyEnabled:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _requestPermissions,
            icon: const Icon(Icons.security, size: 20),
            label: Text(
              lang?.grantMissingPermissions ?? 'Grant Missing Permissions',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case SOSPermissionStatus.disabled:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _requestPermissions,
            icon: const Icon(Icons.security, size: 20),
            label: Text(
              lang?.enableSOSPermissions ?? 'Enable SOS Permissions',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
    }
  }
}
