import 'package:flutter/foundation.dart';

/// Single row in the leaderboard view.
class LeaderboardEntryView {
  const LeaderboardEntryView({
    required this.rank,
    required this.userId,
    required this.username,
    required this.score,
    this.isCurrentUser = false,
    this.justPromoted = false,
  });

  final int rank;
  final String userId;
  final String username;
  final int score;
  final bool isCurrentUser;
  final bool justPromoted;

  LeaderboardEntryView copyWith({
    int? rank,
    String? userId,
    String? username,
    int? score,
    bool? isCurrentUser,
    bool? justPromoted,
  }) {
    return LeaderboardEntryView(
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      score: score ?? this.score,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      justPromoted: justPromoted ?? this.justPromoted,
    );
  }
}

/// Immutable snapshot of the leaderboard UI state.
@immutable
class LeaderboardViewState {
  const LeaderboardViewState({
    this.isLoading = false,
    this.errorMessage,
    this.entries = const <LeaderboardEntryView>[],
  });

  final bool isLoading;
  final String? errorMessage;
  final List<LeaderboardEntryView> entries;

  LeaderboardViewState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<LeaderboardEntryView>? entries,
  }) {
    return LeaderboardViewState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      entries: entries ?? this.entries,
    );
  }
}

