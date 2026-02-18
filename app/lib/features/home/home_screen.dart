import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Game Running',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
