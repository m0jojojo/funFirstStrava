import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

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
      _path.add(
        PathPoint(
          lat: pos.latitude,
          lng: pos.longitude,
          t: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      notifyListeners();
    } catch (_) {}

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final pos = await geo.Geolocator.getCurrentPosition();
        if (!_isRunning) return;
        _path.add(
          PathPoint(
            lat: pos.latitude,
            lng: pos.longitude,
            t: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        notifyListeners();
      } catch (_) {}
    });

    return null;
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
    notifyListeners();

    if (_path.isEmpty) {
      return const RunStopResult(
        success: false,
        points: 0,
        savedOffline: false,
        message: 'No points recorded',
      );
    }

    final pathToSubmit = List<PathPoint>.from(_path);
    _path.clear();
    notifyListeners();

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

