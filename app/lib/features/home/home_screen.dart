import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_config.dart';
import '../map/map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _loadTiles(BuildContext context) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/tiles');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tiles loaded: ${list.length}')),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

  // Debug: copy ID token for curl / runs/me
  FilledButton.tonal(
    onPressed: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
        return;
      }
      final token = await user.getIdToken(true);
      if (token == null || !context.mounted) return;
      await Clipboard.setData(ClipboardData(text: token));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID token copied. In PowerShell: curl -H \'Authorization: Bearer \' then paste token.')));
    },
    child: const Text('Copy ID token (for GET /runs/me)'),
  ),
  const SizedBox(height: 12),

  FilledButton(
    onPressed: () => _loadTiles(context),
    child: const Text('Load tiles (test API)'),
  ),
  const SizedBox(height: 12),
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
],
        ),
      ),
    );
  }
}
