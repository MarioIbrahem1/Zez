import 'dart:async';
import 'package:flutter/services.dart';
import 'direct_sms_status_listener.dart';

class DirectSmsService {
  static const platform = MethodChannel('com.example.road_helperr/direct_sms');
  static const statusChannel =
      MethodChannel('com.example.road_helperr/sms_status');

  // Callback for SMS status changes
  Function(SmsStatus)? onSmsStatusChanged;

  DirectSmsService() {
    // Set up status channel listener
    statusChannel.setMethodCallHandler(_handleStatusCall);
  }

  Future<dynamic> _handleStatusCall(MethodCall call) async {
    if (call.method == 'onSmsSentStatus') {
      final Map<dynamic, dynamic> data = call.arguments;
      final status = SmsStatus(
        success: data['success'] ?? false,
        phoneNumber: data['phoneNumber'] ?? '',
        simId: data['simId'] ?? -1,
        errorReason: data['errorReason'] ?? '',
        isRetry: data['isRetry'] ?? false,
      );

      onSmsStatusChanged?.call(status);
    }
  }

  Future<bool> sendDirectSms({
    required String phoneNumber,
    required String message,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    try {
      final Completer<bool> completer = Completer<bool>();
      Timer? timeoutTimer;

      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // Set up status listener for this specific SMS
      Function(SmsStatus)? originalCallback = onSmsStatusChanged;
      onSmsStatusChanged = (SmsStatus status) {
        if (status.phoneNumber == phoneNumber) {
          if (!completer.isCompleted) {
            completer.complete(status.success);
          }
          timeoutTimer?.cancel();
        }
        // Also call the original callback if it exists
        originalCallback?.call(status);
      };

      // Send the SMS
      final bool result = await platform.invokeMethod('sendDirectSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });

      // If the method call itself failed, complete immediately
      if (!result) {
        timeoutTimer.cancel();
        onSmsStatusChanged = originalCallback;
        return false;
      }

      // Wait for the actual SMS status or timeout
      final bool success = await completer.future;

      // Restore original callback
      onSmsStatusChanged = originalCallback;

      return success;
    } catch (e) {
      print('Error in DirectSmsService.sendDirectSms: $e');
      return false;
    }
  }
}
