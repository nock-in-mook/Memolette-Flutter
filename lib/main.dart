import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'screens/home_screen.dart';
import 'screens/quick_sort_screen.dart';
import 'utils/keyboard_done_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ダミータグ挿入（タグ0件のときだけ）
  final db = AppDatabase();
  await db.seedDummyTags();
  await db.seedDummyTagHistory();
  await db.close();

  runApp(
    const ProviderScope(
      child: MemolettApp(),
    ),
  );
}

class _DQS extends StatefulWidget{const _DQS();@override State<_DQS> createState()=>_DQSs();}
class _DQSs extends State<_DQS>{@override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const QuickSortScreen()));});}@override Widget build(BuildContext c)=>const HomeScreen();}
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
      home: const _DQS(),
    );
  }
}
