import 'dart:async';
import 'package:flutter/services.dart';

class PowerButtonDetector {
  static final PowerButtonDetector _instance = PowerButtonDetector._internal();
  factory PowerButtonDetector() => _instance;
  PowerButtonDetector._internal();

  static const platform =
      MethodChannel('com.example.road_helperr/power_button');

  Function? _onTriplePressCallback;

  Future<void> initialize() async {
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      print('🔍 PowerButtonDetector: Method call received: ${call.method}');
      print('🔍 PowerButtonDetector: Arguments: ${call.arguments}');
      print(
          '🔍 PowerButtonDetector: Callback is set: ${_onTriplePressCallback != null}');

      switch (call.method) {
        case 'onScreenStateChanged':
          final bool isScreenOn = call.arguments as bool;
          print('📱 PowerButtonDetector: Screen state changed: $isScreenOn');
          _handleScreenStateChange(isScreenOn);
          break;
        case 'onTriplePowerPress':
          print(
              '🚨 PowerButtonDetector: Triple power press detected from accessibility service');
          if (_onTriplePressCallback != null) {
            print('🚨 PowerButtonDetector: Calling SOS callback...');
            _onTriplePressCallback?.call();
            print('🚨 PowerButtonDetector: SOS callback called successfully');
          } else {
            print('❌ PowerButtonDetector: No callback set for triple press!');
          }
          break;
        default:
          print('❓ PowerButtonDetector: Unknown method: ${call.method}');
      }
    } catch (e) {
      print('❌ PowerButtonDetector: Error handling method call: $e');
    }
  }

  void _handleScreenStateChange(bool isScreenOn) {
    // Android side now handles the counting, this is just for logging
    print(
        '📱 PowerButtonDetector: Screen state changed: $isScreenOn (Android handles counting)');

    // No need to count here anymore since Android does the smart counting
    // This method is now mainly for debugging and potential future use
  }

  void setTriplePressCallback(Function callback) {
    print('🔧 PowerButtonDetector: Setting triple press callback');
    _onTriplePressCallback = callback;
    print(
        '🔧 PowerButtonDetector: Callback set successfully. Callback is null: ${_onTriplePressCallback == null}');
  }
}
