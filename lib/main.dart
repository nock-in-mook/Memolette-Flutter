import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MemolettApp(),
    ),
  );
}

class MemolettApp extends StatelessWidget {
  const MemolettApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memolette',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
