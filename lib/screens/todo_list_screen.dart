import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/text_menu_dismisser.dart';

const _uuid = Uuid();

const Color _todoTabColor = Color(0xFF8CD18C);
const Color _sysGreen = Color(0xFF34C759);
const int _maxDepth = 4; // depth 0〜4 = 最大5階層
const double _indentStep = 28.0; // 1階層あたりのインデント幅

// 階層ごとの背景色（薄め 8%、本家は opacity(0.10)*0.8）
const List<Color> _depthBgColors = [
  Color(0x1434C759), // depth 0: 緑
  Color(0x14BF5AF2), // depth 1: 紫（Apple HIG purple）
  Color(0x14FF9500), // depth 2: オレンジ
  Color(0x14007AFF), // depth 3: 青
  Color(0x14A2845E), // depth 4: 茶
];

// 階層ごとのアクセント色（濃いめ 70%、罫線・＋ボタン用）
const List<Color> _depthAccentColors = [
  Color(0xB334C759), // depth 0: 緑
  Color(0xB3BF5AF2), // depth 1: 紫（Apple HIG purple）
  Color(0xB3FF9500), // depth 2: オレンジ
  Color(0xB3007AFF), // depth 3: 青
  Color(0xB3A2845E), // depth 4: 茶
];

// フラット化された行の種別
enum _RowKind { item, addButton }

class _FlatRow {
  final String id;
  final _RowKind kind;
  final TodoItem? item;
  final String? addButtonParentId;
  final int depth;

  const _FlatRow.item(this.item, {required this.depth})
      : id = item!.id,
        kind = _RowKind.item,
        addButtonParentId = null;

  const _FlatRow.addButton({required this.addButtonParentId, required this.depth})
      : id = 'add-${addButtonParentId ?? 'root'}',
        kind = _RowKind.addButton,
        item = null;
}

class TodoListScreen extends ConsumerStatefulWidget {
  final String listId;
  const TodoListScreen({super.key, required this.listId});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  String? _editingItemId;
  // 追加先の親ID（null=ルート）。連続入力で同じ階層に追加するため保持
  String? _addingParentId;
  final Set<String> _expandedItems = {};

  bool _isEditingTitle = false;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  // ========================================
  // ストリーム
  // ========================================
  Stream<TodoList?> _watchList() {
    final db = ref.read(databaseProvider);
    return (db.select(db.todoLists)..where((t) => t.id.equals(widget.listId)))
        .watchSingleOrNull();
  }

  // 全アイテム取得（階層構造はクライアント側で組み立て）
  Stream<List<TodoItem>> _watchAllItems() {
    final db = ref.read(databaseProvider);
    return (db.select(db.todoItems)
          ..where((t) => t.listId.equals(widget.listId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  // ========================================
  // ツリー → フラットリスト変換
  // ========================================
  List<_FlatRow> _buildFlatRows(List<TodoItem> allItems) {
    // parentId別にグルーピング
    final Map<String?, List<TodoItem>> childrenMap = {};
    for (final item in allItems) {
      childrenMap.putIfAbsent(item.parentId, () => []).add(item);
    }

    final rows = <_FlatRow>[];

    void appendRows(String? parentId, int depth) {
      final children = childrenMap[parentId] ?? [];
      for (final item in children) {
        rows.add(_FlatRow.item(item, depth: depth));
        // 展開中なら子を再帰的に追加
        if (_expandedItems.contains(item.id)) {
          appendRows(item.id, depth + 1);
          // 子の末尾に追加ボタン（最大階層でなければ）
          if (depth + 1 <= _maxDepth) {
            rows.add(_FlatRow.addButton(addButtonParentId: item.id, depth: depth + 1));
          }
        }
      }
    }

    appendRows(null, 0);
    // ルートの追加ボタン
    rows.add(_FlatRow.addButton(addButtonParentId: null, depth: 0));
    return rows;
  }

  // 指定アイテムに子がいるか
  bool _hasChildren(String itemId, List<TodoItem> allItems) {
    return allItems.any((i) => i.parentId == itemId);
  }

  // ========================================
  // CRUD
  // ========================================
  Future<void> _createItem({String? parentId}) async {
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.todoItems)
          ..where((t) {
            final base = t.listId.equals(widget.listId);
            return parentId == null
                ? base & t.parentId.isNull()
                : base & t.parentId.equals(parentId);
          }))
        .get();
    final id = _uuid.v4();
    await db.into(db.todoItems).insert(TodoItemsCompanion.insert(
          id: id,
          listId: widget.listId,
          title: const Value(''),
          parentId: Value(parentId),
          sortOrder: Value(existing.length),
        ));
    if (!mounted) return;
    // 親を展開状態にする（子が見えるように）
    if (parentId != null) {
      _expandedItems.add(parentId);
    }
    setState(() {
      _editingItemId = id;
      _addingParentId = parentId;
    });
  }

  bool _isCommitting = false;
  Future<void> _commitEditWithText(String text, {bool chainNext = false}) async {
    if (_isCommitting) return;
    _isCommitting = true;
    try {
      final id = _editingItemId;
      if (id == null) return;
      final trimmed = text.trim();
      final db = ref.read(databaseProvider);
      final wasEmpty = trimmed.isEmpty;
      final parentId = _addingParentId;
      if (wasEmpty) {
        await (db.delete(db.todoItems)..where((t) => t.id.equals(id))).go();
      } else {
        await (db.update(db.todoItems)..where((t) => t.id.equals(id)))
            .write(TodoItemsCompanion(
          title: Value(trimmed),
          updatedAt: Value(DateTime.now()),
        ));
      }
      if (!mounted) return;
      setState(() {
        _editingItemId = null;
        _addingParentId = null;
      });
      if (chainNext && !wasEmpty) {
        await _createItem(parentId: parentId);
      }
    } finally {
      _isCommitting = false;
    }
  }

  Future<void> _toggleDone(TodoItem item) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id)))
        .write(TodoItemsCompanion(
      isDone: Value(!item.isDone),
      updatedAt: Value(DateTime.now()),
    ));
  }

  void _toggleExpand(String itemId) {
    setState(() {
      if (_expandedItems.contains(itemId)) {
        _expandedItems.remove(itemId);
      } else {
        _expandedItems.add(itemId);
      }
    });
  }

  Future<void> _saveTitle() async {
    final text = _titleController.text.trim();
    if (text.isEmpty) {
      setState(() => _isEditingTitle = false);
      return;
    }
    final db = ref.read(databaseProvider);
    await (db.update(db.todoLists)..where((t) => t.id.equals(widget.listId)))
        .write(TodoListsCompanion(
      title: Value(text),
      updatedAt: Value(DateTime.now()),
    ));
    setState(() => _isEditingTitle = false);
  }

  Future<void> _resetAll(List<TodoItem> items) async {
    final db = ref.read(databaseProvider);
    for (final item in items.where((i) => i.isDone)) {
      await (db.update(db.todoItems)..where((t) => t.id.equals(item.id)))
          .write(TodoItemsCompanion(
        isDone: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  // ========================================
  // build
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(),
            _buildTitle(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 0.5,
              color: Colors.black.withValues(alpha: 0.15),
            ),
            Expanded(child: _buildItemList()),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.checkmark_square,
                    size: 16, color: _todoTabColor),
                SizedBox(width: 6),
                Text(
                  'ToDo リスト',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Hiragino Sans',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            top: 4,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Text(
                  '戻る',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Hiragino Sans',
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleEditable(TodoList list) {
    if (_isEditingTitle) {
      return TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        autofocus: true,
        onTap: TextMenuDismisser.wrap(null),
        contextMenuBuilder: TextMenuDismisser.builder,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          fontFamily: 'Hiragino Sans',
          color: Colors.black,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (_) => _saveTitle(),
        onTapOutside: (_) => _saveTitle(),
      );
    }
    return GestureDetector(
      onTap: () {
        _titleController.text = list.title;
        setState(() => _isEditingTitle = true);
      },
      behavior: HitTestBehavior.opaque,
      child: Text(
        list.title.isEmpty ? '無題のリスト' : list.title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          fontFamily: 'Hiragino Sans',
          color: list.title.isEmpty
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.black,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTitle() {
    return StreamBuilder<TodoList?>(
      stream: _watchList(),
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) return const SizedBox(height: 32);
        return StreamBuilder<List<TodoItem>>(
          stream: _watchAllItems(),
          builder: (context, itemsSnap) {
            final allItems = itemsSnap.data ?? const <TodoItem>[];
            final rootItems = allItems.where((i) => i.parentId == null).toList();
            final total = rootItems.length;
            final done = rootItems.where((i) => i.isDone).length;
            final progress = total > 0 ? done / total : 0.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.bookmark_fill,
                                size: 20, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTitleEditable(list)),
                          ],
                        ),
                        if (total > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$done/$total 完了',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Hiragino Sans',
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.15),
                            width: 0.5),
                      ),
                      child: Text(
                        'タグなし',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Hiragino Sans',
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                  if (total > 0) _buildProgressDonut(rootItems, progress),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressDonut(List<TodoItem> items, double progress) {
    final percent = (progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(
                      Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  valueColor:
                      AlwaysStoppedAnimation(Colors.blue.shade500),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percent',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black87,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    '%',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: items.any((i) => i.isDone) ? () => _resetAll(items) : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.checkmark_square,
                size: 10,
                color: Colors.black.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 2),
              Text(
                'リセット',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Hiragino Sans',
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================
  // アイテムリスト（階層対応 + ドラッグ並び替え）
  // ========================================
  Widget _buildItemList() {
    return StreamBuilder<List<TodoItem>>(
      stream: _watchAllItems(),
      builder: (context, snap) {
        final allItems = snap.data ?? const <TodoItem>[];
        final flatRows = _buildFlatRows(allItems);
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 200),
            buildDefaultDragHandles: true,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) =>
                _onReorder(oldIndex, newIndex, flatRows, allItems),
            itemCount: flatRows.length,
            itemBuilder: (context, index) {
              final row = flatRows[index];
              switch (row.kind) {
                case _RowKind.item:
                  return _buildItemRow(
                    row.item!, row.depth, allItems,
                    key: ValueKey(row.id),
                    reorderIndex: index,
                  );
                case _RowKind.addButton:
                  final isRootEmpty = row.addButtonParentId == null && allItems.isEmpty;
                  final hasAnyChildren = allItems.any((i) => i.parentId != null);
                  return KeyedSubtree(
                    key: ValueKey(row.id),
                    child: _buildAddButton(
                      parentId: row.addButtonParentId,
                      depth: row.depth,
                      emptyState: isRootEmpty,
                      showGuideText: !hasAnyChildren && row.depth == 1,
                    ),
                  );
              }
            },
          ),
        );
      },
    );
  }

  /// ドラッグ並び替え（同じ親内のみ有効）
  Future<void> _onReorder(
    int oldIndex, int newIndex,
    List<_FlatRow> flatRows, List<TodoItem> allItems,
  ) async {
    if (oldIndex < 0 || oldIndex >= flatRows.length) return;
    final srcRow = flatRows[oldIndex];
    if (srcRow.kind != _RowKind.item || srcRow.item == null) return;

    final srcItem = srcRow.item!;
    final parentId = srcItem.parentId;

    // newIndex を ReorderableListView の仕様に合わせて補正
    if (newIndex > oldIndex) newIndex--;

    if (newIndex < 0 || newIndex >= flatRows.length) return;
    // 同じ親の兄弟を取得
    final siblings = allItems
        .where((i) => i.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final srcIdx = siblings.indexWhere((i) => i.id == srcItem.id);
    if (srcIdx < 0) return;

    // flatRows上のnewIndex → 兄弟内の挿入位置を算出
    // newIndexの手前までスキャンして、最後に見つけた同じ親の兄弟の直後に挿入
    int destIdx = 0;
    for (int i = 0; i <= newIndex && i < flatRows.length; i++) {
      final r = flatRows[i];
      if (r.kind == _RowKind.item && r.item != null && r.item!.id != srcItem.id) {
        if (r.item!.parentId == parentId) {
          destIdx = siblings.indexWhere((s) => s.id == r.item!.id) + 1;
        }
      }
    }
    // newIndexが先頭より前なら0
    if (newIndex == 0) destIdx = 0;
    // srcIdxを考慮（removeしてからinsertするのでズレ補正）
    if (srcIdx < destIdx) destIdx--;
    destIdx = destIdx.clamp(0, siblings.length - 1);
    if (srcIdx == destIdx) return;

    // リスト上で移動
    final moved = siblings.removeAt(srcIdx);
    siblings.insert(destIdx, moved);

    // sortOrder を振り直して保存
    final db = ref.read(databaseProvider);
    for (int i = 0; i < siblings.length; i++) {
      if (siblings[i].sortOrder != i) {
        await (db.update(db.todoItems)
              ..where((t) => t.id.equals(siblings[i].id)))
            .write(TodoItemsCompanion(
          sortOrder: Value(i),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }
  }

  Widget _buildItemRow(
    TodoItem item, int depth, List<TodoItem> allItems, {
    Key? key,
    int? reorderIndex,
  }) {
    final isEditing = _editingItemId == item.id;
    final hasChild = _hasChildren(item.id, allItems);
    final isExpanded = _expandedItems.contains(item.id);
    final canExpand = depth < _maxDepth;
    // 色帯の左端: depth 0 は全幅、depth 1+ は親チェックボックス中心線から
    // = margin(16) + pad(4) + parentIndent + innerPad(2) + iconHalf(20)
    final double bandLeft = depth == 0
        ? 0
        : 16 + 4 + (depth - 1) * _indentStep + 2 + 20;

    return Stack(
      key: key,
      children: [
        // 背景色帯（インデント付き）
        Positioned(
          left: bandLeft,
          right: 16,
          top: 0,
          bottom: 0,
          child: Container(color: _depthBgColors[depth.clamp(0, _maxDepth)]),
        ),
        // 祖先の縦線（編集中は非表示）
        if (depth > 0 && _editingItemId == null)
          for (int d = 0; d < depth; d++)
            Positioned(
              left: 16 + 4 + d * _indentStep + 2 + 20 - 0.75,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1.5,
                color: _depthAccentColors[(d + 1).clamp(0, _maxDepth)],
              ),
            ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.only(left: depth * _indentStep + 4, right: 4, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // チェックボックス
          GestureDetector(
            onTap: () => _toggleDone(item),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                item.isDone
                    ? CupertinoIcons.checkmark_square_fill
                    : CupertinoIcons.square,
                size: 40,
                color: item.isDone
                    ? _sysGreen
                    : Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // タイトル or 入力欄
          Expanded(
            child: isEditing
                ? _EditingItemField(
                    key: ValueKey('edit_${item.id}'),
                    initialText: item.title,
                    onCommit: (text) => _commitEditWithText(text),
                    onCommitChain: (text) => _commitEditWithText(text, chainNext: true),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _editingItemId = item.id;
                        _addingParentId = item.parentId;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      item.title.isEmpty ? '（空のアイテム）' : item.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Hiragino Sans',
                        color: item.isDone
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.black87,
                        decoration: item.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
          ),
          // シェブロン（右端、展開/折りたたみ）
          if (hasChild || canExpand)
            GestureDetector(
              onTap: () => _toggleExpand(item.id),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: SizedBox(
                  width: 28,
                  height: 40,
                  child: Center(
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: 18,
                        weight: 700,
                        color: isExpanded
                            ? Colors.orange
                            : (hasChild ? Colors.blue : Colors.black.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // ドラッグハンドル（将来カスタム化予定）
        ],
      ),
      ),
      ],
    );
  }

  Widget _buildAddButton({
    required String? parentId,
    required int depth,
    required bool emptyState,
    bool showGuideText = false,
  }) {
    final isChild = parentId != null;
    final accentColor = isChild
        ? _depthAccentColors[depth.clamp(0, _maxDepth)]
        : _sysGreen.withValues(alpha: 0.5);

    // ガイドテキスト表示条件
    String? guideText;
    if (emptyState) {
      guideText = '最初の項目を追加しましょう';
    } else if (isChild && showGuideText) {
      guideText = '子項目を追加できます';
    }

    // ルート追加ボタン（シンプル）
    if (!isChild) {
      return GestureDetector(
        onTap: () => _createItem(parentId: null),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(2),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(
                      CupertinoIcons.add_circled_solid,
                      size: 26,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: guideText != null
                    ? Text(guideText, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        fontFamily: 'Hiragino Sans', color: accentColor))
                    : const SizedBox(height: 44),
              ),
            ],
          ),
        ),
      );
    }

    // 子追加ボタン
    // L字の縦線X位置 = 親のチェックボックス中心
    // 親のチェックボックス中心 = margin(16) + padding(4) + parentIndent + innerPad(2) + iconHalf(20)
    final double lineX = 16 + 4 + (depth - 1) * _indentStep + 2 + 20;
    // 紫帯の左端 = L字の縦線位置
    final double bandLeft = lineX - 0.75;

    return GestureDetector(
      onTap: () => _createItem(parentId: parentId),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 階層色の帯（縦線位置から右端まで）
          Container(
            margin: EdgeInsets.only(left: bandLeft, right: 16),
            height: 22,
            color: _depthBgColors[depth.clamp(0, _maxDepth)],
          ),
          // +アイコン＋テキスト
          // チェックボックス中心に＋アイコンを揃える:
          // checkbox center = depth*28 + 4(pad) + 2(innerPad) + 20(iconHalf) = depth*28 + 26
          // +icon(18pt) left = center - 9 = depth*28 + 17
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.only(
              left: depth * _indentStep + 17,
              right: 4,
            ),
            height: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.add_circled_solid,
                  size: 18,
                  color: accentColor,
                ),
                if (guideText != null) ...[
                  const SizedBox(width: 6),
                  Text(guideText, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    fontFamily: 'Hiragino Sans', color: accentColor)),
                ],
              ],
            ),
          ),
          // 祖先の縦線 + 自分のL字（編集中は非表示）
          if (_editingItemId == null) ...[
            // 上位祖先の縦線（全高を貫通）
            for (int d = 0; d < depth - 1; d++)
              Positioned(
                left: 16 + 4 + d * _indentStep + 2 + 20 - 0.75,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1.5,
                  color: _depthAccentColors[(d + 1).clamp(0, _maxDepth)],
                ),
              ),
            // 自分の親の縦線（上端から曲がり角まで）
            Positioned(
              left: lineX - 0.75,
              top: 0,
              child: Container(width: 1.5, height: 11, color: accentColor),
            ),
            // 横線（曲がり角から右へ）
            Positioned(
              left: lineX - 0.75,
              top: 11 - 0.75,
              child: Container(width: 14, height: 1.5, color: accentColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// 編集中の単一行 TextField を独自 StatefulWidget で持つ。
class _EditingItemField extends StatefulWidget {
  final String initialText;
  final void Function(String text) onCommit;
  final void Function(String text) onCommitChain;

  const _EditingItemField({
    super.key,
    required this.initialText,
    required this.onCommit,
    required this.onCommitChain,
  });

  @override
  State<_EditingItemField> createState() => _EditingItemFieldState();
}

class _EditingItemFieldState extends State<_EditingItemField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    if (!_committed) {
      widget.onCommit(_controller.text);
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _doCommit({required bool chain}) {
    if (_committed) return;
    _committed = true;
    if (chain) {
      widget.onCommitChain(_controller.text);
    } else {
      widget.onCommit(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Hiragino Sans',
        color: Colors.black87,
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onTap: TextMenuDismisser.wrap(null),
      contextMenuBuilder: TextMenuDismisser.builder,
      textInputAction: TextInputAction.next,
      scrollPadding: const EdgeInsets.only(bottom: 100),
      onSubmitted: (_) => _doCommit(chain: true),
      onTapOutside: (_) => _doCommit(chain: false),
    );
  }
}

/// L字ライン（縦線＋横線）を描画するCustomPainter
class _LShapePainter extends CustomPainter {
  final Color color;
  const _LShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // 縦線: 上端→下端
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
    // 横線: 下端から右へ
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_LShapePainter oldDelegate) => color != oldDelegate.color;
}
