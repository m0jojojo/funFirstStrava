// Firebase config for each platform. For Windows, options are required.
// To regenerate: dart run flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.android:
        return android;
      default:
        return windows;
    }
  }

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCBmkjlODagVgqmZlbLcQesiIt9eqa8Ayc',
    appId: '1:626019867864:windows:default',
    messagingSenderId: '626019867864',
    projectId: 'funfirststrava',
    authDomain: 'funfirststrava.firebaseapp.com',
    storageBucket: 'funfirststrava.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBmkjlODagVgqmZlbLcQesiIt9eqa8Ayc',
    appId: '1:626019867864:android:313f142a915f2627424bad',
    messagingSenderId: '626019867864',
    projectId: 'funfirststrava',
    authDomain: 'funfirststrava.firebaseapp.com',
    storageBucket: 'funfirststrava.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBmkjlODagVgqmZlbLcQesiIt9eqa8Ayc',
    appId: '1:626019867864:web:default',
    messagingSenderId: '626019867864',
    projectId: 'funfirststrava',
    authDomain: 'funfirststrava.firebaseapp.com',
    storageBucket: 'funfirststrava.firebasestorage.app',
  );

  /// Web OAuth 2.0 Client ID for Google Sign-In (Web only). Get from Google Cloud Console > APIs & Services > Credentials > Create OAuth 2.0 Client ID > Web application. Must match meta tag in web/index.html.
  static const String webGoogleSignInClientId = '626019867864-78cuqeh9bc72u5lfckheo35nh9nvc68u.apps.googleusercontent.com';
}
