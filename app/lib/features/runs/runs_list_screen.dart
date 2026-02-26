import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/offline_run_service.dart';
import '../../services/run_service.dart';

class RunsListScreen extends StatefulWidget {
  const RunsListScreen({super.key});

  @override
  State<RunsListScreen> createState() => _RunsListScreenState();
}

class _RunsListScreenState extends State<RunsListScreen> {
  List<RunSummary> _runs = [];
  List<RunSummary> _pendingRuns = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _error = 'Sign in to view your runs';
          _loading = false;
        });
      }
      return;
    }
    try {
      final pending = await OfflineRunService().getPendingRuns();
      List<RunSummary> runs = [];
      try {
        final token = await user.getIdToken();
        if (token != null) {
          runs = await fetchMyRuns(token);
        }
      } catch (_) {
        // Offline: still show pending runs
      }
      if (mounted) {
        setState(() {
          _pendingRuns = pending;
          _runs = runs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final runDay = DateTime(d.year, d.month, d.day);
    if (runDay == today) {
      return 'Today ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (runDay == yesterday) {
      return 'Yesterday ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _duration(DateTime start, DateTime end) {
    final sec = end.difference(start).inSeconds;
    if (sec < 60) return '${sec}s';
    final min = sec ~/ 60;
    final s = sec % 60;
    if (min < 60) return '${min}m ${s}s';
    final h = min ~/ 60;
    final m = min % 60;
    return '${h}h ${m}m ${s}s';
  }

  static String _formatDistance(double? meters) {
    if (meters == null) return '—';
    if (meters <= 0) return '0 m';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Pace as min:sec per km. Returns "—" if distance missing or zero.
  static String _formatPace(DateTime start, DateTime end, double? distanceMeters) {
    if (distanceMeters == null || distanceMeters <= 0) return '—';
    final sec = end.difference(start).inSeconds;
    if (sec <= 0) return '—';
    final distanceKm = distanceMeters / 1000;
    final secPerKm = sec / distanceKm;
    final minPerKm = secPerKm ~/ 60;
    final secRem = (secPerKm % 60).round();
    return '$minPerKm:${secRem.toString().padLeft(2, '0')} /km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My runs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _pendingRuns.isEmpty && _runs.isEmpty
                  ? const Center(
                      child: Text('No runs yet. Record one from the map!'),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await OfflineRunService().syncPendingRuns();
                        await _load();
                      },
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          if (_pendingRuns.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                'Pending upload (offline)',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                            ..._pendingRuns.map((r) => ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      Icons.cloud_off,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  title: Text(_formatDate(r.startedAt)),
                                  subtitle: Text(
                                    '${_formatDistance(r.distanceMeters)} · ${_formatPace(r.startedAt, r.endedAt, r.distanceMeters)} · ${_duration(r.startedAt, r.endedAt)} · will sync when online',
                                  ),
                                )),
                            const Divider(height: 24),
                          ],
                          if (_runs.isNotEmpty)
                            if (_pendingRuns.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                                child: Text(
                                  'Saved',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ),
                          ..._runs.map((r) => ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    Icons.directions_run,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                                title: Text(_formatDate(r.startedAt)),
                                subtitle: Text(
                                  '${_formatDistance(r.distanceMeters)} · ${_formatPace(r.startedAt, r.endedAt, r.distanceMeters)} · ${_duration(r.startedAt, r.endedAt)}',
                                ),
                              )),
                        ],
                      ),
                    ),
    );
  }
}
