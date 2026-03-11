import 'package:flutter/material.dart';

import '../leaderboard_state.dart';
import 'leaderboard_row.dart';

/// Displays the leaderboard entries.
///
/// Phase 1: simple, non-animated [ListView]. In later phases this
/// will be replaced with an animated list that smoothly reorders rows.
class AnimatedRankList extends StatelessWidget {
  const AnimatedRankList({
    super.key,
    required this.entries,
  });

  final List<LeaderboardEntryView> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: entries.length.clamp(0, 50),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return LeaderboardRow(
          key: ValueKey(entry.userId),
          entry: entry,
        );
      },
    );
  }
}

