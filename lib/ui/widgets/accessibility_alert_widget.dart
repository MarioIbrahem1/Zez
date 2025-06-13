import 'package:flutter/material.dart';
import '../../services/accessibility_service.dart';

/// Widget to show accessibility service activation alert
class AccessibilityAlertWidget extends StatefulWidget {
  final bool showAsDialog;
  final VoidCallback? onDismiss;

  const AccessibilityAlertWidget({
    super.key,
    this.showAsDialog = false,
    this.onDismiss,
  });

  @override
  State<AccessibilityAlertWidget> createState() =>
      _AccessibilityAlertWidgetState();
}

class _AccessibilityAlertWidgetState extends State<AccessibilityAlertWidget> {
  bool _isCheckingStatus = false;

  Future<void> _openSettings() async {
    await AccessibilityService.openAccessibilitySettings();

    // Give user time to enable the service then check again
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'After enabling the service, return to the app and it will check automatically'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isCheckingStatus = true;
    });

    final isEnabled =
        await AccessibilityService.isAccessibilityServiceEnabled();

    setState(() {
      _isCheckingStatus = false;
    });

    if (isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ SOS Emergency Service enabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDismiss?.call();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ Service not enabled yet. Please follow the instructions.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsDialog) {
      return _buildDialog();
    } else {
      return _buildCard();
    }
  }

  Widget _buildDialog() {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AccessibilityService.getAlertTitle(),
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
                AccessibilityService.getInstructionMessage(),
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
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
                        'This service is required for the SOS emergency feature to detect triple power button presses.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
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
          onPressed: widget.onDismiss,
          child: const Text('Dismiss'),
        ),
        TextButton(
          onPressed: _isCheckingStatus ? null : _checkStatus,
          child: _isCheckingStatus
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Check Status'),
        ),
        ElevatedButton(
          onPressed: _openSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Open Settings'),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F3551)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.orange.shade600
              : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.security,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.shade400
                    : Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AccessibilityService.getAlertTitle(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.shade300
                            : Colors.orange.shade700,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Short message
          Text(
            AccessibilityService.getShortMessage(),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.orange.shade200
                  : Colors.orange.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isCheckingStatus ? null : _checkStatus,
                  icon: _isCheckingStatus
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Check Status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.shade400
                            : Colors.orange.shade700,
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.orange.shade600
                          : Colors.orange.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.shade600
                            : Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Instruction note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue.shade900.withOpacity(0.3)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue.shade600
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade400
                      : Colors.blue.shade600,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Look for "Road Helper" in the accessibility services list and enable it.',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.shade300
                          : Colors.blue.shade600,
                      fontSize: 12,
                    ),
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

/// Helper function to show accessibility alert dialog
Future<void> showAccessibilityAlert(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AccessibilityAlertWidget(
        showAsDialog: true,
        onDismiss: () => Navigator.of(context).pop(),
      );
    },
  );
}
