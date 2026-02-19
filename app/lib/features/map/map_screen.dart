import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Default center (same region as backend tile grid): SF area. Position is (lng, lat).
  static const double _defaultLng = -122.4194;
  static const double _defaultLat = 37.7749;
  static const double _defaultZoom = 14.0;

  static const String _tilesSourceIdUnowned = 'tiles-unowned';
  static const String _tilesSourceIdOwned = 'tiles-owned';
  static const String _tilesLayerIdUnowned = 'tiles-fill-unowned';
  static const String _tilesLayerIdOwned = 'tiles-fill-owned';

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
    if (_tilesLayerAdded) _refreshTilesData();
  }

  Future<void> _loadTilesAndAddLayer() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    if (_isLoadingTiles) return;
    _isLoadingTiles = true;

    setState(() => _tilesError = null);

    try {
      final uri = Uri.parse('$apiBaseUrl/tiles');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        if (mounted) setState(() => _tilesError = 'Tiles: ${response.statusCode}');
        return;
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      final unowned = _tilesToGeoJson(list, owned: false);
      final owned = _tilesToGeoJson(list, owned: true);
      if (unowned == null && owned == null) return;

      try {
        // Remove existing tile layers/sources if present (e.g. style reload or second load).
        try {
          await mapboxMap.style.removeStyleLayer(_tilesLayerIdOwned);
        } catch (_) {}
        try {
          await mapboxMap.style.removeStyleLayer(_tilesLayerIdUnowned);
        } catch (_) {}
        try {
          await mapboxMap.style.removeStyleSource(_tilesSourceIdOwned);
        } catch (_) {}
        try {
          await mapboxMap.style.removeStyleSource(_tilesSourceIdUnowned);
        } catch (_) {}

        await mapboxMap.style.addSource(GeoJsonSource(id: _tilesSourceIdUnowned, data: unowned ?? '{"type":"FeatureCollection","features":[]}'));
        await mapboxMap.style.addSource(GeoJsonSource(id: _tilesSourceIdOwned, data: owned ?? '{"type":"FeatureCollection","features":[]}'));
        await mapboxMap.style.addLayer(FillLayer(
          id: _tilesLayerIdUnowned,
          sourceId: _tilesSourceIdUnowned,
          fillColor: Colors.blue.withOpacity(0.35).value,
          fillOpacity: 0.5,
          fillOutlineColor: Colors.blue.value,
        ));
        await mapboxMap.style.addLayer(FillLayer(
          id: _tilesLayerIdOwned,
          sourceId: _tilesSourceIdOwned,
          fillColor: Colors.green.withOpacity(0.4).value,
          fillOpacity: 0.6,
          fillOutlineColor: Colors.green.value,
        ));
        if (mounted) setState(() => _tilesLayerAdded = true);
      } catch (e) {
        if (mounted) setState(() => _tilesError = 'Layer: $e');
      }
    } catch (e) {
      if (mounted) setState(() => _tilesError = 'Fetch: $e');
    } finally {
      _isLoadingTiles = false;
    }
  }

  /// Refresh tile source data when map moves (Phase 5.3) and after run save (Phase 6.2).
  Future<void> _refreshTilesData() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || !_tilesLayerAdded) return;
    try {
      final list = await _fetchTiles();
      if (list == null || !mounted) return;
      final unowned = _tilesToGeoJson(list, owned: false);
      final owned = _tilesToGeoJson(list, owned: true);
      final unownedSource = await mapboxMap.style.getSource(_tilesSourceIdUnowned);
      final ownedSource = await mapboxMap.style.getSource(_tilesSourceIdOwned);
      if (unownedSource is GeoJsonSource) await unownedSource.updateGeoJSON(unowned ?? '{"type":"FeatureCollection","features":[]}');
      if (ownedSource is GeoJsonSource) await ownedSource.updateGeoJSON(owned ?? '{"type":"FeatureCollection","features":[]}');
    } catch (_) {}
  }

  Future<List<dynamic>?> _fetchTiles() async {
    final uri = Uri.parse('$apiBaseUrl/tiles');
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    return decoded is List<dynamic> ? decoded : null;
  }

  /// Build GeoJSON FeatureCollection from backend tile list (Phase 6.2: split by owner).
  /// Backend returns [{ id, minLat, minLng, maxLat, maxLng, ownerId?, ... }, ...].
  String? _tilesToGeoJson(List<dynamic> list, {required bool owned}) {
    final features = <Map<String, dynamic>>[];
    for (final t in list) {
      final tile = t as Map<String, dynamic>;
      final ownerId = tile['ownerId'] ?? tile['owner_id'];
      final hasOwner = ownerId != null && ownerId.toString().isNotEmpty;
      if (owned != hasOwner) continue;
      final minLat = _num(tile['minLat'] ?? tile['min_lat']);
      final minLng = _num(tile['minLng'] ?? tile['min_lng']);
      final maxLat = _num(tile['maxLat'] ?? tile['max_lat']);
      final maxLng = _num(tile['maxLng'] ?? tile['max_lng']);
      if (minLat == null || minLng == null || maxLat == null || maxLng == null) continue;
      features.add({
        'type': 'Feature',
        'properties': {'id': tile['id']},
        'geometry': {
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
        },
      });
    }
    if (features.isEmpty) return null;
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
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