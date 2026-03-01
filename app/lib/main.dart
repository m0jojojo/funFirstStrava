import 'platform_utils_stub.dart'
    if (dart.library.io) 'platform_utils_io.dart' as platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'services/run_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    const token = String.fromEnvironment('ACCESS_TOKEN', defaultValue: '');
    if (token.isNotEmpty) MapboxOptions.setAccessToken(token);
    await PushNotificationService().initialize();
    if (platform.isAndroid) {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'run_tracking',
          channelName: 'Run Tracking',
          channelDescription:
              'Shown while tracking a run (keeps GPS active in background).',
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(4000),
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      FlutterForegroundTask.addTaskDataCallback((data) {
        if (data is Map && RunTracker.instance.isRunning) {
          RunTracker.instance.refreshPathFromStorage();
        }
      });
    }
  }
  runApp(const TerritoryGameApp());
}

class TerritoryGameApp extends StatefulWidget {
  const TerritoryGameApp({super.key});

  @override
  State<TerritoryGameApp> createState() => _TerritoryGameAppState();
}

class _TerritoryGameAppState extends State<TerritoryGameApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && platform.isAndroid) {
      RunTracker.instance.refreshPathFromStorage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'gogo',
      theme: AppTheme.light,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
