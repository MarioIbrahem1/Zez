import 'package:flutter/services.dart';

class SimService {
  static const platform = MethodChannel('com.example.road_helperr/sim_service');

  Future<bool> hasDualSim() async {
    try {
      final bool result = await platform.invokeMethod('hasDualSim');
      return result;
    } catch (e) {
      print('Error checking dual SIM: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSimInfo() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getSimInfo');
      return result.map((sim) => Map<String, dynamic>.from(sim)).toList();
    } catch (e) {
      print('Error getting SIM info: $e');
      return [];
    }
  }

  Future<int> getActiveSimCount() async {
    try {
      final int result = await platform.invokeMethod('getActiveSimCount');
      return result;
    } catch (e) {
      print('Error getting active SIM count: $e');
      return 0;
    }
  }
}
