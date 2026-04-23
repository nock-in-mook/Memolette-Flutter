import 'package:drift/drift.dart';
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

/// よく見るメモ取得（viewCount > 0 を降順）
final frequentMemosProvider = StreamProvider<List<Memo>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchFrequentMemos();
});

/// 検索用正規化: 小文字化 + 全角ASCII→半角
String normalizeForSearch(String s) {
  final buf = StringBuffer();
  for (final cp in s.codeUnits) {
    if (cp >= 0xFF01 && cp <= 0xFF5E) {
      // 全角ASCII (！〜～) → 半角ASCII (! 〜 ~)
      buf.writeCharCode(cp - 0xFEE0);
    } else if (cp == 0x3000) {
      // 全角スペース → 半角スペース
      buf.writeCharCode(0x20);
    } else {
      buf.writeCharCode(cp);
    }
  }
  return buf.toString().toLowerCase();
}

/// メモ検索（title/content を正規化して大小・全半角を吸収）
/// watchAllMemos を購読して Dart 側でフィルタ → 全/半角混在も検索可能
final searchMemosProvider =
    StreamProvider.family<List<Memo>, String>((ref, query) {
  final db = ref.watch(databaseProvider);
  final normQuery = normalizeForSearch(query);
  if (normQuery.isEmpty) {
    return Stream<List<Memo>>.value(const []);
  }
  return db.watchAllMemos().map((all) {
    return all.where((m) {
      final t = normalizeForSearch(m.title);
      final c = normalizeForSearch(m.content);
      return t.contains(normQuery) || c.contains(normQuery);
    }).toList();
  });
});

/// 最近見たメモ取得（lastViewedAt 降順）
final recentMemosProvider = StreamProvider<List<Memo>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentMemos();
});

/// メモに紐づくタグ取得（FutureProvider）
final tagsForMemoProvider =
    FutureProvider.family<List<Tag>, String>((ref, memoId) {
  final db = ref.watch(databaseProvider);
  return db.getTagsForMemo(memoId);
});

/// メモに紐づくタグ取得（StreamProvider, リアルタイム更新版）
final tagsForMemoStreamProvider =
    StreamProvider.family<List<Tag>, String>((ref, memoId) {
  final db = ref.watch(databaseProvider);
  return db.watchTagsForMemo(memoId);
});

/// メモに紐づく画像を監視（Phase 10）
final memoImagesProvider =
    StreamProvider.family<List<MemoImage>, String>((ref, memoId) {
  final db = ref.watch(databaseProvider);
  return db.watchMemoImages(memoId);
});

// ========================================
// ToDoリスト関連
// ========================================

/// 全ToDoリストをリアルタイム監視
final allTodoListsProvider = StreamProvider<List<TodoList>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.todoLists)
        ..orderBy([
          (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
          (t) => OrderingTerm(
              expression: t.manualSortOrder, mode: OrderingMode.desc),
          (t) =>
              OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
      .watch();
});

/// タグに紐づくToDoリスト取得
final todoListsForTagProvider =
    StreamProvider.family<List<TodoList>, String>((ref, tagId) {
  final db = ref.watch(databaseProvider);
  return db.watchTodoListsForTag(tagId);
});

/// タグなしToDoリスト取得
final untaggedTodoListsProvider = StreamProvider<List<TodoList>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchUntaggedTodoLists();
});

/// TODOリスト検索（title / items.title / items.memo のいずれかにヒット）
final searchTodoListsProvider =
    StreamProvider.family<List<TodoList>, String>((ref, query) {
  final db = ref.watch(databaseProvider);
  if (query.isEmpty) return Stream<List<TodoList>>.value(const []);
  return db.searchTodoLists(query);
});

/// 特定 TODOリストの全アイテムを購読（sortOrder 順）
/// 検索結果カード内でヒットアイテムを表示するのに使う。
final todoItemsForListProvider =
    StreamProvider.family<List<TodoItem>, String>((ref, listId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.todoItems)
        ..where((t) => t.listId.equals(listId))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();
});

/// ToDoリストに紐づくタグ取得（StreamProvider）
final tagsForTodoListStreamProvider =
    StreamProvider.family<List<Tag>, String>((ref, todoListId) {
  final db = ref.watch(databaseProvider);
  return db.watchTagsForTodoList(todoListId);
});

/// 「すべて」「タグなし」タブの色（colorIndex）を保持
/// 永続化は後日対応。今はメモリのみ。
final allTabColorIndexProvider = StateProvider<int>((ref) => -1); // -1 = TagColors.allTabColor を使う
final untaggedTabColorIndexProvider = StateProvider<int>((ref) => 0); // 0 = palette[0]
final frequentTabColorIndexProvider = StateProvider<int>((ref) => 8); // 薄い水色系
