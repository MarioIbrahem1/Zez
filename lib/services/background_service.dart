import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'sos_service.dart';

class BackgroundServiceHandler {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: false,
        notificationChannelId: 'sos_background_service',
        initialNotificationTitle: 'SOS Service Active',
        initialNotificationContent: 'Triple press power button for emergency',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Initialize device info
    final deviceInfo = DeviceInfoPlugin();
    try {
      final androidInfo = await deviceInfo.androidInfo;
      print('Android device info: ${androidInfo.model}');
    } catch (e) {
      print('Error getting device info: $e');
    }

    // Power button press detection logic
    int powerButtonPressCount = 0;
    Timer? resetTimer;

    service.on('powerButtonPressed').listen((event) {
      powerButtonPressCount++;
      resetTimer?.cancel();
      resetTimer = Timer(const Duration(seconds: 2), () {
        powerButtonPressCount = 0;
      });

      if (powerButtonPressCount >= 3) {
        SOSService().onPowerButtonPressed();
        powerButtonPressCount = 0;
      }
    });

    // Keep the service alive
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: 'SOS Service Active',
            content: 'Triple press power button for emergency',
          );
        }
      }
    });
  }
}
