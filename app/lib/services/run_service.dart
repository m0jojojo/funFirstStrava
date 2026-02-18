import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';

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
