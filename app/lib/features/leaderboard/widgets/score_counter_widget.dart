import 'package:flutter/material.dart';

/// Displays a score value.
///
/// In later phases this will animate changes; for Phase 1 it is static.
class ScoreCounterWidget extends StatelessWidget {
  const ScoreCounterWidget({
    super.key,
    required this.score,
  });

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Text(
      '$score',
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.primary,
      ),
    );
  }
}

