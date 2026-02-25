import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'run_service.dart';

class OfflineRunService {
  static const _storageKey = 'offline_runs_v1';

  Future<void> saveRunLocally(List<PathPoint> path) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final List<dynamic> list = raw != null ? jsonDecode(raw) as List<dynamic> : <dynamic>[];
    list.add(<String, dynamic>{
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'path': path.map((p) => p.toJson()).toList(),
    });
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> _loadRawRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> _saveRawRuns(List<Map<String, dynamic>> runs) async {
    final prefs = await SharedPreferences.getInstance();
    if (runs.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, jsonEncode(runs));
    }
  }

  /// Attempts to upload all pending offline runs.
  /// Returns the number of runs successfully synced.
  Future<int> syncPendingRuns() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final idToken = await user.getIdToken(true);
    if (idToken == null) return 0;

    final runs = await _loadRawRuns();
    if (runs.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var synced = 0;

    for (final run in runs) {
      final rawPath = run['path'];
      if (rawPath is! List<dynamic> || rawPath.isEmpty) {
        continue;
      }
      final path = <PathPoint>[];
      for (final point in rawPath) {
        if (point is Map<String, dynamic>) {
          final lat = point['lat'];
          final lng = point['lng'];
          final t = point['t'];
          if (lat is num && lng is num && t is num) {
            path.add(PathPoint(lat: lat.toDouble(), lng: lng.toDouble(), t: t.toInt()));
          }
        }
      }
      if (path.isEmpty) continue;

      try {
        await submitRun(idToken, path);
        synced += 1;
      } catch (e) {
        final msg = e.toString();
        // If backend rejects the run as invalid (e.g. anti-cheat 400), drop it permanently.
        if (msg.contains('Failed to save run: 400')) {
          continue;
        }
        // For other errors (likely offline / network issues), keep remaining runs for later.
        remaining.add(run);
        break;
      }
    }

    await _saveRawRuns(remaining);
    return synced;
  }
}

