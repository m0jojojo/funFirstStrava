import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../map/map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
  Text(
    'Game Running',
    style: Theme.of(context).textTheme.headlineMedium,
  ),
  const SizedBox(height: 24),

  FilledButton.tonal(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const MapScreen(),
        ),
      );
    },
    child: const Text('Open map'),
  ),
  const SizedBox(height: 12),
  FilledButton.tonal(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LeaderboardScreen(),
        ),
      );
    },
    child: const Text('Leaderboard'),
  ),
  const SizedBox(height: 24),
  TextButton(
    onPressed: () async {
      await authService.signOut();
      // Auth state changes → StreamBuilder in main.dart shows LoginScreen
    },
    child: const Text('Sign out'),
  ),
],
        ),
      ),
    );
  }
}
