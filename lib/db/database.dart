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
  /// ソート優先度: ピン留め → 手動並び順(トップ移動) → 作成日時
  Stream<List<Memo>> watchAllMemos() {
    return (select(memos)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(
                expression: t.manualSortOrder, mode: OrderingMode.desc),
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

  /// 全メモ件数を取得
  Future<int> countMemos() async {
    final exp = memos.id.count();
    final row = await (selectOnly(memos)..addColumns([exp])).getSingle();
    return row.read(exp) ?? 0;
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

  /// 複数メモをまとめて削除
  Future<void> deleteMemos(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(memos)..where((t) => t.id.isIn(ids))).go();
  }

  /// メモをトップに移動: 既存最大の manualSortOrder + 1 を設定
  /// （ソートは isPinned → manualSortOrder → createdAt の優先順）
  Future<void> moveMemoToTop(String id) async {
    final maxRow = await (selectOnly(memos)
          ..addColumns([memos.manualSortOrder.max()]))
        .getSingle();
    final maxOrder = maxRow.read(memos.manualSortOrder.max()) ?? 0;
    await (update(memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(manualSortOrder: Value(maxOrder + 1)),
    );
  }

  /// 複数メモをまとめてトップに移動。+1, +2, +3... の順で並ぶ
  Future<void> moveMemosToTop(List<String> memoIds) async {
    if (memoIds.isEmpty) return;
    final maxRow = await (selectOnly(memos)
          ..addColumns([memos.manualSortOrder.max()]))
        .getSingle();
    final maxOrder = maxRow.read(memos.manualSortOrder.max()) ?? 0;
    await batch((b) {
      for (var i = 0; i < memoIds.length; i++) {
        b.update(
          memos,
          MemosCompanion(manualSortOrder: Value(maxOrder + i + 1)),
          where: (t) => t.id.equals(memoIds[i]),
        );
      }
    });
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
  // タグ CRUD
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

  /// 子タグ取得（特定の親タグ配下）
  Stream<List<Tag>> watchChildTags(String parentId) {
    return (select(tags)
          ..where((t) => t.parentTagId.equals(parentId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// タグを1件取得
  Future<Tag?> getTagById(String id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// タグを新規作成
  Future<Tag> createTag({
    required String name,
    int colorIndex = 1,
    String? parentTagId,
    bool isSystem = false,
  }) async {
    final id = _uuid.v4();
    // 末尾にsortOrderを設定
    final maxSort = await _maxTagSortOrder(parentTagId);
    final companion = TagsCompanion.insert(
      id: id,
      name: Value(name),
      colorIndex: Value(colorIndex),
      parentTagId: Value(parentTagId),
      isSystem: Value(isSystem),
      sortOrder: Value(maxSort + 1),
    );
    await into(tags).insert(companion);
    return (await getTagById(id))!;
  }

  /// タグを更新
  Future<void> updateTag({
    required String id,
    String? name,
    int? colorIndex,
    int? gridSize,
    String? parentTagId,
    int? sortOrder,
  }) {
    return (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        colorIndex:
            colorIndex != null ? Value(colorIndex) : const Value.absent(),
        gridSize: gridSize != null ? Value(gridSize) : const Value.absent(),
        parentTagId:
            parentTagId != null ? Value(parentTagId) : const Value.absent(),
        sortOrder:
            sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ),
    );
  }

  /// タグと、そのタグに紐づくメモも一緒に削除
  Future<void> deleteTagWithMemos(String id) async {
    // このタグに紐づく全メモIDを取得
    final memoIdQuery = await (select(memoTags)
          ..where((t) => t.tagId.equals(id)))
        .get();
    final memoIds = memoIdQuery.map((mt) => mt.memoId).toList();
    // メモ削除
    for (final memoId in memoIds) {
      await deleteMemo(memoId);
    }
    // 子タグの分も再帰的に
    final children =
        await (select(tags)..where((t) => t.parentTagId.equals(id))).get();
    for (final child in children) {
      await deleteTagWithMemos(child.id);
    }
    // タグ自体は通常の deleteTag で消す
    await deleteTag(id);
  }

  /// 親タグの並び替え（IDリストの新しい順序で sortOrder を再採番）
  Future<void> reorderParentTags(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(tags)..where((t) => t.id.equals(orderedIds[i])))
            .write(TagsCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// タグを削除（紐づく中間テーブルも削除）
  Future<void> deleteTag(String id) async {
    await (delete(memoTags)..where((t) => t.tagId.equals(id))).go();
    await (delete(todoItemTags)..where((t) => t.tagId.equals(id))).go();
    await (delete(todoListTags)..where((t) => t.tagId.equals(id))).go();
    // 子タグも削除
    final children =
        await (select(tags)..where((t) => t.parentTagId.equals(id))).get();
    for (final child in children) {
      await deleteTag(child.id);
    }
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  /// 同階層内の最大sortOrder取得
  Future<int> _maxTagSortOrder(String? parentTagId) async {
    final query = parentTagId == null
        ? (select(tags)..where((t) => t.parentTagId.isNull()))
        : (select(tags)..where((t) => t.parentTagId.equals(parentTagId)));
    final all = await query.get();
    if (all.isEmpty) return -1;
    return all.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b);
  }

  /// メモを title/content で検索（大文字小文字区別なし）
  /// ピン留め降順 → 作成日時降順
  Stream<List<Memo>> searchMemos(String query) {
    final lower = '%${query.toLowerCase()}%';
    return (select(memos)
          ..where((t) =>
              t.title.lower().like(lower) | t.content.lower().like(lower))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(
                expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// よく見るメモ: viewCount > 0 を viewCount 降順
  Stream<List<Memo>> watchFrequentMemos() {
    return (select(memos)
          ..where((t) => t.viewCount.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.viewCount, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 最近見たメモ: lastViewedAt が非null を 降順
  Stream<List<Memo>> watchRecentMemos() {
    return (select(memos)
          ..where((t) => t.lastViewedAt.isNotNull())
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastViewedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// タグなしメモを取得（リアルタイム）
  Stream<List<Memo>> watchUntaggedMemos() {
    // memoTagsに存在しないメモを取得
    return customSelect(
      'SELECT * FROM memos WHERE id NOT IN (SELECT DISTINCT memo_id FROM memo_tags) '
      'ORDER BY is_pinned DESC, manual_sort_order DESC, created_at DESC',
      readsFrom: {memos, memoTags},
    ).watch().map((rows) => rows.map((row) {
          return Memo(
            id: row.read<String>('id'),
            content: row.read<String>('content'),
            title: row.read<String>('title'),
            isMarkdown: row.read<bool>('is_markdown'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            isPinned: row.read<bool>('is_pinned'),
            manualSortOrder: row.read<int>('manual_sort_order'),
            viewCount: row.read<int>('view_count'),
            lastViewedAt: row.readNullable<DateTime>('last_viewed_at'),
            isLocked: row.read<bool>('is_locked'),
          );
        }).toList());
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

  /// メモに紐づくタグをリアルタイム監視
  Stream<List<Tag>> watchTagsForMemo(String memoId) {
    final query = select(tags).join([
      innerJoin(memoTags, memoTags.tagId.equalsExp(tags.id)),
    ])
      ..where(memoTags.memoId.equals(memoId));
    return query.map((row) => row.readTable(tags)).watch();
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
            expression: memos.manualSortOrder, mode: OrderingMode.desc),
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

  /// タグ履歴を新しい順で取得
  Future<List<TagHistory>> getRecentTagHistory() async {
    return (select(tagHistories)
          ..orderBy([(t) => OrderingTerm.desc(t.usedAt)]))
        .get();
  }

  // ========================================
  // ダミーデータ挿入（開発用）
  // ========================================

  /// 親タグが0件のときだけダミータグを挿入
  Future<void> seedDummyTags() async {
    final existing = await (select(tags)
          ..where((t) => t.parentTagId.isNull()))
        .get();
    if (existing.isNotEmpty) return;

    // Swift版スクショに合わせたダミー親タグ
    final dummyTags = [
      ('日記', 5),       // 緑系
      ('仕事', 15),      // ティール系
      ('買い物', 25),    // オレンジ系
      ('旅', 35),        // ラベンダー系
      ('映画レビュー', 45), // ピンク系
      ('バッジテスト', 55),  // 赤系
      ('長文テスト', 60),    // ミント系
      ('超重要タスク', 10),  // サーモン系
    ];

    for (final (name, colorIndex) in dummyTags) {
      await createTag(name: name, colorIndex: colorIndex);
    }
  }

  /// 全データ削除（開発用）
  Future<void> wipeAll() async {
    await transaction(() async {
      await delete(memoTags).go();
      await delete(todoItemTags).go();
      await delete(todoListTags).go();
      await delete(memos).go();
      await delete(tags).go();
      await delete(todoItems).go();
      await delete(todoLists).go();
      await delete(tagHistories).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'memolette.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
