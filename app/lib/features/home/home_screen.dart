import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/offline_run_service.dart';
import '../../services/push_notification_service.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../map/map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    PushNotificationService().sendTokenToBackend();
    // Try to upload any runs that were recorded offline while the user was disconnected.
    OfflineRunService().syncPendingRuns();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      backgroundColor: const Color(0xFFFFDA03),
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
  const SizedBox(height: 48),
  const Text(
    'I LOVE YOU GOGO ❤️',
    style: TextStyle(fontSize: 18),
  ),
],
        ),
      ),
    );
  }
}
