import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for run path during foreground service. Shared with RunTracker.
const String runPathStorageKey = 'background_run_path_v1';

/// Top-level callback for foreground task. Required by flutter_foreground_task.
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(RunLocationTaskHandler());
}

/// Task handler that runs in foreground service isolate. Samples GPS every ~4s
/// and persists path to SharedPreferences so RunTracker can read it on stop.
class RunLocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[RunLocationTaskHandler] onStart');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _sampleAndStore();
  }

  Future<void> _sampleAndStore() async {
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final point = <String, dynamic>{
        'lat': pos.latitude,
        'lng': pos.longitude,
        't': DateTime.now().millisecondsSinceEpoch,
      };
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(runPathStorageKey);
      final list = raw != null
          ? (jsonDecode(raw) as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
              <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[];
      list.add(point);
      await prefs.setString(runPathStorageKey, jsonEncode(list));
      FlutterForegroundTask.sendDataToMain({'count': list.length});
    } catch (_) {}
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[RunLocationTaskHandler] onDestroy isTimeout=$isTimeout');
    }
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}
