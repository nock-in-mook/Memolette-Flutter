import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'database.g.dart';

const _uuid = Uuid();

@DriftDatabase(tables: [
  Memos,
  Tags,
  TodoItems,
  TodoLists,
  TagHistories,
  MemoTags,
  TodoItemTags,
  TodoListTags,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // テスト用コンストラクタ
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ========================================
  // メモ CRUD
  // ========================================

  /// 全メモをcreatedAt降順で取得（リアルタイム）
  Stream<List<Memo>> watchAllMemos() {
    return (select(memos)
          ..orderBy([
            // ピン留めを先頭に
            (t) => OrderingTerm(
                expression: t.isPinned, mode: OrderingMode.desc),
            // 作成日時の新しい順
            (t) => OrderingTerm(
                expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// メモを1件取得
  Future<Memo?> getMemoById(String id) {
    return (select(memos)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// メモを新規作成
  Future<Memo> createMemo({String title = '', String content = ''}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final companion = MemosCompanion.insert(
      id: id,
      title: Value(title),
      content: Value(content),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await into(memos).insert(companion);
    return (await getMemoById(id))!;
  }

  /// メモを更新
  Future<void> updateMemo({
    required String id,
    String? title,
    String? content,
    bool? isMarkdown,
    bool? isPinned,
    bool? isLocked,
    int? manualSortOrder,
  }) {
    return (update(memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        content: content != null ? Value(content) : const Value.absent(),
        isMarkdown:
            isMarkdown != null ? Value(isMarkdown) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        isLocked: isLocked != null ? Value(isLocked) : const Value.absent(),
        manualSortOrder: manualSortOrder != null
            ? Value(manualSortOrder)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// メモを削除
  Future<void> deleteMemo(String id) {
    return (delete(memos)..where((t) => t.id.equals(id))).go();
  }

  /// 閲覧回数を増やす（ソート順は変えない）
  Future<void> incrementViewCount(String id) async {
    final memo = await getMemoById(id);
    if (memo == null) return;
    await (update(memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(
        viewCount: Value(memo.viewCount + 1),
        lastViewedAt: Value(DateTime.now()),
      ),
    );
  }

  // ========================================
  // タグ CRUD（Phase 2で拡張）
  // ========================================

  /// 全タグ取得（sortOrder順）
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// 親タグのみ取得
  Stream<List<Tag>> watchParentTags() {
    return (select(tags)
          ..where((t) => t.parentTagId.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// タグを新規作成
  Future<Tag> createTag({
    required String name,
    int colorIndex = 1,
    String? parentTagId,
    bool isSystem = false,
  }) async {
    final id = _uuid.v4();
    final companion = TagsCompanion.insert(
      id: id,
      name: Value(name),
      colorIndex: Value(colorIndex),
      parentTagId: Value(parentTagId),
      isSystem: Value(isSystem),
    );
    await into(tags).insert(companion);
    return (await (select(tags)..where((t) => t.id.equals(id)))
        .getSingleOrNull())!;
  }

  // ========================================
  // メモ ↔ タグ リレーション
  // ========================================

  /// メモにタグを付ける
  Future<void> addTagToMemo(String memoId, String tagId) {
    return into(memoTags).insert(
      MemoTagsCompanion.insert(memoId: memoId, tagId: tagId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// メモからタグを外す
  Future<void> removeTagFromMemo(String memoId, String tagId) {
    return (delete(memoTags)
          ..where((t) => t.memoId.equals(memoId) & t.tagId.equals(tagId)))
        .go();
  }

  /// メモに紐づくタグを取得
  Future<List<Tag>> getTagsForMemo(String memoId) {
    final query = select(tags).join([
      innerJoin(memoTags, memoTags.tagId.equalsExp(tags.id)),
    ])
      ..where(memoTags.memoId.equals(memoId));
    return query.map((row) => row.readTable(tags)).get();
  }

  /// タグに紐づくメモを取得（リアルタイム）
  Stream<List<Memo>> watchMemosForTag(String tagId) {
    final query = select(memos).join([
      innerJoin(memoTags, memoTags.memoId.equalsExp(memos.id)),
    ])
      ..where(memoTags.tagId.equals(tagId))
      ..orderBy([
        OrderingTerm(
            expression: memos.isPinned, mode: OrderingMode.desc),
        OrderingTerm(
            expression: memos.createdAt, mode: OrderingMode.desc),
      ]);
    return query.map((row) => row.readTable(memos)).watch();
  }

  // ========================================
  // タグ使用履歴（最大20件）
  // ========================================

  /// 履歴を記録（重複は日時更新、最大20件）
  Future<void> recordTagHistory(String parentTagId,
      {String? childTagId}) async {
    final all = await select(tagHistories).get();
    final existing = all
        .where((h) =>
            h.parentTagId == parentTagId && h.childTagId == childTagId)
        .toList();

    if (existing.isNotEmpty) {
      await (update(tagHistories)
            ..where((t) => t.id.equals(existing.first.id)))
          .write(TagHistoriesCompanion(usedAt: Value(DateTime.now())));
    } else {
      await into(tagHistories).insert(TagHistoriesCompanion.insert(
        parentTagId: parentTagId,
        childTagId: Value(childTagId),
      ));
    }

    // 20件超え分を削除
    final sorted = await (select(tagHistories)
          ..orderBy([(t) => OrderingTerm.desc(t.usedAt)]))
        .get();
    if (sorted.length > 20) {
      for (final old in sorted.skip(20)) {
        await (delete(tagHistories)..where((t) => t.id.equals(old.id))).go();
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'memolette.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
