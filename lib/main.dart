import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'screens/home_screen.dart';
import 'utils/keyboard_done_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ダミータグ挿入（タグ0件のときだけ）
  final db = AppDatabase();
  await db.seedDummyTags();
  await db.seedDummyTagHistory();
  await db.seedDummyLongMemos();
  await db.close();

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
      builder: (context, child) => KeyboardDoneBar(child: child!),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        fontFamily: 'PingFang JP',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
