import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'screens/home_screen.dart';
import 'utils/image_storage.dart';
import 'utils/keyboard_done_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iPhone は縦固定 / iPad は全向き許可
  // （Info.plist だけだと UIRequiresFullScreen=true と組み合わさったときに
  //   iPhone 側の方向制限が効かないケースがあるため Flutter 側でも制御する）
  final view = ui.PlatformDispatcher.instance.views.first;
  final shortestSide =
      view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSide < 600) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
  // Documents パスを温めて以降の Image.file FutureBuilder を同期化
  await ImageStorage.warmUp();
  // ダミータグ挿入（タグ0件のときだけ）
  final db = AppDatabase();
  await db.seedDummyTags();
  await db.seedDummyTagHistory();
  await db.seedDummyLongMemos();
  await db.seedDummyBulkMemos(tagName: 'ダミー70', count: 70);
  await _seedDummyImageMemosIfNeeded(db);
  await db.close();

  runApp(
    const ProviderScope(
      child: MemolettApp(),
    ),
  );
}

/// Phase 10++ 動作確認用: Canvas で生成した画像付きメモを大量に挿入する
/// （既に挿入済みならスキップ）
Future<void> _seedDummyImageMemosIfNeeded(AppDatabase db) async {
  const memoCount = 50;
  const marker = '\uFFFC';
  // 既に seed 済みなら 画像ダミー-000 が存在するはず
  final existing = await (db.select(db.memos)
        ..where((t) => t.title.equals('画像ダミー-000'))
        ..limit(1))
      .get();
  if (existing.isNotEmpty) return;

  for (var i = 0; i < memoCount; i++) {
    final memo = await db.createMemo(
      title: '画像ダミー-${i.toString().padLeft(3, '0')}',
    );
    final imgCount = 1 + (i % 3); // 1〜3 枚
    final imgIds = <String>[];
    for (var j = 0; j < imgCount; j++) {
      final bytes = await _renderSampleImage(i * 10 + j);
      final relPath =
          await ImageStorage.saveBytes(bytes, extension: 'png');
      final img =
          await db.addMemoImage(memoId: memo.id, filePath: relPath);
      imgIds.add(img.id);
    }
    // 本文にマーカーを埋めて、インライン位置で画像が出るようにする
    final buf = StringBuffer()..write('ダミー画像メモ #$i\n前書き:\n');
    for (var j = 0; j < imgIds.length; j++) {
      buf.write('$marker${imgIds[j]}$marker');
      if (j < imgIds.length - 1) buf.write('\n画像${j + 2}の説明\n');
    }
    buf.write('\n末尾のテキスト');
    await (db.update(db.memos)..where((t) => t.id.equals(memo.id))).write(
      MemosCompanion(content: Value(buf.toString())),
    );
  }
}

/// Canvas で簡易的な 512x512 PNG を生成
Future<Uint8List> _renderSampleImage(int seed) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const w = 512.0;
  const h = 512.0;
  final hue = (seed * 37.0) % 360.0;
  final bg = HSVColor.fromAHSV(1, hue, 0.55, 0.9).toColor();
  canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);
  // 軽い装飾: 円をいくつか配置（ファイルサイズを少し稼ぐ）
  for (var k = 0; k < 12; k++) {
    final x = ((seed * 7 + k * 53) % 500).toDouble();
    final y = ((seed * 11 + k * 67) % 500).toDouble();
    final c =
        HSVColor.fromAHSV(0.55, (hue + k * 30) % 360, 0.8, 1.0).toColor();
    canvas.drawCircle(Offset(x, y), 40, Paint()..color = c);
  }
  final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
    fontSize: 110,
    fontWeight: FontWeight.bold,
    textAlign: TextAlign.center,
  ))
    ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)))
    ..addText('$seed');
  final para = pb.build()..layout(const ui.ParagraphConstraints(width: w));
  canvas.drawParagraph(para, Offset(0, (h - 110) / 2));
  final pic = recorder.endRecording();
  final img = await pic.toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class MemolettApp extends StatelessWidget {
  const MemolettApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memolette',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // システムのテキストスケールを無視してアプリ内は1.0固定
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: KeyboardDoneBar(child: child!),
        );
      },
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
