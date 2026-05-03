import 'package:drift/drift.dart';

// ========================================
// メモテーブル
// ========================================
class Memos extends Table {
  // UUID文字列をPKとして使用
  TextColumn get id => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  BoolColumn get isMarkdown => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get manualSortOrder => integer().withDefault(const Constant(0))();
  IntColumn get viewCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastViewedAt => dateTime().nullable()();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  // メモ背景色インデックス（0=なし/白、1-72=タグカラーパレットの色）
  IntColumn get bgColorIndex => integer().withDefault(const Constant(0))();
  // カレンダー紐付け日（任意）。日付指定があれば「全カレンダー」タブの該当日に出る
  DateTimeColumn get eventDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ========================================
// タグテーブル
// ========================================
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get colorIndex => integer().withDefault(const Constant(1))();
  // 0=小(2×4), 1=中(3×6), 2=大(4×8)
  IntColumn get gridSize => integer().withDefault(const Constant(2))();
  // nil=トップレベル（親タグ）
  TextColumn get parentTagId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  // 同期で「最終更新優先」を判定するための更新時刻（Phase 9 タグ同期）
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ========================================
// ToDoアイテムテーブル
// ========================================
class TodoItems extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  // nil=ルートレベル
  TextColumn get parentId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // カレンダー紐付け日（任意）。旧 dueDate はリネームしてこれに統合（schema v5）
  DateTimeColumn get eventDate => dateTime().nullable()();
  TextColumn get memo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ========================================
// ToDoリストテーブル
// ========================================
class TodoLists extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  IntColumn get manualSortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // 結合で生成されたリストは true（カードに結合アイコンを表示）
  BoolColumn get isMerged => boolean().withDefault(const Constant(false))();
  // カレンダー紐付け日（任意）。リスト全体の日付指定
  DateTimeColumn get eventDate => dateTime().nullable()();
  // カード背景色インデックス（0=なし/白、1-31=MemoBgColors パレット）
  IntColumn get bgColorIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ========================================
// タグ使用履歴テーブル
// ========================================
class TagHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get parentTagId => text()();
  TextColumn get childTagId => text().nullable()();
  DateTimeColumn get usedAt => dateTime().withDefault(currentDateAndTime)();
}

// ========================================
// 中間テーブル: メモ ↔ タグ（多対多）
// ========================================
class MemoTags extends Table {
  TextColumn get memoId => text().references(Memos, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {memoId, tagId};
}

// ========================================
// 中間テーブル: ToDoアイテム ↔ タグ（多対多）
// ========================================
class TodoItemTags extends Table {
  TextColumn get todoItemId => text().references(TodoItems, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {todoItemId, tagId};
}

// ========================================
// 中間テーブル: ToDoリスト ↔ タグ（多対多）
// ========================================
class TodoListTags extends Table {
  TextColumn get todoListId => text().references(TodoLists, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {todoListId, tagId};
}

// ========================================
// メモ画像テーブル（1メモに複数画像、順序管理）
// filePath は Documents ディレクトリからの相対パス (例: memo_images/abc.jpg)
// remoteUrl は Firebase Storage のダウンロード URL（同期で取得済みなら格納）
// ========================================
class MemoImages extends Table {
  TextColumn get id => text()();
  TextColumn get memoId => text().references(Memos, #id)();
  TextColumn get filePath => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Phase 9 画像同期: Storage への URL（未アップなら null）
  TextColumn get remoteUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ========================================
// 競合履歴テーブル（Phase 9 Step 5e）
// 同期で「上書きされて失われた側」の内容を保存する。
// lostSide: 'local'  = リモートが勝ってローカルが上書きされた
//           'remote' = ローカルが勝ってリモートが上書きされた
// memo 本体（title / content）のみ保存。タグ/画像/ToDo は対象外。
// ========================================
class ConflictHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get memoId => text()();
  TextColumn get lostSide => text()();
  TextColumn get lostTitle => text().withDefault(const Constant(''))();
  TextColumn get lostContent => text().withDefault(const Constant(''))();
  DateTimeColumn get lostUpdatedAt => dateTime()();
  DateTimeColumn get winnerUpdatedAt => dateTime()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
}
