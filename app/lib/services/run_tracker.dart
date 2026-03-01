import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

import '../platform_utils_stub.dart'
    if (dart.library.io) '../platform_utils_io.dart' as platform;
import 'location_task_handler.dart';
import 'offline_run_service.dart';
import 'run_service.dart';

class RunTracker extends ChangeNotifier {
  RunTracker._();

  static final RunTracker instance = RunTracker._();

  bool _isRunning = false;
  final List<PathPoint> _path = [];
  Timer? _timer;

  bool get isRunning => _isRunning;
  List<PathPoint> get path => List.unmodifiable(_path);

  Future<String?> start() async {
    if (_isRunning) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'Sign in to record runs';
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return 'Location permission needed';
    }

    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return 'Enable location services';
    }

    _isRunning = true;
    _path.clear();
    notifyListeners();

    try {
      final pos = await geo.Geolocator.getCurrentPosition();
      final point = PathPoint(
        lat: pos.latitude,
        lng: pos.longitude,
        t: DateTime.now().millisecondsSinceEpoch,
      );
      _path.add(point);
      notifyListeners();

      // On Android: start foreground service (keeps process alive when backgrounded)
      // and timer in main isolate (Geolocator only works reliably here)
      if (platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          runPathStorageKey,
          jsonEncode([{'lat': point.lat, 'lng': point.lng, 't': point.t}]),
        );
        await _startForegroundService();
        _startTimer(); // main-isolate timer so points keep increasing
      } else {
        _startTimer();
      }
    } catch (_) {
      if (platform.isAndroid) {
        await _startForegroundService();
        _startTimer();
      } else {
        _startTimer();
      }
    }

    return null;
  }

  Future<void> _startForegroundService() async {
    _timer?.cancel();
    try {
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      final running = await FlutterForegroundTask.isRunningService;
      if (running) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Run active',
          notificationText: 'Tracking your run',
          callback: startLocationTaskCallback,
          serviceId: 256,
          serviceTypes: [ForegroundServiceTypes.location],
        );
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final pos = await geo.Geolocator.getCurrentPosition();
        if (!_isRunning) return;
        final point = PathPoint(
          lat: pos.latitude,
          lng: pos.longitude,
          t: DateTime.now().millisecondsSinceEpoch,
        );
        _path.add(point);
        if (platform.isAndroid) {
          await _appendPointToStorage(point);
        }
        notifyListeners();
      } catch (_) {}
    });
  }

  Future<void> _appendPointToStorage(PathPoint point) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(runPathStorageKey);
      final list = raw != null
          ? (jsonDecode(raw) as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[];
      list.add({'lat': point.lat, 'lng': point.lng, 't': point.t});
      await prefs.setString(runPathStorageKey, jsonEncode(list));
    } catch (_) {}
  }

  /// Called when app resumes or receives data from foreground service
  /// to refresh path count for UI (FAB point count).
  Future<void> refreshPathFromStorage() async {
    if (!platform.isAndroid || !_isRunning) return;
    final loaded = await _loadPathFromStorage();
    if (loaded.length != _path.length) {
      _path.clear();
      _path.addAll(loaded);
      notifyListeners();
    }
  }

  Future<List<PathPoint>> _loadPathFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(runPathStorageKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null || list.isEmpty) return [];
      final path = <PathPoint>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final lat = e['lat'];
          final lng = e['lng'];
          final t = e['t'];
          if (lat is num && lng is num && t is num) {
            path.add(PathPoint(
              lat: lat.toDouble(),
              lng: lng.toDouble(),
              t: t.toInt(),
            ));
          }
        }
      }
      return path;
    } catch (_) {
      return List<PathPoint>.from(_path);
    }
  }

  Future<RunStopResult> stop() async {
    if (!_isRunning) {
      return const RunStopResult(
        success: false,
        points: 0,
        savedOffline: false,
        message: 'Run is not active',
      );
    }

    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    // On Android: read path from foreground service storage (it persists there)
    List<PathPoint> pathToSubmit;
    if (platform.isAndroid) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
      pathToSubmit = await _loadPathFromStorage();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(runPathStorageKey);
    } else {
      pathToSubmit = List<PathPoint>.from(_path);
      _path.clear();
    }
    _path.clear();
    notifyListeners();

    if (pathToSubmit.isEmpty) {
      return const RunStopResult(
        success: false,
        points: 0,
        savedOffline: false,
        message: 'No points recorded',
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('No token');
      await submitRun(idToken, pathToSubmit);
      await OfflineRunService().syncPendingRuns();
      return RunStopResult(
        success: true,
        points: pathToSubmit.length,
        savedOffline: false,
        message: 'Run saved (${pathToSubmit.length} points)',
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed to save run: 400')) {
        return RunStopResult(
          success: false,
          points: pathToSubmit.length,
          savedOffline: false,
          message: 'Save failed: $e',
        );
      }

      await OfflineRunService().saveRunLocally(pathToSubmit);
      return RunStopResult(
        success: true,
        points: pathToSubmit.length,
        savedOffline: true,
        message:
            'No network? Run saved offline and will sync when you are online.',
      );
    }
  }
}

class RunStopResult {
  const RunStopResult({
    required this.success,
    required this.points,
    required this.savedOffline,
    this.message,
  });

  final bool success;
  final int points;
  final bool savedOffline;
  final String? message;
}

