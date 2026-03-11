import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import 'leaderboard_state.dart';

/// Controller for the leaderboard screen.
///
/// Responsibilities:
/// - Load initial leaderboard data from the backend
/// - (Later) subscribe to WebSocket updates
/// - (Later) drive animated reordering and score updates
class LeaderboardController extends ChangeNotifier {
  LeaderboardController() {
    _loadInitial();
  }

  LeaderboardViewState _state = const LeaderboardViewState(isLoading: true);

  LeaderboardViewState get state => _state;

  void _setState(LeaderboardViewState newState) {
    _state = newState;
    notifyListeners();
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
}

