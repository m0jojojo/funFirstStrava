import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_config.dart';
import '../../services/run_service.dart';

/// Full-screen map (Mapbox). Android/iOS only; requires ACCESS_TOKEN via --dart-define.
/// Fetches tiles from backend and draws them as a fill layer (Phase 5.3).
/// Run tracking (5.4): Start/Stop run records GPS path and POSTs to backend.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  String? _tilesError;
  bool _tilesLayerAdded = false;
  bool _isLoadingTiles = false;

  io.Socket? _tilesSocket;

  bool _isRunning = false;
  List<PathPoint> _path = [];
  Timer? _runTimer;

  /// Default center: Sector 40 Gurgaon (play area). Position is (lng, lat).
  static const double _defaultLng = 77.054319;
  static const double _defaultLat = 28.449841;
  static const double _defaultZoom = 14.0;

  static const String _tilesSourceIdNeutral = 'tiles-neutral';
  static const String _tilesSourceIdYours = 'tiles-yours';
  static const String _tilesSourceIdOthers = 'tiles-others';
  static const String _tilesLayerIdNeutral = 'tiles-fill-neutral';
  static const String _tilesLayerIdYours = 'tiles-fill-yours';
  static const String _tilesLayerIdOthers = 'tiles-fill-others';
  static const String _emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

  DateTime? _lastTilesRefreshAt;
  static const _tilesRefreshDebounce = Duration(seconds: 2);

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _tryCenterOnUserLocation();
  }

  void _onStyleLoaded(StyleLoadedEventData eventData) {
    _loadTilesAndAddLayer();
    // Also try to center when style is ready (e.g. second time opening map, or slow GPS).
    _tryCenterOnUserLocation();
  }

  /// Center map on user location (Phase 5.2). Request permission and flyTo.
  Future<void> _tryCenterOnUserLocation() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) return;
    }
    if (!await geo.Geolocator.isLocationServiceEnabled()) return;
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      await mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: _defaultZoom,
          bearing: 0,
          pitch: 0,
        ),
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );
    } catch (_) {}
  }

  void _onMapIdle(MapIdleEventData eventData) {
    if (!_tilesLayerAdded) return;
    final now = DateTime.now();
    if (_lastTilesRefreshAt != null && now.difference(_lastTilesRefreshAt!) < _tilesRefreshDebounce) return;
    _lastTilesRefreshAt = now;
    _refreshTilesData();
  }

  Future<void> _loadTilesAndAddLayer() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    if (_isLoadingTiles) return;
    _isLoadingTiles = true;

    setState(() => _tilesError = null);

    try {
      final result = await _fetchTilesNear(_defaultLat, _defaultLng);
      final list = result.tiles;
      final currentUserId = result.currentUserId;
      final three = (list != null && list.isNotEmpty)
          ? _tilesToGeoJsonThree(list, currentUserId)
          : (neutral: _emptyGeoJson, yours: _emptyGeoJson, others: _emptyGeoJson);

      if (list == null || list.isEmpty) {
        if (kDebugMode) debugPrint('[Tiles] Load: no tiles (check API_BASE_URL=$apiBaseUrl and backend)');
        if (mounted) setState(() => _tilesError = 'No tiles in this area');
      } else if (kDebugMode) {
        debugPrint('[Tiles] Load: ${list.length} tiles → neutral/yours/others');
      }

      try {
        for (final id in [_tilesLayerIdOthers, _tilesLayerIdYours, _tilesLayerIdNeutral]) {
          try { await mapboxMap.style.removeStyleLayer(id); } catch (_) {}
        }
        for (final id in [_tilesSourceIdOthers, _tilesSourceIdYours, _tilesSourceIdNeutral]) {
          try { await mapboxMap.style.removeStyleSource(id); } catch (_) {}
        }
        await mapboxMap.style.addSource(GeoJsonSource(id: _tilesSourceIdNeutral, data: three.neutral ?? _emptyGeoJson));
        await mapboxMap.style.addSource(GeoJsonSource(id: _tilesSourceIdYours, data: three.yours ?? _emptyGeoJson));
        await mapboxMap.style.addSource(GeoJsonSource(id: _tilesSourceIdOthers, data: three.others ?? _emptyGeoJson));
        await mapboxMap.style.addLayer(FillLayer(
          id: _tilesLayerIdNeutral,
          sourceId: _tilesSourceIdNeutral,
          fillColor: Colors.grey.withOpacity(0.35).value,
          fillOpacity: 0.5,
          fillOutlineColor: Colors.grey.value,
        ));
        await mapboxMap.style.addLayer(FillLayer(
          id: _tilesLayerIdYours,
          sourceId: _tilesSourceIdYours,
          fillColor: Colors.blue.withOpacity(0.4).value,
          fillOpacity: 0.6,
          fillOutlineColor: Colors.blue.value,
        ));
        await mapboxMap.style.addLayer(FillLayer(
          id: _tilesLayerIdOthers,
          sourceId: _tilesSourceIdOthers,
          fillColor: Colors.red.withOpacity(0.4).value,
          fillOpacity: 0.6,
          fillOutlineColor: Colors.red.value,
        ));
        if (mounted) setState(() => _tilesLayerAdded = true);
      } catch (e) {
        if (mounted) setState(() => _tilesError = 'Layer: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Tiles] Fetch failed: $e');
      if (mounted) setState(() => _tilesError = 'Fetch: $e');
    } finally {
      _isLoadingTiles = false;
    }
  }

  /// Refresh tile source data when map moves and after run save.
  Future<void> _refreshTilesData() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || !_tilesLayerAdded) return;
    try {
      double lat = _defaultLat;
      double lng = _defaultLng;
      try {
        final state = await mapboxMap.getCameraState();
        final pos = state.center?.coordinates;
        if (pos != null) {
          lat = (pos.lat as num).toDouble();
          lng = (pos.lng as num).toDouble();
        }
      } catch (_) {}
      final result = await _fetchTilesNear(lat, lng);
      if (result.tiles == null || !mounted) return;
      // Don't overwrite with empty when camera moved outside play area (e.g. flyTo to user location).
      if (result.tiles!.isEmpty) return;
      final three = _tilesToGeoJsonThree(result.tiles!, result.currentUserId);
      final neutralSrc = await mapboxMap.style.getSource(_tilesSourceIdNeutral);
      final yoursSrc = await mapboxMap.style.getSource(_tilesSourceIdYours);
      final othersSrc = await mapboxMap.style.getSource(_tilesSourceIdOthers);
      if (neutralSrc is GeoJsonSource) await neutralSrc.updateGeoJSON(three.neutral ?? _emptyGeoJson);
      if (yoursSrc is GeoJsonSource) await yoursSrc.updateGeoJSON(three.yours ?? _emptyGeoJson);
      if (othersSrc is GeoJsonSource) await othersSrc.updateGeoJSON(three.others ?? _emptyGeoJson);
      if (mounted) setState(() => _tilesError = null);
    } catch (_) {}
  }

  Future<({List<dynamic>? tiles, String? currentUserId})> _fetchTilesNear(double lat, double lng) async {
    final headers = <String, String>{};
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final nearUri = Uri.parse('$apiBaseUrl/tiles/near').replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radiusKm': '10',
      'limit': '6000',
    });
    final nearResponse = await http.get(nearUri, headers: headers.isEmpty ? null : headers);
    final nearOk = nearResponse.statusCode == 200;
    if (kDebugMode) {
      debugPrint('[Tiles] GET /tiles/near lat=$lat lng=$lng → ${nearResponse.statusCode} (${nearResponse.body.length} bytes)');
    }
    if (nearOk) {
      final decoded = jsonDecode(nearResponse.body);
      if (decoded is Map<String, dynamic>) {
        final tiles = decoded['tiles'];
        final currentUserId = decoded['currentUserId']?.toString();
        if (tiles is List<dynamic>) {
          if (kDebugMode) debugPrint('[Tiles] /tiles/near → ${tiles.length} tiles, currentUserId=$currentUserId');
          return (
            tiles: tiles,
            currentUserId: currentUserId != null && currentUserId.isNotEmpty ? currentUserId : null,
          );
        }
      }
    }
    if (kDebugMode) debugPrint('[Tiles] Fallback to GET /tiles/all');
    final allUri = Uri.parse('$apiBaseUrl/tiles/all');
    final allResponse = await http.get(allUri, headers: headers.isEmpty ? null : headers);
    if (kDebugMode) debugPrint('[Tiles] GET /tiles/all → ${allResponse.statusCode}');
    if (allResponse.statusCode != 200) return (tiles: null, currentUserId: null);
    final body = jsonDecode(allResponse.body);
    List<dynamic>? list;
    String? currentUserId;
    if (body is Map<String, dynamic>) {
      list = body['tiles'] is List ? body['tiles'] as List<dynamic> : null;
      final cu = body['currentUserId']?.toString();
      if (cu != null && cu.isNotEmpty) currentUserId = cu;
    }
    if (list == null) return (tiles: null, currentUserId: null);
    if (kDebugMode) debugPrint('[Tiles] Got ${list.length} tiles (fallback), currentUserId=$currentUserId');
    return (tiles: list, currentUserId: currentUserId);
  }

  ({String? neutral, String? yours, String? others}) _tilesToGeoJsonThree(List<dynamic> list, String? currentUserId) {
    final neutralFeatures = <Map<String, dynamic>>[];
    final yoursFeatures = <Map<String, dynamic>>[];
    final othersFeatures = <Map<String, dynamic>>[];
    for (final t in list) {
      final tile = t as Map<String, dynamic>;
      final ownerIdRaw = tile['ownerId'] ?? tile['owner_id'];
      final ownerId = ownerIdRaw != null && ownerIdRaw.toString().isNotEmpty ? ownerIdRaw.toString() : null;
      final minLat = _num(tile['minLat'] ?? tile['min_lat']);
      final minLng = _num(tile['minLng'] ?? tile['min_lng']);
      final maxLat = _num(tile['maxLat'] ?? tile['max_lat']);
      final maxLng = _num(tile['maxLng'] ?? tile['max_lng']);
      if (minLat == null || minLng == null || maxLat == null || maxLng == null) continue;
      final geom = {
        'type': 'Polygon',
        'coordinates': [
          [
            [minLng, minLat],
            [maxLng, minLat],
            [maxLng, maxLat],
            [minLng, maxLat],
            [minLng, minLat],
          ],
        ],
      };
      final feature = {'type': 'Feature', 'properties': {'id': tile['id']}, 'geometry': geom};
      if (ownerId == null) {
        neutralFeatures.add(feature);
      } else if (currentUserId != null && ownerId == currentUserId) {
        yoursFeatures.add(feature);
      } else {
        othersFeatures.add(feature);
      }
    }
    return (
      neutral: neutralFeatures.isEmpty ? null : jsonEncode({'type': 'FeatureCollection', 'features': neutralFeatures}),
      yours: yoursFeatures.isEmpty ? null : jsonEncode({'type': 'FeatureCollection', 'features': yoursFeatures}),
      others: othersFeatures.isEmpty ? null : jsonEncode({'type': 'FeatureCollection', 'features': othersFeatures}),
    );
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _startRun() async {
    if (_isRunning) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to record runs')));
      return;
    }
    final permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      final requested = await geo.Geolocator.requestPermission();
      if (requested == geo.LocationPermission.denied || requested == geo.LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission needed')));
        return;
      }
    }
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable location services')));
      return;
    }
    setState(() {
      _isRunning = true;
      _path = [];
    });
    try {
      final pos = await geo.Geolocator.getCurrentPosition();
      if (mounted && _isRunning) setState(() => _path.add(PathPoint(lat: pos.latitude, lng: pos.longitude, t: DateTime.now().millisecondsSinceEpoch)));
    } catch (_) {}
    _runTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final pos = await geo.Geolocator.getCurrentPosition();
        if (mounted && _isRunning) {
          setState(() => _path.add(PathPoint(lat: pos.latitude, lng: pos.longitude, t: DateTime.now().millisecondsSinceEpoch)));
        }
      } catch (_) {}
    });
  }

  Future<void> _stopRun() async {
    if (!_isRunning) return;
    _runTimer?.cancel();
    _runTimer = null;
    setState(() => _isRunning = false);
    if (_path.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No points recorded')));
      return;
    }
    final pathToSubmit = List<PathPoint>.from(_path);
    _path = [];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('No token');
      await submitRun(idToken, pathToSubmit);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Run saved (${pathToSubmit.length} points)')));
      _refreshTilesData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  void dispose() {
    _runTimer?.cancel();
    _tilesSocket?.disconnect();
    _tilesSocket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: const Center(
          child: Text('Map is available on Android and iOS.'),
        ),
      );
    }

    const token = String.fromEnvironment('ACCESS_TOKEN', defaultValue: '');
    if (token.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Mapbox access token not set.\n\n'
              'Run with:\n'
              'flutter run --dart-define=ACCESS_TOKEN=your_mapbox_token\n\n'
              'Get a token at: https://account.mapbox.com/access-tokens/',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(_defaultLng, _defaultLat)),
      zoom: _defaultZoom,
      bearing: 0,
      pitch: 0,
    );

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('mapWidget'),
            cameraOptions: cameraOptions,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapIdleListener: _onMapIdle,
          ),
          if (_tilesError != null)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 8,
              child: Material(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_tilesError!, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRunning ? _stopRun : _startRun,
        backgroundColor: _isRunning ? Colors.red : Colors.green,
        icon: Icon(_isRunning ? Icons.stop : Icons.directions_run),
        label: Text(_isRunning ? 'Stop run · ${_path.length} pts' : 'Start run'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}