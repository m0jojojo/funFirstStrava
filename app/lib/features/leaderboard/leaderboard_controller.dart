import 'package:flutter/foundation.dart';

import 'leaderboard_state.dart';

/// Simple controller for the leaderboard screen.
///
/// In later phases this will:
/// - Load initial data from the backend
/// - Subscribe to WebSocket updates
/// - Drive animated reordering and score updates
class LeaderboardController extends ChangeNotifier {
  LeaderboardController() {
    _bootstrapWithMockData();
  }

  LeaderboardViewState _state = const LeaderboardViewState(isLoading: true);

  LeaderboardViewState get state => _state;

  void _setState(LeaderboardViewState newState) {
    _state = newState;
    notifyListeners();
  }

  void _bootstrapWithMockData() {
    // For Phase 1 we just show a static, fake leaderboard so we can iterate on layout.
    final demoEntries = List<LeaderboardEntryView>.generate(10, (index) {
      final rank = index + 1;
      return LeaderboardEntryView(
        rank: rank,
        userId: 'demo-$rank',
        username: 'Runner $rank',
        score: 74200 - index * 50,
        isCurrentUser: rank == 4,
      );
    });

    _setState(
      LeaderboardViewState(
        isLoading: false,
        entries: demoEntries,
      ),
    );
  }
}

