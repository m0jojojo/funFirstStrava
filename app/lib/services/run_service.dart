import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/api_config.dart';

/// Summary of a run as returned by GET /runs/me.
class RunSummary {
  const RunSummary({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.pathLength,
    this.distanceMeters,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int pathLength;
  /// Total path distance in meters. Null if not provided (e.g. old API).
  final double? distanceMeters;

  static RunSummary fromJson(Map<String, dynamic> json) {
    double? dist;
    if (json['distanceMeters'] != null && json['distanceMeters'] is num) {
      dist = (json['distanceMeters'] as num).toDouble();
    }
    return RunSummary(
      id: json['id']?.toString() ?? '',
      startedAt: _parseDate(json['startedAt']),
      endedAt: _parseDate(json['endedAt']),
      pathLength: (json['pathLength'] is num) ? (json['pathLength'] as num).toInt() : 0,
      distanceMeters: dist,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DateTime.now();
  }
}

/// One point in a run path: lat, lng, timestamp (ms since epoch).
class PathPoint {
  const PathPoint({required this.lat, required this.lng, required this.t});

  final double lat;
  final double lng;
  final int t;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 't': t};
}

/// Submits a run to the backend. Requires [idToken] (Firebase ID token) for auth.
Future<void> submitRun(String idToken, List<PathPoint> path) async {
  if (path.isEmpty) throw Exception('Run path is empty');
  final uri = Uri.parse('$apiBaseUrl/runs');
  final body = jsonEncode({'path': path.map((p) => p.toJson()).toList()});
  final response = await http.post(
    uri,
    body: body,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    },
  );
  if (response.statusCode != 201) {
    throw Exception('Failed to save run: ${response.statusCode}');
  }
}

/// Total path distance in meters (Haversine sum over consecutive points).
double pathDistanceMeters(List<PathPoint> path) {
  if (path.length < 2) return 0;
  double total = 0;
  for (int i = 1; i < path.length; i++) {
    total += _haversineM(
      path[i - 1].lat,
      path[i - 1].lng,
      path[i].lat,
      path[i].lng,
    );
  }
  return total;
}

double _haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0; // Earth radius in meters
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Fetches the current user's runs from GET /runs/me. Requires [idToken] for auth.
Future<List<RunSummary>> fetchMyRuns(String idToken) async {
  final uri = Uri.parse('$apiBaseUrl/runs/me');
  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $idToken',
    },
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to load runs: ${response.statusCode}');
  }
  final list = jsonDecode(response.body);
  if (list is! List) return [];
  return list
      .whereType<Map<String, dynamic>>()
      .map((e) => RunSummary.fromJson(e))
      .toList();
}
