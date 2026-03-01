import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/offline_run_service.dart';
import '../../services/push_notification_service.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../map/map_screen.dart';
import '../runs/runs_list_screen.dart';

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
    OfflineRunService().syncPendingRuns();
  }

  void _navigate(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Hero + primary CTA
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'gogo',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Run to claim territory on the map.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => _navigate(const MapScreen()),
                      icon: const Icon(Icons.map_outlined, size: 22),
                      label: const Text('Open map'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Secondary actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeActionCard(
                      icon: Icons.leaderboard_outlined,
                      title: 'Leaderboard',
                      subtitle: 'See who owns the most tiles',
                      onTap: () => _navigate(const LeaderboardScreen()),
                    ),
                    const SizedBox(height: 12),
                    _HomeActionCard(
                      icon: Icons.directions_run_outlined,
                      title: 'My runs',
                      subtitle: 'History and stats',
                      onTap: () => _navigate(const RunsListScreen()),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            // Footer: sign out + tagline
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await AuthService().signOut();
                        },
                        child: Text(
                          'Sign out',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'gogo ❤️',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.outline,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
