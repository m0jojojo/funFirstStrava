import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.tileCount,
  });

  final String userId;
  final String username;
  final int tileCount;

  static LeaderboardEntry fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Unknown',
      tileCount: (json['tileCount'] is num) ? (json['tileCount'] as num).toInt() : 0,
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry> _entries = [];
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
    try {
      final uri = Uri.parse('$apiBaseUrl/tiles/leaderboard');
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          _loading = false;
        });
        return;
      }
      final list = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _entries = list
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
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
              : _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              size: 64,
                              color: colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No one has captured tiles yet',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first: go for a run and claim territory on the map.',
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
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final e = _entries[index];
                          final rank = index + 1;
                          return _LeaderboardCard(
                            theme: theme,
                            rank: rank,
                            username: e.username,
                            tileCount: e.tileCount,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.theme,
    required this.rank,
    required this.username,
    required this.tileCount,
  });

  final ThemeData theme;
  final int rank;
  final String username;
  final int tileCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final isTopThree = rank <= 3;
    final rankColor = rank == 1
        ? const Color(0xFFFFD700) // gold
        : rank == 2
            ? const Color(0xFFC0C0C0) // silver
            : rank == 3
                ? const Color(0xFFCD7F32) // bronze
                : colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTopThree
                    ? rankColor.withOpacity(0.2)
                    : colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$rank',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isTopThree ? rankColor : colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                username,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$tileCount tiles',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
