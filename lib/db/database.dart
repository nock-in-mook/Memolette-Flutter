import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../utils/image_storage.dart';
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
  MemoImages,
  ConflictHistories,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // テスト用コンストラクタ
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // メモ背景色カラム追加
            await m.addColumn(memos, memos.bgColorIndex);
          }
          if (from < 3) {
            // メモ画像テーブル追加（Phase 10）
            await m.createTable(memoImages);
          }
          if (from < 4) {
            // TodoLists.isMerged（結合で生成されたリスト判定用）
            await m.addColumn(todoLists, todoLists.isMerged);
          }
          if (from < 5) {
            // Phase 15 カレンダービュー: eventDate を 3 テーブルに統一
            // Memos / TodoLists は新規追加、TodoItems の dueDate は eventDate にリネーム
            await m.addColumn(memos, memos.eventDate);
            await m.addColumn(todoLists, todoLists.eventDate);
            await customStatement(
              'ALTER TABLE todo_items RENAME COLUMN due_date TO event_date',
            );
          }
          if (from < 6) {
            // TodoLists カード背景色（メモと同じ MemoBgColors パレット使用）
            await m.addColumn(todoLists, todoLists.bgColorIndex);
          }
          if (from < 7) {
            // Phase 9 Step 5e: 競合履歴テーブル
            await m.createTable(conflictHistories);
          }
        },
      );

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
  Future<Memo> createMemo({
    String title = '',
    String content = '',
    bool isMarkdown = false,
    int bgColorIndex = 0,
    DateTime? eventDate,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final nextOrder = await nextItemSortOrder();
    final companion = MemosCompanion.insert(
      id: id,
      title: Value(title),
      content: Value(content),
      isMarkdown: Value(isMarkdown),
      bgColorIndex: Value(bgColorIndex),
      manualSortOrder: Value(nextOrder),
      createdAt: Value(now),
      updatedAt: Value(now),
      eventDate: Value(eventDate),
    );
    await into(memos).insert(companion);
    return (await getMemoById(id))!;
  }

  /// ToDoアイテム新規作成（ダミー生成ヘルパ）。listId 必須、title / memo / parentId は任意。
  Future<TodoItem> createTodoItem({
    required String listId,
    String title = '',
    String? memo,
    String? parentId,
    int? sortOrder,
    DateTime? eventDate,
  }) async {
    final id = _uuid.v4();
    final companion = TodoItemsCompanion.insert(
      id: id,
      listId: listId,
      title: Value(title),
      memo: Value(memo),
      parentId: Value(parentId),
      sortOrder: Value(sortOrder ?? 0),
      eventDate: Value(eventDate),
    );
    await into(todoItems).insert(companion);
    return (await (select(todoItems)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// 複数TODOリストをネスト結合して新リストを作成。
  /// - 各元リストのタイトル → 新リストのルート親項目
  /// - 元の親項目 → 子項目
  /// - 元の子項目 → 孫項目（... 階層を1段下げる）
  /// 元リストは削除せずそのまま残す。新リストにはタグを付けない。
  ///
  /// 戻り値: 作成した新 TodoList
  Future<TodoList> mergeTodoLists({
    required List<String> sourceListIds,
    required String newTitle,
  }) async {
    final newList = await createTodoList(title: newTitle, isMerged: true);

    var rootSortOrder = 0;
    for (final sourceId in sourceListIds) {
      final source = await (select(todoLists)
            ..where((t) => t.id.equals(sourceId)))
          .getSingleOrNull();
      if (source == null) continue;

      // 各元リストのタイトルを新ルート親項目として挿入
      final rootTitle = source.title.isEmpty ? '無題のリスト' : source.title;
      final rootItemId = _uuid.v4();
      await into(todoItems).insert(TodoItemsCompanion.insert(
        id: rootItemId,
        listId: newList.id,
        title: Value(rootTitle),
        parentId: const Value(null),
        sortOrder: Value(rootSortOrder++),
      ));

      // 元リストの全アイテム取得
      final items = await (select(todoItems)
            ..where((t) => t.listId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

      // BFS で階層順に処理（親が map に入ってから子を処理）
      final idMap = <String, String>{};
      final queue = <TodoItem>[];
      queue.addAll(items.where((i) => i.parentId == null));
      while (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        // 元parentId=null → rootItem の子、それ以外 → マップで対応
        final newParentId = item.parentId == null
            ? rootItemId
            : idMap[item.parentId];
        if (newParentId == null) continue;

        final newItemId = _uuid.v4();
        await into(todoItems).insert(TodoItemsCompanion.insert(
          id: newItemId,
          listId: newList.id,
          title: Value(item.title),
          memo: Value(item.memo),
          parentId: Value(newParentId),
          sortOrder: Value(item.sortOrder),
          isDone: Value(item.isDone),
          eventDate: Value(item.eventDate),
        ));
        idMap[item.id] = newItemId;

        // 子要素を queue に追加
        queue.addAll(items.where((i) => i.parentId == item.id));
      }
    }
    return newList;
  }

  /// ToDoリスト新規作成（メモと一貫した manualSortOrder を設定）
  /// [isMerged] は結合で生成されたリストのとき true（UIで結合アイコン表示）
  Future<TodoList> createTodoList({
    String title = '',
    bool isMerged = false,
    DateTime? eventDate,
  }) async {
    final id = _uuid.v4();
    final nextOrder = await nextItemSortOrder();
    final companion = TodoListsCompanion.insert(
      id: id,
      title: Value(title),
      manualSortOrder: Value(nextOrder),
      isMerged: Value(isMerged),
      eventDate: Value(eventDate),
    );
    await into(todoLists).insert(companion);
    return (await (select(todoLists)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// memos と todoLists の manualSortOrder 最大値 + 1 を返す。
  /// 新規作成・トップ移動の sort order を統一するためのヘルパー。
  Future<int> nextItemSortOrder() async {
    final memoMaxRow = await (selectOnly(memos)
          ..addColumns([memos.manualSortOrder.max()]))
        .getSingle();
    final memoMax = memoMaxRow.read(memos.manualSortOrder.max()) ?? 0;
    final todoMaxRow = await (selectOnly(todoLists)
          ..addColumns([todoLists.manualSortOrder.max()]))
        .getSingle();
    final todoMax = todoMaxRow.read(todoLists.manualSortOrder.max()) ?? 0;
    return (memoMax > todoMax ? memoMax : todoMax) + 1;
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
    int? bgColorIndex,
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
        bgColorIndex: bgColorIndex != null
            ? Value(bgColorIndex)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// メモを削除（memo_tags / memo_images もカスケード削除、画像ファイルも削除）
  Future<void> deleteMemo(String id) async {
    print('[DB-DELETE] deleteMemo called id=$id\n${StackTrace.current}');
    // 先にファイルパスを取得（トランザクション外でファイル削除するため）
    final imgs = await (select(memoImages)
          ..where((t) => t.memoId.equals(id)))
        .get();
    await transaction(() async {
      await (delete(memoTags)..where((t) => t.memoId.equals(id))).go();
      await (delete(memoImages)..where((t) => t.memoId.equals(id))).go();
      await (delete(memos)..where((t) => t.id.equals(id))).go();
    });
    for (final img in imgs) {
      try {
        await ImageStorage.deleteFile(img.filePath);
      } catch (_) {}
    }
  }

  /// タイトル・本文が空のメモをまとめて削除（起動時セーフティネット）。
  /// 削除対象: タイトル空 + 本文空 + 色なし + eventDate なし + タグ無し のメモのみ。
  /// 「タイトルは消したけどタグだけ残してる」ような意図的なメモは保持する。
  /// 返り値: 削除件数
  Future<int> purgeEmptyMemos() async {
    final candidates = await (select(memos)
          ..where((t) =>
              t.title.equals('') &
              t.content.equals('') &
              t.bgColorIndex.equals(0) &
              t.eventDate.isNull()))
        .map((m) => m.id)
        .get();
    if (candidates.isEmpty) return 0;
    // タグを持つ candidates は除外
    final tagged = await (selectOnly(memoTags, distinct: true)
          ..addColumns([memoTags.memoId])
          ..where(memoTags.memoId.isIn(candidates)))
        .map((row) => row.read(memoTags.memoId))
        .get();
    final taggedSet = tagged.whereType<String>().toSet();
    final emptyIds =
        candidates.where((id) => !taggedSet.contains(id)).toList();
    if (emptyIds.isEmpty) return 0;
    print('[DB-DELETE] purgeEmptyMemos found ${emptyIds.length}件 ids=$emptyIds\n${StackTrace.current}');
    await deleteMemos(emptyIds);
    return emptyIds.length;
  }

  /// タイトルが空で、かつ配下にアイテムが 1 件もない ToDoリストを削除
  /// 返り値: 削除件数
  Future<int> purgeEmptyTodoLists() async {
    final emptyTitleLists = await (select(todoLists)
          ..where((t) => t.title.equals('')))
        .get();
    if (emptyTitleLists.isEmpty) return 0;
    final removed = <String>[];
    for (final list in emptyTitleLists) {
      final hasItems = await (selectOnly(todoItems)
            ..addColumns([todoItems.id.count()])
            ..where(todoItems.listId.equals(list.id)))
          .getSingle();
      final cnt = hasItems.read(todoItems.id.count()) ?? 0;
      if (cnt == 0) removed.add(list.id);
    }
    if (removed.isEmpty) return 0;
    await transaction(() async {
      await (delete(todoListTags)..where((t) => t.todoListId.isIn(removed)))
          .go();
      await (delete(todoLists)..where((t) => t.id.isIn(removed))).go();
    });
    return removed.length;
  }

  /// 複数メモをまとめて削除（memo_tags / memo_images もカスケード削除、画像ファイルも削除）
  Future<void> deleteMemos(List<String> ids) async {
    if (ids.isEmpty) return;
    print('[DB-DELETE] deleteMemos called ids=${ids.length}件 first=${ids.first}\n${StackTrace.current}');
    final imgs = await (select(memoImages)
          ..where((t) => t.memoId.isIn(ids)))
        .get();
    await transaction(() async {
      await (delete(memoTags)..where((t) => t.memoId.isIn(ids))).go();
      await (delete(memoImages)..where((t) => t.memoId.isIn(ids))).go();
      await (delete(memos)..where((t) => t.id.isIn(ids))).go();
    });
    for (final img in imgs) {
      try {
        await ImageStorage.deleteFile(img.filePath);
      } catch (_) {}
    }
  }

  /// メモをトップに移動: nextItemSortOrder で memos+todoLists 通しの最大+1 を設定
  /// （ソートは isPinned → manualSortOrder → createdAt の優先順）
  Future<void> moveMemoToTop(String id) async {
    final next = await nextItemSortOrder();
    await (update(memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(manualSortOrder: Value(next)),
    );
  }

  /// メモ+ToDoリストをまとめてトップに移動。
  /// nextItemSortOrder を起点に連番を振る（memos と todoLists 通し）。
  Future<void> moveItemsToTop({
    List<String> memoIds = const [],
    List<String> todoListIds = const [],
  }) async {
    if (memoIds.isEmpty && todoListIds.isEmpty) return;
    final base = (await nextItemSortOrder()) - 1;
    await batch((b) {
      var i = 1;
      for (final id in memoIds) {
        b.update(
          memos,
          MemosCompanion(manualSortOrder: Value(base + i)),
          where: (t) => t.id.equals(id),
        );
        i++;
      }
      for (final id in todoListIds) {
        b.update(
          todoLists,
          TodoListsCompanion(manualSortOrder: Value(base + i)),
          where: (t) => t.id.equals(id),
        );
        i++;
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
  // メモ画像 CRUD（Phase 10）
  // ========================================

  /// 特定メモの画像をsortOrder順で購読
  Stream<List<MemoImage>> watchMemoImages(String memoId) {
    return (select(memoImages)
          ..where((t) => t.memoId.equals(memoId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  /// 特定メモの画像を取得
  Future<List<MemoImage>> getMemoImages(String memoId) {
    return (select(memoImages)
          ..where((t) => t.memoId.equals(memoId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  /// 画像追加（sortOrder は末尾）
  Future<MemoImage> addMemoImage({
    required String memoId,
    required String filePath,
  }) async {
    final id = _uuid.v4();
    final maxRow = await (selectOnly(memoImages)
          ..addColumns([memoImages.sortOrder.max()])
          ..where(memoImages.memoId.equals(memoId)))
        .getSingle();
    final nextOrder = (maxRow.read(memoImages.sortOrder.max()) ?? -1) + 1;
    final companion = MemoImagesCompanion.insert(
      id: id,
      memoId: memoId,
      filePath: filePath,
      sortOrder: Value(nextOrder),
    );
    await into(memoImages).insert(companion);
    return (await (select(memoImages)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// 画像を1件削除（実ファイルも削除）
  Future<void> deleteMemoImage(String id) async {
    final row = await (select(memoImages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (delete(memoImages)..where((t) => t.id.equals(id))).go();
    try {
      await ImageStorage.deleteFile(row.filePath);
    } catch (_) {}
  }

  /// 指定メモの画像を全件削除（実ファイルも削除）
  /// 消しゴムボタンの本文クリアと一緒に呼ぶ
  Future<void> deleteAllMemoImages(String memoId) async {
    final rows = await (select(memoImages)
          ..where((t) => t.memoId.equals(memoId)))
        .get();
    if (rows.isEmpty) return;
    await (delete(memoImages)..where((t) => t.memoId.equals(memoId))).go();
    for (final row in rows) {
      try {
        await ImageStorage.deleteFile(row.filePath);
      } catch (_) {}
    }
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

  /// タグを新規作成。同じ親 + 同じ名前のタグが既に存在する場合はそれを返し、
  /// 新規作成はしない（重複防止）。
  Future<Tag> createTag({
    required String name,
    int colorIndex = 1,
    String? parentTagId,
    bool isSystem = false,
  }) async {
    // 重複チェック（同じ親スコープ内に同名タグがあれば既存を返す）
    final query = select(tags)..where((t) => t.name.equals(name));
    if (parentTagId == null) {
      query.where((t) => t.parentTagId.isNull());
    } else {
      query.where((t) => t.parentTagId.equals(parentTagId));
    }
    final existing = await query.getSingleOrNull();
    if (existing != null) return existing;

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
            bgColorIndex: row.read<int>('bg_color_index'),
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
    print('[DB-DELETE] removeTagFromMemo memoId=$memoId tagId=$tagId\n${StackTrace.current}');
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
  /// タグに紐づくメモの件数を取得（子タグは含まない）
  Future<int> countMemosForTag(String tagId) async {
    final exp = memoTags.memoId.count();
    final row = await (selectOnly(memoTags)
          ..addColumns([exp])
          ..where(memoTags.tagId.equals(tagId)))
        .getSingle();
    return row.read(exp) ?? 0;
  }

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
  // ToDoリスト ↔ タグ リレーション
  // ========================================

  /// ToDoリストにタグを付ける
  Future<void> addTagToTodoList(String todoListId, String tagId) {
    return into(todoListTags).insert(
      TodoListTagsCompanion.insert(todoListId: todoListId, tagId: tagId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// ToDoリストからタグを外す
  Future<void> removeTagFromTodoList(String todoListId, String tagId) {
    return (delete(todoListTags)
          ..where((t) =>
              t.todoListId.equals(todoListId) & t.tagId.equals(tagId)))
        .go();
  }

  /// ToDoリストに紐づくタグを取得
  Future<List<Tag>> getTagsForTodoList(String todoListId) {
    final query = select(tags).join([
      innerJoin(todoListTags, todoListTags.tagId.equalsExp(tags.id)),
    ])
      ..where(todoListTags.todoListId.equals(todoListId));
    return query.map((row) => row.readTable(tags)).get();
  }

  /// ToDoリストに紐づくタグをリアルタイム監視
  Stream<List<Tag>> watchTagsForTodoList(String todoListId) {
    final query = select(tags).join([
      innerJoin(todoListTags, todoListTags.tagId.equalsExp(tags.id)),
    ])
      ..where(todoListTags.todoListId.equals(todoListId));
    return query.map((row) => row.readTable(tags)).watch();
  }

  /// タグに紐づくToDoリストを取得（リアルタイム）
  Stream<List<TodoList>> watchTodoListsForTag(String tagId) {
    final query = select(todoLists).join([
      innerJoin(
          todoListTags, todoListTags.todoListId.equalsExp(todoLists.id)),
    ])
      ..where(todoListTags.tagId.equals(tagId))
      ..orderBy([
        OrderingTerm(
            expression: todoLists.isPinned, mode: OrderingMode.desc),
        OrderingTerm(
            expression: todoLists.manualSortOrder,
            mode: OrderingMode.desc),
        OrderingTerm(
            expression: todoLists.createdAt, mode: OrderingMode.desc),
      ]);
    return query.map((row) => row.readTable(todoLists)).watch();
  }

  /// TODOリスト全文検索: title, 紐付く items の title / memo のいずれかに
  /// クエリ部分一致するリストを返す（大文字小文字区別なし、重複排除）。
  /// リストアイテム (todo_items.memo) の変更もリアルタイム追従。
  Stream<List<TodoList>> searchTodoLists(String query) {
    final lower = '%${query.toLowerCase()}%';
    return customSelect(
      '''
      SELECT DISTINCT tl.* FROM todo_lists tl
      WHERE lower(tl.title) LIKE ?1
         OR tl.id IN (
           SELECT DISTINCT list_id FROM todo_items
           WHERE lower(title) LIKE ?1
              OR (memo IS NOT NULL AND lower(memo) LIKE ?1)
         )
      ORDER BY tl.is_pinned DESC,
               tl.manual_sort_order DESC,
               tl.created_at DESC
      ''',
      variables: [Variable<String>(lower)],
      readsFrom: {todoLists, todoItems},
    ).watch().map((rows) => rows.map((row) {
          return TodoList(
            id: row.read<String>('id'),
            title: row.read<String>('title'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            isPinned: row.read<bool>('is_pinned'),
            isLocked: row.read<bool>('is_locked'),
            manualSortOrder: row.read<int>('manual_sort_order'),
            isMerged: row.read<bool>('is_merged'),
            eventDate: row.readNullable<DateTime>('event_date'),
            bgColorIndex: row.read<int>('bg_color_index'),
          );
        }).toList());
  }

  /// タグなしToDoリストを取得（リアルタイム）
  Stream<List<TodoList>> watchUntaggedTodoLists() {
    return customSelect(
      'SELECT * FROM todo_lists WHERE id NOT IN '
      '(SELECT DISTINCT todo_list_id FROM todo_list_tags) '
      'ORDER BY is_pinned DESC, manual_sort_order DESC, created_at DESC',
      readsFrom: {todoLists, todoListTags},
    ).watch().map((rows) => rows.map((row) {
          return TodoList(
            id: row.read<String>('id'),
            title: row.read<String>('title'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            isPinned: row.read<bool>('is_pinned'),
            isLocked: row.read<bool>('is_locked'),
            manualSortOrder: row.read<int>('manual_sort_order'),
            isMerged: row.read<bool>('is_merged'),
            eventDate: row.readNullable<DateTime>('event_date'),
            bgColorIndex: row.read<int>('bg_color_index'),
          );
        }).toList());
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
  // カレンダー（Phase 15）
  // ========================================

  /// メモのカレンダー紐付け日を設定（null でクリア）
  Future<void> setMemoEventDate(String id, DateTime? eventDate) {
    return (update(memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(
        eventDate: Value(eventDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// ToDoリストのカレンダー紐付け日を設定（null でクリア）
  Future<void> setTodoListEventDate(String id, DateTime? eventDate) {
    return (update(todoLists)..where((t) => t.id.equals(id))).write(
      TodoListsCompanion(
        eventDate: Value(eventDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// ToDoリストの背景色を設定（0=色なし、1-31=MemoBgColors パレット）
  Future<void> setTodoListBgColor(String id, int bgColorIndex) {
    return (update(todoLists)..where((t) => t.id.equals(id))).write(
      TodoListsCompanion(
        bgColorIndex: Value(bgColorIndex),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// ToDoアイテムのカレンダー紐付け日を設定（null でクリア）
  Future<void> setTodoItemEventDate(String id, DateTime? eventDate) {
    return (update(todoItems)..where((t) => t.id.equals(id))).write(
      TodoItemsCompanion(
        eventDate: Value(eventDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 指定範囲 [start, end) で eventDate を持つアイテムの日別件数を返す。
  /// メモ + ToDoリスト + ToDoアイテム の合計（混合カウント）。
  /// 「内容あり」のみカウント: 空メモ/空リスト/空アイテムは件数バッジに含めない。
  /// 返り値の Map のキーはローカル日付 (時刻 00:00:00)。
  Stream<Map<DateTime, int>> watchEventCountsForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return customSelect(
      '''
      SELECT day, SUM(cnt) AS total FROM (
        SELECT date(event_date, 'unixepoch', 'localtime') AS day, COUNT(*) AS cnt
          FROM memos
          WHERE event_date IS NOT NULL AND event_date >= ?1 AND event_date < ?2
            AND (title != '' OR content != '' OR bg_color_index != 0)
          GROUP BY day
        UNION ALL
        SELECT date(event_date, 'unixepoch', 'localtime') AS day, COUNT(*) AS cnt
          FROM todo_lists
          WHERE event_date IS NOT NULL AND event_date >= ?1 AND event_date < ?2
            AND (title != ''
                 OR id IN (SELECT DISTINCT list_id FROM todo_items))
          GROUP BY day
        UNION ALL
        SELECT date(event_date, 'unixepoch', 'localtime') AS day, COUNT(*) AS cnt
          FROM todo_items
          WHERE event_date IS NOT NULL AND event_date >= ?1 AND event_date < ?2
            AND title != ''
          GROUP BY day
      )
      GROUP BY day
      ''',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
      readsFrom: {memos, todoLists, todoItems},
    ).watch().map((rows) {
      final result = <DateTime, int>{};
      for (final row in rows) {
        final dayStr = row.read<String>('day');
        final parts = dayStr.split('-');
        final day = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        result[day] = row.read<int>('total');
      }
      return result;
    });
  }

  /// 指定範囲の各日付サマリ（メモ件数・最初のメモラベル・ToDo件数・最初のToDoラベル）。
  /// カレンダーセル内に「オレンジ帯（メモ）/緑帯（ToDo）」を表示するために使用。
  /// 空アイテムは除外。
  Stream<Map<DateTime, DaySummary>> watchEventSummariesForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return customSelect(
      '''
      SELECT kind, label, day, sort_key FROM (
        SELECT 'memo' AS kind,
               CASE WHEN title != '' THEN title
                    WHEN content != '' THEN content
                    ELSE ''
               END AS label,
               date(event_date, 'unixepoch', 'localtime') AS day,
               created_at AS sort_key
          FROM memos
          WHERE event_date IS NOT NULL
            AND event_date >= ?1 AND event_date < ?2
            AND (title != '' OR content != '' OR bg_color_index != 0)
        UNION ALL
        SELECT 'todoList' AS kind,
               CASE WHEN title != '' THEN title
                    ELSE COALESCE(
                      (SELECT title FROM todo_items
                         WHERE list_id = todo_lists.id
                         ORDER BY sort_order LIMIT 1),
                      ''
                    )
               END AS label,
               date(event_date, 'unixepoch', 'localtime') AS day,
               created_at AS sort_key
          FROM todo_lists
          WHERE event_date IS NOT NULL
            AND event_date >= ?1 AND event_date < ?2
            AND (title != ''
                 OR id IN (SELECT DISTINCT list_id FROM todo_items))
        UNION ALL
        SELECT 'todoItem' AS kind,
               title AS label,
               date(event_date, 'unixepoch', 'localtime') AS day,
               created_at AS sort_key
          FROM todo_items
          WHERE event_date IS NOT NULL
            AND event_date >= ?1 AND event_date < ?2
            AND title != ''
      )
      ORDER BY day, sort_key
      ''',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
      readsFrom: {memos, todoLists, todoItems},
    ).watch().map((rows) {
      final result = <DateTime, DaySummary>{};
      for (final row in rows) {
        final dayStr = row.read<String>('day');
        final parts = dayStr.split('-');
        final day = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final kind = row.read<String>('kind');
        final label = row.read<String>('label');
        final cur = result[day] ?? const DaySummary();
        if (kind == 'memo') {
          result[day] = DaySummary(
            memoCount: cur.memoCount + 1,
            firstMemoLabel:
                cur.firstMemoLabel ?? (label.isEmpty ? null : label),
            todoCount: cur.todoCount,
            firstTodoLabel: cur.firstTodoLabel,
          );
        } else {
          // todoList と todoItem を ToDo として一緒にカウント
          result[day] = DaySummary(
            memoCount: cur.memoCount,
            firstMemoLabel: cur.firstMemoLabel,
            todoCount: cur.todoCount + 1,
            firstTodoLabel:
                cur.firstTodoLabel ?? (label.isEmpty ? null : label),
          );
        }
      }
      return result;
    });
  }

  /// その日のメモ取得（eventDate が day と同じ日、空メモは除外）
  Stream<List<Memo>> watchMemosForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(memos)
          ..where((t) =>
              t.eventDate.isNotNull() &
              t.eventDate.isBiggerOrEqualValue(start) &
              t.eventDate.isSmallerThanValue(end) &
              (t.title.equals('').not() |
                  t.content.equals('').not() |
                  t.bgColorIndex.equals(0).not()))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(
                expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// その日のToDoリスト取得（タイトル空でアイテム無しのリストは除外）
  Stream<List<TodoList>> watchTodoListsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return customSelect(
      '''
      SELECT * FROM todo_lists
      WHERE event_date IS NOT NULL
        AND event_date >= ?1 AND event_date < ?2
        AND (title != ''
             OR id IN (SELECT DISTINCT list_id FROM todo_items))
      ORDER BY is_pinned DESC, created_at DESC
      ''',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
      readsFrom: {todoLists, todoItems},
    ).watch().map((rows) => rows.map((row) {
          return TodoList(
            id: row.read<String>('id'),
            title: row.read<String>('title'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            isPinned: row.read<bool>('is_pinned'),
            isLocked: row.read<bool>('is_locked'),
            manualSortOrder: row.read<int>('manual_sort_order'),
            isMerged: row.read<bool>('is_merged'),
            eventDate: row.readNullable<DateTime>('event_date'),
            bgColorIndex: row.read<int>('bg_color_index'),
          );
        }).toList());
  }

  /// その日のToDoアイテム取得（sortOrder 昇順、空タイトルは除外）
  Stream<List<TodoItem>> watchTodoItemsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(todoItems)
          ..where((t) =>
              t.eventDate.isNotNull() &
              t.eventDate.isBiggerOrEqualValue(start) &
              t.eventDate.isSmallerThanValue(end) &
              t.title.equals('').not())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch();
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

  /// ダミータグ履歴を挿入（開発用）
  /// 親タグのみ・親子セット・重複を含むパターンで生成
  Future<void> seedDummyTagHistory() async {
    final existing = await getRecentTagHistory();
    // 長いタグ名テスト済みかチェック（テストタグの存在で判定）
    final hasLongTest = (await (select(tags)
          ..where((t) => t.name.equals('とても長い親タグの名前テスト用')))
        .get()).isNotEmpty;
    if (existing.isNotEmpty && hasLongTest) return;

    final parentTags = await (select(tags)
          ..where((t) => t.parentTagId.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    if (parentTags.isEmpty) return;

    // 各親タグの子タグを取得
    final childMap = <String, List<Tag>>{};
    for (final p in parentTags) {
      final children = await (select(tags)
            ..where((t) => t.parentTagId.equals(p.id)))
          .get();
      childMap[p.id] = children;
    }

    // パターン生成: 親タグのみ、親+子、重複チェック用（初回のみ）
    if (existing.isEmpty)
    for (var i = 0; i < parentTags.length && i < 5; i++) {
      final p = parentTags[i];
      final children = childMap[p.id] ?? [];

      // 親タグのみ
      await recordTagHistory(p.id);

      // 子タグがあれば親+子セットも
      if (children.isNotEmpty) {
        await recordTagHistory(p.id, childTagId: children.first.id);
      }
      if (children.length > 1) {
        await recordTagHistory(p.id, childTagId: children[1].id);
      }
    }

    // 重複テスト: 最初の親タグをもう一度記録（日時更新されるはず）
    if (parentTags.isNotEmpty) {
      await recordTagHistory(parentTags.first.id);
    }

    // 長いタグ名テスト用
    final longParent = parentTags.where((t) => t.name.length > 5).firstOrNull;
    if (longParent != null) {
      final longChildren = childMap[longParent.id] ?? [];
      final longChild = longChildren.where((t) => t.name.length > 3).firstOrNull;
      await recordTagHistory(longParent.id, childTagId: longChild?.id);
    }

    // 超長い名前のテスト用タグを一時作成して履歴に入れる
    final longTestParentId = _uuid.v4();
    final longTestChildId = _uuid.v4();
    await into(tags).insert(TagsCompanion.insert(
      id: longTestParentId, name: const Value('とても長い親タグの名前テスト用'), colorIndex: const Value(20),
    ));
    await into(tags).insert(TagsCompanion.insert(
      id: longTestChildId, name: const Value('超長い子タグ名前テスト'), colorIndex: const Value(30),
      parentTagId: Value(longTestParentId),
    ));
    await recordTagHistory(longTestParentId, childTagId: longTestChildId);
  }

  /// 長文メモのダミーデータ（開発用・「長文テスト」タグに紐付け）
  Future<void> seedDummyLongMemos() async {
    // 既にタイトル「長文テスト1」があればスキップ
    final existing = await (select(memos)
          ..where((t) => t.title.equals('長文テスト1')))
        .get();
    if (existing.isNotEmpty) return;

    // タグが無ければ作る
    var longTag = await (select(tags)
          ..where((t) => t.name.equals('長文テスト')))
        .getSingleOrNull();
    longTag ??= await createTag(name: '長文テスト', colorIndex: 60);

    // 基本パラグラフ（~200文字）
    const para1 =
        '朝の光が部屋に差し込む頃、窓辺のコーヒーカップから立ちのぼる湯気が、昨夜の考えごとをゆっくりと溶かしていくような気がする。日々の中で見過ごしがちな小さな瞬間こそ、後から振り返って意味を持つことが多い。'
        'そういうものを丁寧に拾い集めていきたいと、最近よく思う。忙しない時間の中で、自分の呼吸を取り戻すための時間を意識して作ることが、結局は一番遠回りに見えて最短の道なのかもしれない。';
    const para2 =
        '本を読んでいると、まったく関係のない出来事の間に思いがけないつながりを見つけることがある。ある章で登場した言葉が、何日も経ってから別の場面で急に意味を持ちはじめる。'
        '情報は蓄積されるだけでなく、発酵する時間を経て、ようやく自分の一部になっていく。急いで答えを出すよりも、保留にしておける余白を大切にしたい。';
    const para3 =
        '散歩の途中でふと立ち止まる。街路樹の葉が光を透かして揺れているのを見ながら、こういう景色は毎日あるのに気付くのはまれだ、と感じる。'
        '観察する目を持つには、余裕が必要で、余裕は意識して作らないと勝手には生まれない。小さな非効率を肯定することが、豊かさの入り口なのかもしれない。';
    const para4 =
        '書きながら考えるという行為は、話しながら考えるのとはまるで違う。書き出すことで輪郭がはっきりしてくる。'
        '曖昧な感覚のままでは扱えないが、言葉に起こすと、まるで別のものを観察するように自分の思考を見ることができる。';

    // 3パターンの長文（約800 / 1600 / 3200文字）
    final memo1Content =
        [para1, para2, para3, para4].join('\n\n');
    final memo2Content =
        [para1, para2, para3, para4, para1, para2, para3, para4].join('\n\n');
    final memo3Content = List.generate(
            16, (i) => [para1, para2, para3, para4][i % 4])
        .join('\n\n');

    final seeds = [
      ('長文テスト1', memo1Content),
      ('長文テスト2 - 中程度の文量', memo2Content),
      ('長文テスト3 - タイトルも長めにしてみる超長大なメモ', memo3Content),
    ];

    for (final (title, content) in seeds) {
      final memo = await createMemo(title: title, content: content);
      await addTagToMemo(memo.id, longTag.id);
    }
  }

  /// 爆速モード動作確認用: 指定タグに大量のダミーメモを投入
  Future<void> seedDummyBulkMemos({
    String tagName = 'ダミー70',
    int count = 70,
  }) async {
    // 既に同名タグがあれば一切 seed しない（過去の不具合：count 比較で
    // 「足りない分を再投入」していたが、メモが何かの理由で減ると毎起動で
    // 70 件まるごと再投入されてダミーが増殖する重大バグの原因だった）。
    final existingTag = await (select(tags)
          ..where((t) => t.name.equals(tagName)))
        .getSingleOrNull();
    if (existingTag != null) return;

    final tag = await createTag(name: tagName, colorIndex: 42);
    for (int i = 1; i <= count; i++) {
      final memo = await createMemo(
        title: '$tagName-${i.toString().padLeft(3, '0')}',
        content: 'ダミーメモ#$i: 爆速整理モードの動作確認用です。適当な本文を入れておきます。',
      );
      await addTagToMemo(memo.id, tag.id);
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
      await delete(conflictHistories).go();
    });
  }

  // ========================================
  // 競合履歴 CRUD（Phase 9 Step 5e）
  // ========================================

  /// 競合履歴を1件記録する
  Future<void> recordConflict({
    required String memoId,
    required String lostSide, // 'local' or 'remote'
    required String lostTitle,
    required String lostContent,
    required DateTime lostUpdatedAt,
    required DateTime winnerUpdatedAt,
  }) async {
    await into(conflictHistories).insert(
      ConflictHistoriesCompanion.insert(
        memoId: memoId,
        lostSide: lostSide,
        lostTitle: Value(lostTitle),
        lostContent: Value(lostContent),
        lostUpdatedAt: lostUpdatedAt,
        winnerUpdatedAt: winnerUpdatedAt,
      ),
    );
  }

  /// 競合履歴を新しい順に流す
  Stream<List<ConflictHistory>> watchAllConflicts() {
    return (select(conflictHistories)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.recordedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 競合履歴を1件取得
  Future<ConflictHistory?> getConflictById(int id) {
    return (select(conflictHistories)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 競合履歴を全削除
  Future<void> deleteAllConflicts() async {
    await delete(conflictHistories).go();
  }

  /// 競合履歴を1件削除
  Future<void> deleteConflict(int id) async {
    await (delete(conflictHistories)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'memolette.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// カレンダーセル内に表示するための、その日のサマリ。
/// メモ・ToDo それぞれ「件数」と「最初のラベル（タイトル or 1行目 or 1項目目）」を持つ。
class DaySummary {
  final int memoCount;
  final String? firstMemoLabel;
  final int todoCount;
  final String? firstTodoLabel;

  const DaySummary({
    this.memoCount = 0,
    this.firstMemoLabel,
    this.todoCount = 0,
    this.firstTodoLabel,
  });
}
