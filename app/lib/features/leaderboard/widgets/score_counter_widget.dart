import 'package:flutter/material.dart';

/// Displays a score value with a smooth count-up animation when it changes.
class ScoreCounterWidget extends StatefulWidget {
  const ScoreCounterWidget({
    super.key,
    required this.score,
  });

  final int score;

  @override
  State<ScoreCounterWidget> createState() => _ScoreCounterWidgetState();
}

class _ScoreCounterWidgetState extends State<ScoreCounterWidget> {
  late int _previousScore;

  @override
  void initState() {
    super.initState();
    _previousScore = widget.score;
  }

  @override
  void didUpdateWidget(covariant ScoreCounterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Capture the last rendered score so we can animate from it.
    if (oldWidget.score != widget.score) {
      _previousScore = oldWidget.score;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.score),
      tween: Tween<double>(
        begin: _previousScore.toDouble(),
        end: widget.score.toDouble(),
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final display = value.round();
        return Text(
          '$display tiles',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        );
      },
    );
  }
}

