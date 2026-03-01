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
import '../../services/run_tracker.dart';

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

  /// Initial map center. Null = still resolving user location.
  double? _initialLat;
  double? _initialLng;

  io.Socket? _tilesSocket;

  /// Fallback center: Sector 40 Gurgaon (when location unavailable). Position is (lng, lat).
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

  static const String _runPathSourceId = 'run-path';
  static const String _runPathLayerId = 'run-path-line';
  bool _runPathLayerAdded = false;

  DateTime? _lastTilesRefreshAt;
  static const _tilesRefreshDebounce = Duration(seconds: 2);

  Timer? _elapsedTick;

  @override
  void initState() {
    super.initState();
    _resolveInitialCenter();
    RunTracker.instance.addListener(_onRunTrackerChanged);
  }

  void _onRunTrackerChanged() {
    final running = RunTracker.instance.isRunning;
    if (running && _elapsedTick?.isActive != true) {
      _elapsedTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _elapsedTick?.cancel();
      _elapsedTick = null;
    }
    _updateRunPathOnMap();
    if (mounted) setState(() {});
  }

  /// Build GeoJSON Feature with LineString from run path (coordinates as [lng, lat]).
  String _runPathToGeoJson(List<PathPoint> path) {
    if (path.isEmpty) {
      return '{"type":"Feature","geometry":{"type":"LineString","coordinates":[]}}';
    }
    final coords = path.map((p) => [p.lng, p.lat]).toList();
    return '{"type":"Feature","geometry":{"type":"LineString","coordinates":${jsonEncode(coords)}}}';
  }

  Future<void> _updateRunPathOnMap() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || !_runPathLayerAdded) return;
    final path = RunTracker.instance.path;
    try {
      final src = await mapboxMap.style.getSource(_runPathSourceId);
      if (src is GeoJsonSource) {
        await src.updateGeoJSON(_runPathToGeoJson(path));
      }
    } catch (_) {}
  }

  /// Resolve initial map center: user location, or fallback to Sector 40.
  Future<void> _resolveInitialCenter() async {
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever ||
        !await geo.Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() {
        _initialLat = _defaultLat;
        _initialLng = _defaultLng;
      });
      return;
    }
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) setState(() {
        _initialLat = pos.latitude;
        _initialLng = pos.longitude;
      });
    } catch (_) {
      if (mounted) setState(() {
        _initialLat = _defaultLat;
        _initialLng = _defaultLng;
      });
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  void _onStyleLoaded(StyleLoadedEventData eventData) {
    _enableUserLocationPuck();
    _loadTilesAndAddLayer();
  }

  /// Show user location as blue dot with pulsing glow (like Google Maps).
  void _enableUserLocationPuck() {
    try {
      _mapboxMap?.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
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

    final lat = _initialLat ?? _defaultLat;
    final lng = _initialLng ?? _defaultLng;
    try {
      final result = await _fetchTilesNear(lat, lng);
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
        // Run path line (orange) — draws on top of tiles, updates live during run
        await mapboxMap.style.addSource(GeoJsonSource(
          id: _runPathSourceId,
          data: _runPathToGeoJson(RunTracker.instance.path),
        ));
        await mapboxMap.style.addLayer(LineLayer(
          id: _runPathLayerId,
          sourceId: _runPathSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineColor: Colors.orange.value,
          lineWidth: 5.0,
        ));
        if (mounted) setState(() {
          _tilesLayerAdded = true;
          _runPathLayerAdded = true;
        });
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
      double lat = _initialLat ?? _defaultLat;
      double lng = _initialLng ?? _defaultLng;
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
    final error = await RunTracker.instance.start();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _stopRun() async {
    final result = await RunTracker.instance.stop();
    if (!mounted) return;
    if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message!)));
    }
    if (result.success) {
      _refreshTilesData();
    }
  }

  @override
  void dispose() {
    RunTracker.instance.removeListener(_onRunTrackerChanged);
    _elapsedTick?.cancel();
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

    // Wait for initial center (user location or fallback)
    if (_initialLat == null || _initialLng == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location...'),
            ],
          ),
        ),
      );
    }

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(_initialLng!, _initialLat!)),
      zoom: _defaultZoom,
      bearing: 0,
      pitch: 0,
    );

    final tracker = RunTracker.instance;

    return WillPopScope(
      onWillPop: () async {
        if (tracker.isRunning && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Run is still active. You can come back to the map later and press Stop run.',
              ),
            ),
          );
        }
        return true;
      },
      child: Scaffold(
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
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _tilesError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Metrics bar (time + tiles) — above bottom control bar
            Positioned(
              left: 16,
              right: 16,
              bottom: _mapBottomBarHeight + 12,
              child: _MapMetricsBar(tracker: tracker),
            ),
            // Bottom control bar: activity type, Start/Pause/Resume, Finish
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _MapBottomControlBar(
                tracker: tracker,
                onStart: _startRun,
                onPause: () => tracker.pause(),
                onResume: () => tracker.resume(),
                onFinish: _stopRun,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double _mapBottomBarHeight = 100;

String _formatElapsed(Duration? d) {
  if (d == null) return '00:00';
  final total = d.inSeconds;
  final min = total ~/ 60;
  final sec = total % 60;
  return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

class _MapMetricsBar extends StatelessWidget {
  const _MapMetricsBar({required this.tracker});

  final RunTracker tracker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final elapsed = tracker.elapsed;
    final timeStr = _formatElapsed(elapsed);
    final tileCount = tracker.path.length;

    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.95),
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MetricItem(
              value: timeStr,
              label: 'Time',
              colorScheme: colorScheme,
            ),
            _MetricItem(
              value: '$tileCount',
              label: 'Tiles',
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.value,
    required this.label,
    required this.colorScheme,
  });

  final String value;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MapBottomControlBar extends StatelessWidget {
  const _MapBottomControlBar({
    required this.tracker,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final RunTracker tracker;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRunning = tracker.isRunning;
    final isPaused = tracker.isPaused;

    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.98),
      elevation: 8,
      shadowColor: Colors.black38,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _mapBottomBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: activity type (Run)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.directions_run_rounded,
                        color: colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Run',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                // Center: Start / Pause / Resume
                Builder(
                  builder: (context) {
                    if (!isRunning) {
                      return _BigRoundButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Start',
                        color: colorScheme.primary,
                        onPressed: onStart,
                      );
                    }
                    if (isPaused) {
                      return _BigRoundButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Resume',
                        color: colorScheme.primary,
                        onPressed: onResume,
                      );
                    }
                    return _BigRoundButton(
                      icon: Icons.pause_rounded,
                      label: 'Pause',
                      color: colorScheme.primary,
                      onPressed: onPause,
                    );
                  },
                ),
                // Right: Finish (when running) or placeholder
                isRunning
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Material(
                            color: colorScheme.error.withOpacity(0.15),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: onFinish,
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.stop_rounded,
                                  color: Colors.red,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Finish',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(width: 48, height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigRoundButton extends StatelessWidget {
  const _BigRoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: Colors.black38,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white, size: 40),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}