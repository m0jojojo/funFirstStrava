import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Google Sign-In button for web (GIS renderButton). Use via conditional import with [GoogleSignInButtonStub] on non-web.
Widget buildGoogleSignInButtonWeb() {
  return gsi_web.renderButton();
}
