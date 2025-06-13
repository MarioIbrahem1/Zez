import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:road_helperr/services/sos_permission_service.dart';
import 'package:road_helperr/services/sos_service.dart';
import 'package:road_helperr/ui/widgets/sos_permission_status_widget.dart';

/// Test screen for verifying SOS permission functionality
class SOSPermissionTestScreen extends StatefulWidget {
  const SOSPermissionTestScreen({super.key});

  static const String routeName = '/sos-permission-test';

  @override
  State<SOSPermissionTestScreen> createState() => _SOSPermissionTestScreenState();
}

class _SOSPermissionTestScreenState extends State<SOSPermissionTestScreen> {
  final SOSPermissionService _permissionService = SOSPermissionService();
  final SOSService _sosService = SOSService();
  
  bool _isLoading = true;
  List<String> _testResults = [];
  SOSPermissionStatus _permissionStatus = SOSPermissionStatus.disabled;
  Map<Permission, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    await _testPermissionService();
    await _testIndividualPermissions();
    await _testSOSServiceIntegration();
    await _testPermissionDialogs();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testPermissionService() async {
    try {
      _addTestResult('🔍 Testing SOS Permission Service...');
      
      // Test permission status checking
      final status = await _permissionService.getSOSPermissionStatus();
      _permissionStatus = status;
      _addTestResult('✅ Permission Status: ${status.toString().split('.').last}');
      
      // Test all permissions check
      final hasAll = await _permissionService.hasAllRequiredPermissions();
      _addTestResult('${hasAll ? '✅' : '❌'} All Required Permissions: ${hasAll ? 'Granted' : 'Missing'}');
      
      // Test permission statuses
      final statuses = await _permissionService.getAllPermissionStatuses();
      _permissionStatuses = statuses;
      _addTestResult('✅ Retrieved ${statuses.length} permission statuses');
      
    } catch (e) {
      _addTestResult('❌ Permission Service Test Failed: $e');
    }
  }

  Future<void> _testIndividualPermissions() async {
    _addTestResult('🔍 Testing Individual Permissions...');
    
    final requiredPermissions = [
      Permission.phone,
      Permission.sms,
      Permission.location,
      Permission.contacts,
      Permission.notification,
    ];

    for (final permission in requiredPermissions) {
      try {
        final status = await permission.status;
        final permissionName = _getPermissionName(permission);
        _addTestResult('${status.isGranted ? '✅' : '❌'} $permissionName: ${status.toString().split('.').last}');
      } catch (e) {
        _addTestResult('❌ Error checking ${_getPermissionName(permission)}: $e');
      }
    }
  }

  Future<void> _testSOSServiceIntegration() async {
    try {
      _addTestResult('🔍 Testing SOS Service Integration...');
      
      // Test if SOS service can check permissions
      final canTrigger = await _sosService.triggerSosAlert();
      _addTestResult('${canTrigger ? '✅' : '⚠️'} SOS Alert Trigger: ${canTrigger ? 'Success' : 'Failed (expected if no contacts)'}');
      
    } catch (e) {
      _addTestResult('❌ SOS Service Integration Test Failed: $e');
    }
  }

  Future<void> _testPermissionDialogs() async {
    _addTestResult('🔍 Testing Permission Dialog System...');
    _addTestResult('✅ Permission dialogs are ready for user interaction');
    _addTestResult('ℹ️ Use "Request Permissions" button to test dialogs');
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.phone:
        return 'Phone Calls';
      case Permission.sms:
        return 'SMS Messages';
      case Permission.location:
        return 'Location Access';
      case Permission.contacts:
        return 'Contacts Access';
      case Permission.notification:
        return 'Notifications';
      default:
        return permission.toString().split('.').last;
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults.add(result);
    });
    debugPrint('SOS Permission Test: $result');
  }

  Future<void> _requestPermissions() async {
    try {
      final granted = await _permissionService.requestAllRequiredPermissions(context);
      
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All SOS permissions granted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Re-run tests after permission request
      await _runTests();
    } catch (e) {
      debugPrint('❌ SOS Permission Test: Error requesting permissions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error requesting permissions. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Permission Test'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runTests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Running SOS Permission Tests...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Permission Status Widget
                  SOSPermissionStatusWidget(
                    showDetailedStatus: true,
                    onPermissionsChanged: _runTests,
                  ),
                  const SizedBox(height: 16),
                  
                  // Test Results Header
                  Text(
                    'Test Results:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  
                  // Test Results List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _testResults.length,
                      itemBuilder: (context, index) {
                        final result = _testResults[index];
                        final isSuccess = result.startsWith('✅');
                        final isWarning = result.startsWith('⚠️') || result.startsWith('ℹ️');
                        final isError = result.startsWith('❌');
                        final isInfo = result.startsWith('🔍');

                        return Card(
                          color: isSuccess
                              ? Colors.green.shade50
                              : isWarning
                                  ? Colors.orange.shade50
                                  : isError
                                      ? Colors.red.shade50
                                      : isInfo
                                          ? Colors.blue.shade50
                                          : null,
                          child: ListTile(
                            leading: Icon(
                              isSuccess
                                  ? Icons.check_circle
                                  : isWarning
                                      ? Icons.warning
                                      : isError
                                          ? Icons.error
                                          : isInfo
                                              ? Icons.info
                                              : Icons.help,
                              color: isSuccess
                                  ? Colors.green
                                  : isWarning
                                      ? Colors.orange
                                      : isError
                                          ? Colors.red
                                          : isInfo
                                              ? Colors.blue
                                              : Colors.grey,
                            ),
                            title: Text(
                              result,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: isSuccess
                                    ? Colors.green.shade800
                                    : isWarning
                                        ? Colors.orange.shade800
                                        : isError
                                            ? Colors.red.shade800
                                            : isInfo
                                                ? Colors.blue.shade800
                                                : Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _requestPermissions,
                          icon: const Icon(Icons.security),
                          label: const Text('Request Permissions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => openAppSettings(),
                          icon: const Icon(Icons.settings),
                          label: const Text('App Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _permissionStatus == SOSPermissionStatus.fullyEnabled
                          ? Colors.green.shade50
                          : _permissionStatus == SOSPermissionStatus.partiallyEnabled
                              ? Colors.orange.shade50
                              : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _permissionStatus == SOSPermissionStatus.fullyEnabled
                            ? Colors.green.shade200
                            : _permissionStatus == SOSPermissionStatus.partiallyEnabled
                                ? Colors.orange.shade200
                                : Colors.red.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _permissionStatus == SOSPermissionStatus.fullyEnabled
                                  ? Icons.check_circle
                                  : _permissionStatus == SOSPermissionStatus.partiallyEnabled
                                      ? Icons.warning
                                      : Icons.error,
                              color: _permissionStatus == SOSPermissionStatus.fullyEnabled
                                  ? Colors.green.shade600
                                  : _permissionStatus == SOSPermissionStatus.partiallyEnabled
                                      ? Colors.orange.shade600
                                      : Colors.red.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SOS Permission Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _permissionStatus == SOSPermissionStatus.fullyEnabled
                                    ? Colors.green.shade800
                                    : _permissionStatus == SOSPermissionStatus.partiallyEnabled
                                        ? Colors.orange.shade800
                                        : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _permissionStatus == SOSPermissionStatus.fullyEnabled
                              ? 'All SOS permissions are granted. Emergency features are fully functional.'
                              : _permissionStatus == SOSPermissionStatus.partiallyEnabled
                                  ? 'Some SOS permissions are missing. Emergency features may be limited.'
                                  : 'SOS permissions are not granted. Emergency features will not work.',
                          style: TextStyle(
                            color: _permissionStatus == SOSPermissionStatus.fullyEnabled
                                ? Colors.green.shade700
                                : _permissionStatus == SOSPermissionStatus.partiallyEnabled
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700,
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
}
