import 'package:flutter/material.dart';

/// Enhanced error handling for notification system
class NotificationErrorHandler {
  static const String _logPrefix = '🚨 NotificationError';

  /// Handle FCM token related errors
  static void handleTokenError(dynamic error, {String? context}) {
    final contextStr = context != null ? ' [$context]' : '';
    debugPrint('$_logPrefix$contextStr: Token Error - $error');
    
    if (error.toString().contains('PERMISSION_DENIED')) {
      debugPrint('$_logPrefix: Firebase Database permission denied. Check Firebase rules.');
    } else if (error.toString().contains('NETWORK_ERROR')) {
      debugPrint('$_logPrefix: Network error. Check internet connection.');
    } else if (error.toString().contains('TIMEOUT')) {
      debugPrint('$_logPrefix: Operation timed out. Try again later.');
    }
  }

  /// Handle FCM sending errors
  static void handleSendError(dynamic error, {String? userId, String? title}) {
    final userStr = userId != null ? ' [User: $userId]' : '';
    final titleStr = title != null ? ' [Title: $title]' : '';
    debugPrint('$_logPrefix$userStr$titleStr: Send Error - $error');
    
    if (error.toString().contains('401')) {
      debugPrint('$_logPrefix: Authentication failed. Check service account credentials.');
    } else if (error.toString().contains('400')) {
      debugPrint('$_logPrefix: Bad request. Check message format and FCM token.');
    } else if (error.toString().contains('404')) {
      debugPrint('$_logPrefix: FCM token not found or invalid.');
    } else if (error.toString().contains('429')) {
      debugPrint('$_logPrefix: Rate limit exceeded. Reduce notification frequency.');
    } else if (error.toString().contains('500')) {
      debugPrint('$_logPrefix: FCM server error. Try again later.');
    }
  }

  /// Handle Firebase Database errors
  static void handleDatabaseError(dynamic error, {String? operation}) {
    final opStr = operation != null ? ' [$operation]' : '';
    debugPrint('$_logPrefix$opStr: Database Error - $error');
    
    if (error.toString().contains('PERMISSION_DENIED')) {
      debugPrint('$_logPrefix: Database permission denied. Check Firebase rules:');
      debugPrint('$_logPrefix: Suggested rules: {"rules": {".read": true, ".write": true}}');
    } else if (error.toString().contains('NETWORK_ERROR')) {
      debugPrint('$_logPrefix: Database network error. Check Firebase configuration.');
    }
  }

  /// Handle authentication errors
  static void handleAuthError(dynamic error, {String? context}) {
    final contextStr = context != null ? ' [$context]' : '';
    debugPrint('$_logPrefix$contextStr: Auth Error - $error');
    
    if (error.toString().contains('user-not-found')) {
      debugPrint('$_logPrefix: User not found. Check user authentication state.');
    } else if (error.toString().contains('invalid-credential')) {
      debugPrint('$_logPrefix: Invalid credentials. Re-authenticate user.');
    }
  }

  /// Handle general notification errors
  static void handleGeneralError(dynamic error, {String? context, String? operation}) {
    final contextStr = context != null ? ' [$context]' : '';
    final opStr = operation != null ? ' [$operation]' : '';
    debugPrint('$_logPrefix$contextStr$opStr: General Error - $error');
  }

  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'إعدادات الصلاحيات غير صحيحة. يرجى المحاولة مرة أخرى.';
    } else if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'مشكلة في الاتصال بالإنترنت. تحقق من اتصالك وحاول مرة أخرى.';
    } else if (errorStr.contains('timeout')) {
      return 'انتهت مهلة العملية. يرجى المحاولة مرة أخرى.';
    } else if (errorStr.contains('token')) {
      return 'مشكلة في إعدادات الإشعارات. يرجى إعادة تسجيل الدخول.';
    } else if (errorStr.contains('auth')) {
      return 'مشكلة في المصادقة. يرجى إعادة تسجيل الدخول.';
    } else if (errorStr.contains('rate limit') || errorStr.contains('429')) {
      return 'تم إرسال إشعارات كثيرة. يرجى الانتظار قليلاً.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'مشكلة في الخادم. يرجى المحاولة لاحقاً.';
    } else {
      return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    }
  }

  /// Log detailed error information for debugging
  static void logDetailedError({
    required dynamic error,
    String? context,
    String? operation,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) {
    debugPrint('$_logPrefix: ========== DETAILED ERROR LOG ==========');
    debugPrint('$_logPrefix: Context: ${context ?? 'Unknown'}');
    debugPrint('$_logPrefix: Operation: ${operation ?? 'Unknown'}');
    debugPrint('$_logPrefix: User ID: ${userId ?? 'Unknown'}');
    debugPrint('$_logPrefix: Error Type: ${error.runtimeType}');
    debugPrint('$_logPrefix: Error Message: $error');
    
    if (additionalData != null) {
      debugPrint('$_logPrefix: Additional Data:');
      additionalData.forEach((key, value) {
        debugPrint('$_logPrefix:   $key: $value');
      });
    }
    
    debugPrint('$_logPrefix: Stack Trace: ${StackTrace.current}');
    debugPrint('$_logPrefix: Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('$_logPrefix: ==========================================');
  }

  /// Check if error is recoverable
  static bool isRecoverableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Network errors are usually recoverable
    if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('timeout')) {
      return true;
    }
    
    // Rate limit errors are recoverable after waiting
    if (errorStr.contains('rate limit') || errorStr.contains('429')) {
      return true;
    }
    
    // Server errors might be temporary
    if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) {
      return true;
    }
    
    // Authentication errors might be recoverable with re-auth
    if (errorStr.contains('auth') && !errorStr.contains('invalid')) {
      return true;
    }
    
    return false;
  }

  /// Get suggested retry delay based on error type
  static Duration getRetryDelay(dynamic error, int attemptNumber) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('rate limit') || errorStr.contains('429')) {
      // Exponential backoff for rate limits
      return Duration(seconds: (attemptNumber * attemptNumber) * 5);
    } else if (errorStr.contains('network') || errorStr.contains('timeout')) {
      // Linear backoff for network issues
      return Duration(seconds: attemptNumber * 2);
    } else if (errorStr.contains('500')) {
      // Server errors - wait longer
      return Duration(seconds: attemptNumber * 10);
    } else {
      // Default backoff
      return Duration(seconds: attemptNumber * 3);
    }
  }

  /// Show error dialog to user
  static void showErrorDialog(BuildContext context, dynamic error, {String? title}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'خطأ في الإشعارات'),
        content: Text(getUserFriendlyMessage(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar to user
  static void showErrorSnackbar(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getUserFriendlyMessage(error)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'إغلاق',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Common error patterns and their solutions
  static const Map<String, String> errorSolutions = {
    'PERMISSION_DENIED': 'تحقق من قواعد Firebase Database وصلاحيات التطبيق',
    'NETWORK_ERROR': 'تحقق من اتصال الإنترنت وإعدادات Firebase',
    'TOKEN_ERROR': 'أعد تسجيل الدخول لتحديث رمز الإشعارات',
    'AUTH_ERROR': 'أعد تسجيل الدخول للمصادقة',
    'RATE_LIMIT': 'انتظر قليلاً قبل إرسال إشعارات أخرى',
    'SERVER_ERROR': 'مشكلة مؤقتة في الخادم، حاول لاحقاً',
    'INVALID_TOKEN': 'رمز الإشعارات غير صالح، أعد تسجيل الدخول',
    'CONFIGURATION_ERROR': 'تحقق من إعدادات Firebase في التطبيق',
  };

  /// Get solution for specific error
  static String? getSolution(dynamic error) {
    final errorStr = error.toString().toUpperCase();
    
    for (final pattern in errorSolutions.keys) {
      if (errorStr.contains(pattern)) {
        return errorSolutions[pattern];
      }
    }
    
    return null;
  }
}
