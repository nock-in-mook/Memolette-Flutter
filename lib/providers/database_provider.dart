import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';

/// アプリ全体で共有するデ��タベースインスタンス
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// 全メモをリアルタイム監視��ピン��め→作成日時降順）
final allMemosProvider = StreamProvider<List<Memo>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllMemos();
});

/// 全タグをリアルタイム監視
final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTags();
});

/// 親タグのみリアルタイム監視
final parentTagsProvider = StreamProvider<List<Tag>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchParentTags();
});

/// 子タグ取得（親タグIDをキーに）
final childTagsProvider =
    StreamProvider.family<List<Tag>, String>((ref, parentId) {
  final db = ref.watch(databaseProvider);
  return db.watchChildTags(parentId);
});

/// タグに紐づくメモ取得
final memosForTagProvider =
    StreamProvider.family<List<Memo>, String>((ref, tagId) {
  final db = ref.watch(databaseProvider);
  return db.watchMemosForTag(tagId);
});

/// タグなしメモ取得
final untaggedMemosProvider = StreamProvider<List<Memo>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchUntaggedMemos();
});

/// メモに紐づくタグ取得（FutureProvider）
final tagsForMemoProvider =
    FutureProvider.family<List<Tag>, String>((ref, memoId) {
  final db = ref.watch(databaseProvider);
  return db.getTagsForMemo(memoId);
});

/// 「すべて」「タグなし」タブの色（colorIndex）を保持
/// 永続化は後日対応。今はメモリのみ。
final allTabColorIndexProvider = StateProvider<int>((ref) => -1); // -1 = TagColors.allTabColor を使う
final untaggedTabColorIndexProvider = StateProvider<int>((ref) => 0); // 0 = palette[0]
