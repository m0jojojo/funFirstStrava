import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_config.dart';
import 'leaderboard_state.dart';

/// Controller for the leaderboard screen.
///
/// Responsibilities:
/// - Load initial leaderboard data from the backend
/// - Subscribe to WebSocket updates from the backend
/// - Drive animated reordering and score updates
class LeaderboardController extends ChangeNotifier {
  LeaderboardController() {
    _instances.add(this);
    _loadInitial();
    _connectSocket();
  }

  static final Set<LeaderboardController> _instances = <LeaderboardController>{};

  LeaderboardViewState _state = const LeaderboardViewState(isLoading: true);
  io.Socket? _socket;

  LeaderboardViewState get state => _state;

  void _setState(LeaderboardViewState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _instances.remove(this);
    super.dispose();
  }

  /// Trigger a fresh HTTP fetch of the global leaderboard.
  Future<void> refresh() => _loadInitial();

  /// Convenience to refresh any existing leaderboard controllers.
  static Future<void> refreshAll() async {
    await Future.wait(_instances.map((c) => c.refresh()));
  }

  Future<void> _loadInitial() async {
    _setState(
      _state.copyWith(
        isLoading: true,
        errorMessage: null,
      ),
    );

    try {
      final uri = Uri.parse('$apiBaseUrl/leaderboards/global?limit=50');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        _setState(
          _state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load leaderboard (${response.statusCode})',
          ),
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        _setState(
          _state.copyWith(
            isLoading: false,
            errorMessage: 'Unexpected leaderboard response',
          ),
        );
        return;
      }

      final entries = <LeaderboardEntryView>[];
      for (var i = 0; i < decoded.length; i++) {
        final raw = decoded[i];
        if (raw is! Map) continue;

        final map = raw.cast<String, dynamic>();
        final userId = map['userId']?.toString() ?? '';
        final username = map['username']?.toString();
        final scoreValue = map['score'];
        final score = scoreValue is num ? scoreValue.toInt() : 0;

        entries.add(
          LeaderboardEntryView(
            rank: i + 1,
            userId: userId,
            username: username?.isNotEmpty == true ? username! : 'Runner ${i + 1}',
            score: score,
          ),
        );
      }

      _setState(
        LeaderboardViewState(
          isLoading: false,
          entries: entries,
        ),
      );
    } catch (e) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load leaderboard',
        ),
      );
    }
  }

  void _connectSocket() {
    try {
      final socket = io.io(
        apiBaseUrl,
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': true,
        },
      );

      _socket = socket;

      socket.on('leaderboard_update', (dynamic data) {
        _handleLeaderboardUpdate(data);
      });
    } catch (_) {
      // If the socket fails we still keep the static leaderboard; no-op.
    }
  }

  void _handleLeaderboardUpdate(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(
      data.cast<String, dynamic>(),
    );

    final userId = map['userId']?.toString() ?? '';
    if (userId.isEmpty) return;

    final scoreValue = map['score'];
    if (scoreValue is! num) return;
    final newScore = scoreValue.toInt();

    // Optional rank field (backend currently sends newRank).
    final dynamic rankField = map['rank'] ?? map['newRank'];
    int? newRank;
    if (rankField is num) {
      newRank = rankField.toInt();
    }

    final current = List<LeaderboardEntryView>.from(_state.entries);
    final previousRanks = <String, int>{};
    for (final e in current) {
      previousRanks[e.userId] = e.rank;
    }

    final index = current.indexWhere((e) => e.userId == userId);

    if (index == -1) {
      // New entrant into the leaderboard.
      final username = map['username']?.toString();
      current.add(
        LeaderboardEntryView(
          rank: newRank ?? (current.length + 1),
          userId: userId,
          username:
              username != null && username.isNotEmpty ? username : 'Runner',
          score: newScore,
        ),
      );
    } else {
      final existing = current[index];
      current[index] = existing.copyWith(
        score: newScore,
        rank: newRank ?? existing.rank,
      );
    }

    // Re-sort by score descending; then recompute ranks to keep them consistent.
    current.sort((a, b) => b.score.compareTo(a.score));
    final reRanked = <LeaderboardEntryView>[];
    for (var i = 0; i < current.length; i++) {
      final entry = current[i];
      final newRankValue = i + 1;
      final oldRankValue = previousRanks[entry.userId];
      final promoted =
          oldRankValue != null && newRankValue < oldRankValue ? true : false;

      reRanked.add(
        entry.copyWith(
          rank: newRankValue,
          justPromoted: promoted,
        ),
      );
    }

    _setState(
      _state.copyWith(
        entries: reRanked,
      ),
    );
  }
}
