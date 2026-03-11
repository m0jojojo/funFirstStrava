import 'package:flutter/material.dart';
import 'package:implicitly_animated_reorderable_list_2/implicitly_animated_reorderable_list_2.dart';

import '../leaderboard_state.dart';
import 'leaderboard_row.dart';

/// Displays the leaderboard entries with smooth position changes.
///
/// Uses [ImplicitlyAnimatedList] so that when the order of [entries]
/// changes, only the affected rows animate into their new positions.
class AnimatedRankList extends StatelessWidget {
  const AnimatedRankList({
    super.key,
    required this.entries,
  });

  final List<LeaderboardEntryView> entries;

  @override
  Widget build(BuildContext context) {
    final visibleEntries =
        entries.length > 50 ? entries.sublist(0, 50) : entries;

    return ImplicitlyAnimatedList<LeaderboardEntryView>(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      items: visibleEntries,
      areItemsTheSame: (a, b) => a.userId == b.userId,
      itemBuilder: (context, animation, item, index) {
        return SizeFadeTransition(
          animation: animation,
          curve: Curves.easeInOut,
          child: LeaderboardRow(
            key: ValueKey(item.userId),
            entry: item,
          ),
        );
      },
    );
  }
}

