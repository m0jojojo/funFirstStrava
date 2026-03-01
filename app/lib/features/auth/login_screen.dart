import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../../services/auth_service.dart';
import '../home/home_screen.dart';

bool get _isGoogleSignInSupported {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return false;
    default:
      return true;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    if (!_isGoogleSignInSupported) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final supported = _isGoogleSignInSupported;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Text(
                  'gogo',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Run to claim territory.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                if (!supported) ...[
                  Text(
                    'Sign in with Google isn’t available on this device.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use Chrome or Android to sign in:\nflutter run -d chrome',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                      );
                    },
                    child: const Text('Continue without sign-in'),
                  ),
                ] else ...[
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  FilledButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.login_rounded, size: 20),
                    label: Text(_loading ? 'Signing in…' : 'Sign in with Google'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
