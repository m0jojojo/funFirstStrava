import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

/// Background message handler - must be top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] Background: ${message.notification?.title}');
  }
}

/// Handles FCM setup: permissions, token, foreground/background messages.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Current FCM token. Call [initialize] first.
  String? get token => _token;
  String? _token;

  /// Initialize FCM: request permission, get token, set up handlers.
  /// Skipped on web (FCM not supported there).
  Future<void> initialize() async {
    if (kIsWeb) return;

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+, iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    }

    // Get token
    _token = await _messaging.getToken();
    if (kDebugMode && _token != null) {
      debugPrint('[FCM] Token: ${_token!.substring(0, 20)}...');
    }

    // Token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      if (kDebugMode) debugPrint('[FCM] Token refreshed');
      sendTokenToBackend();
    });

    await sendTokenToBackend();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Foreground: ${message.notification?.title}');
      }
      // TODO: Show in-app notification or snackbar
    });

    // User tapped notification (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Opened from notification: ${message.data}');
      }
      // TODO: Navigate based on message.data
    });
  }

  /// Send current FCM token to backend (requires signed-in user).
  Future<void> sendTokenToBackend() async {
    final fcmToken = _token;
    if (fcmToken == null || fcmToken.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();
    if (idToken == null) return;

    try {
      final uri = Uri.parse('$apiBaseUrl/users/fcm-token');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      if (kDebugMode) {
        debugPrint('[FCM] Backend register: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Backend register failed: $e');
    }
  }
}
