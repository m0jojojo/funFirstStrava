import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const TerritoryGameApp());
}

class TerritoryGameApp extends StatelessWidget {
  const TerritoryGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Territory Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
