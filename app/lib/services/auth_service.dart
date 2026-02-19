import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../firebase_options.dart';

/// Result of a successful login: backend user info + Firebase uid/email/name.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.username,
    this.email,
  });

  final String uid;
  final String username;
  final String? email;
}

/// Handles Google Sign-In, Firebase Auth, and backend user registration.
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    String baseUrl = apiBaseUrl,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? (kIsWeb ? GoogleSignIn(clientId: DefaultFirebaseOptions.webGoogleSignInClientId) : GoogleSignIn()),
        _baseUrl = baseUrl;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final String _baseUrl;

  /// Sign out from Firebase and Google.
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  /// Signs in with Google (all platforms including web). On web, Google may only return an access token; Firebase Auth accepts that and we use [FirebaseUser.getIdToken] for the backend.
  Future<AuthUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    return signInWithGoogleAccount(googleUser);
  }

  /// Completes sign-in using an already-authenticated [GoogleSignInAccount]. Throws on failure.
  Future<AuthUser> signInWithGoogleAccount(GoogleSignInAccount googleUser) async {
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      // On web, Google Identity Services might not provide an ID token here.
      // Firebase Auth can sign in with just the access token, and we later
      // obtain a Firebase ID token from [FirebaseAuth.currentUser].
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) throw Exception('Firebase sign-in failed');

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null) throw Exception('No Firebase ID token');

    final authUser = await _registerWithBackend(
      idToken: idToken,
      displayName: firebaseUser.displayName,
      email: firebaseUser.email,
    );
    return authUser;
  }

  Future<AuthUser> _registerWithBackend({
    required String idToken,
    String? displayName,
    String? email,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/register');
    final body = jsonEncode({
      'idToken': idToken,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
    });
    final response = await http.post(
      uri,
      body: body,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 201) {
      throw Exception('Backend register failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthUser(
      uid: data['firebaseUid'] as String,
      username: data['username'] as String,
      email: data['email'] as String?,
    );
  }
}
