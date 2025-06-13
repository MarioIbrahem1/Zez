import 'package:flutter_background_service/flutter_background_service.dart';

class PowerButtonService {
  static final PowerButtonService _instance = PowerButtonService._internal();
  factory PowerButtonService() => _instance;
  PowerButtonService._internal();

  Future<void> startService() async {
    try {
      final service = FlutterBackgroundService();

      // Configure the background service
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false, // Changed to false to prevent auto-start issues
          isForegroundMode:
              false, // Changed to false to avoid foreground service issues
          notificationChannelId: 'sos_background_service',
          initialNotificationTitle: 'SOS Service',
          initialNotificationContent: 'Emergency service is running',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      // Start the service
      await service.startService();
      print('Power button background service started');
    } catch (e) {
      print('Error starting power button service: $e');
    }
  }

  static void onStart(ServiceInstance service) async {
    print('Background service started');

    // Keep the service running
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  static bool onIosBackground(ServiceInstance service) {
    print('iOS background service running');
    return true;
  }

  Future<void> stopService() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
      print('Power button background service stopped');
    } catch (e) {
      print('Error stopping power button service: $e');
    }
  }
}
