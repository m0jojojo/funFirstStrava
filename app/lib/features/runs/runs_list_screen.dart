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
      } catch (_) {}
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

  /// Distance in km with 2 decimal places, e.g. "0.05 km" or "3.53 km".
  static String _formatDistanceKm(double? meters) {
    if (meters == null) return '—';
    final km = meters / 1000;
    return '${km.toStringAsFixed(2)} km';
  }

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My runs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
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
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _pendingRuns.isEmpty && _runs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_run_rounded,
                              size: 64,
                              color: colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No runs yet',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Open the map, tap Start run, and go for a run to claim territory.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await OfflineRunService().syncPendingRuns();
                        await _load();
                      },
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        children: [
                          if (_pendingRuns.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                              child: Text(
                                'Pending upload',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ..._pendingRuns.map((r) => _RunCard(
                                  theme: theme,
                                  date: _formatDate(r.startedAt),
                                  distance: _formatDistanceKm(r.distanceMeters),
                                  pace: _formatPace(r.startedAt, r.endedAt, r.distanceMeters),
                                  duration: _duration(r.startedAt, r.endedAt),
                                  tilesCaptured: r.tilesCaptured,
                                  isPending: true,
                                )),
                            const SizedBox(height: 16),
                          ],
                          if (_runs.isNotEmpty) ...[
                            if (_pendingRuns.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                                child: Text(
                                  'Saved',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ..._runs.map((r) => _RunCard(
                                  theme: theme,
                                  date: _formatDate(r.startedAt),
                                  distance: _formatDistanceKm(r.distanceMeters),
                                  pace: _formatPace(r.startedAt, r.endedAt, r.distanceMeters),
                                  duration: _duration(r.startedAt, r.endedAt),
                                  tilesCaptured: r.tilesCaptured,
                                  isPending: false,
                                )),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({
    required this.theme,
    required this.date,
    required this.distance,
    required this.pace,
    required this.duration,
    required this.tilesCaptured,
    required this.isPending,
  });

  final ThemeData theme;
  final String date;
  final String distance;
  final String pace;
  final String duration;
  final int? tilesCaptured;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPending
                    ? colorScheme.tertiaryContainer.withOpacity(0.5)
                    : colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPending ? Icons.cloud_off_rounded : Icons.directions_run_rounded,
                color: isPending ? colorScheme.tertiary : colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetricChip(label: distance, icon: Icons.straighten_rounded),
                      _MetricChip(
                        label: tilesCaptured != null ? '$tilesCaptured tiles' : '— tiles',
                        icon: Icons.grid_on_rounded,
                      ),
                      _MetricChip(label: pace, icon: Icons.speed_rounded),
                      _MetricChip(label: duration, icon: Icons.schedule_rounded),
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Will sync when online',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
