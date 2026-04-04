import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';

const _uuid = Uuid();

// 階層の深さごとの色
const _depthColors = [
  Colors.green,
  Colors.purple,
  Colors.orange,
  Colors.blue,
  Colors.brown,
];

Color _depthColor(int depth) =>
    _depthColors[depth.clamp(0, _depthColors.length - 1)];

/// 個別ToDoリスト画面
class TodoListScreen extends ConsumerStatefulWidget {
  final String listId;

  const TodoListScreen({super.key, required this.listId});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  TodoList? _list;
  List<_FlatRow> _flatRows = [];
  String? _editingItemId;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocus = FocusNode();
  // 展開中のアイテム
  final Set<String> _expandedItems = {};
  bool _allExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    final db = ref.read(databaseProvider);
    final list = await (db.select(db.todoLists)
          ..where((t) => t.id.equals(widget.listId)))
        .getSingleOrNull();
    final items = await (db.select(db.todoItems)
          ..where((t) => t.listId.equals(widget.listId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    if (mounted) {
      setState(() {
        _list = list;
        _flatRows = _buildFlatRows(items);
        // 初期状態: 全展開
        for (final item in items) {
          if (_hasChildren(items, item.id)) {
            _expandedItems.add(item.id);
          }
        }
      });
    }
  }

  bool _hasChildren(List<TodoItem> items, String parentId) {
    return items.any((i) => i.parentId == parentId);
  }

  /// ツリーをフラットなリストに変換
  List<_FlatRow> _buildFlatRows(List<TodoItem> allItems) {
    final rows = <_FlatRow>[];
    _addChildren(rows, allItems, null, 0);
    return rows;
  }

  void _addChildren(List<_FlatRow> rows, List<TodoItem> allItems,
      String? parentId, int depth) {
    final children = allItems
        .where((i) => i.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final item in children) {
      rows.add(_FlatRow(item: item, depth: depth));
      if (_expandedItems.contains(item.id)) {
        _addChildren(rows, allItems, item.id, depth + 1);
      }
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_list == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(_list!.title),
        actions: [
          // 全展開/折りたたみ
          IconButton(
            icon: Icon(
                _allExpanded ? Icons.unfold_less : Icons.unfold_more),
            onPressed: _toggleExpandAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // 進捗バー
          _buildProgressBar(),
          // アイテムリスト
          Expanded(
            child: _flatRows.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _flatRows.length,
                    itemBuilder: (context, index) {
                      final row = _flatRows[index];
                      return _buildItemTile(row);
                    },
                  ),
          ),
          // 新規アイテム追加バー
          _buildAddBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final rootItems =
        _flatRows.where((r) => r.depth == 0).toList();
    final total = rootItems.length;
    final done = rootItems.where((r) => r.item.isDone).length;
    final progress = total > 0 ? done / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // 進捗リング
          GestureDetector(
            onTap: total > 0 ? _confirmResetProgress : null,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.green : Colors.blueAccent,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            total == done && total > 0
                ? '全完了！'
                : '$done / $total 完了',
            style: TextStyle(
              fontSize: 14,
              color: total == done && total > 0
                  ? Colors.green
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_task, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('タスクを追加しましょう',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  /// アイテム1行
  Widget _buildItemTile(_FlatRow row) {
    final item = row.item;
    final depth = row.depth;
    final color = _depthColor(depth);
    final isEditing = _editingItemId == item.id;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => !item.isDone || true,
      onDismissed: (_) => _deleteItem(item),
      child: Container(
        padding: EdgeInsets.only(left: 16.0 + depth * 24),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: color.withValues(alpha: 0.3),
              width: depth > 0 ? 2 : 0,
            ),
          ),
        ),
        child: Row(
          children: [
            // チェックボックス（44x44タップ領域確保 — バグ#22対策）
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  item.isDone
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: item.isDone ? Colors.green : Colors.grey.withValues(alpha: 0.5),
                ),
                onPressed: () => _toggleDone(item),
              ),
            ),
            // タイトル（タップで編集）
            Expanded(
              child: isEditing
                  ? TextField(
                      controller: _editController,
                      focusNode: _editFocus,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 15,
                        color: color,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (value) =>
                          _submitEdit(item, value),
                    )
                  : GestureDetector(
                      onTap: () => _startEdit(item),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          item.title.isEmpty ? '（タイトルなし）' : item.title,
                          style: TextStyle(
                            fontSize: 15,
                            color: item.isDone
                                ? Colors.grey
                                : Colors.black87,
                            decoration: item.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
            ),
            // 子アイテム展開ボタン（子がある場合のみ）
            if (_hasChildrenInFlat(item.id))
              IconButton(
                icon: Icon(
                  _expandedItems.contains(item.id)
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                ),
                onPressed: () => _toggleExpand(item.id),
              ),
            // 子アイテム追加ボタン（最大5階層 — maxDepth=4）
            if (depth < 4)
              IconButton(
                icon: Icon(Icons.subdirectory_arrow_right,
                    size: 18, color: _depthColor(depth + 1)),
                onPressed: () => _addChildItem(item.id, depth + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasChildrenInFlat(String parentId) {
    return _flatRows.any((r) => r.item.parentId == parentId);
  }

  /// 新規追加バー（画面下部）
  Widget _buildAddBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '新しいタスクを追加...',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(CornerRadius.button),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _addRootItem(value.trim());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 操作メソッド
  // ========================================

  Future<void> _toggleDone(TodoItem item) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id)))
        .write(TodoItemsCompanion(
      isDone: Value(!item.isDone),
      updatedAt: Value(DateTime.now()),
    ));
    _loadList();
  }

  void _startEdit(TodoItem item) {
    setState(() {
      _editingItemId = item.id;
      _editController.text = item.title;
    });
    _editFocus.requestFocus();
  }

  Future<void> _submitEdit(TodoItem item, String value) async {
    final db = ref.read(databaseProvider);
    if (value.trim().isEmpty) {
      // 空なら削除
      await _deleteItem(item);
    } else {
      // 保存 + 次の兄弟を自動作成（チェーン編集）
      await (db.update(db.todoItems)
            ..where((t) => t.id.equals(item.id)))
          .write(TodoItemsCompanion(
        title: Value(value.trim()),
        updatedAt: Value(DateTime.now()),
      ));
      // 兄弟として新アイテム作成
      await _addSiblingItem(item);
    }
    setState(() => _editingItemId = null);
    _loadList();
  }

  Future<void> _addRootItem(String title) async {
    final db = ref.read(databaseProvider);
    final maxSort = _flatRows
        .where((r) => r.item.parentId == null)
        .fold<int>(0, (max, r) =>
            r.item.sortOrder > max ? r.item.sortOrder : max);
    await db.into(db.todoItems).insert(TodoItemsCompanion.insert(
      id: _uuid.v4(),
      listId: widget.listId,
      title: Value(title),
      sortOrder: Value(maxSort + 1),
    ));
    // リスト更新日時も更新
    await (db.update(db.todoLists)
          ..where((t) => t.id.equals(widget.listId)))
        .write(TodoListsCompanion(updatedAt: Value(DateTime.now())));
    _loadList();
  }

  Future<void> _addChildItem(String parentId, int depth) async {
    final db = ref.read(databaseProvider);
    final siblings = _flatRows
        .where((r) => r.item.parentId == parentId)
        .toList();
    final maxSort = siblings.isEmpty
        ? 0
        : siblings.fold<int>(
            0, (max, r) => r.item.sortOrder > max ? r.item.sortOrder : max);

    final newId = _uuid.v4();
    await db.into(db.todoItems).insert(TodoItemsCompanion.insert(
      id: newId,
      listId: widget.listId,
      parentId: Value(parentId),
      sortOrder: Value(maxSort + 1),
    ));
    _expandedItems.add(parentId);
    await _loadList();
    // 新アイテムを編集状態に
    setState(() {
      _editingItemId = newId;
      _editController.text = '';
    });
    _editFocus.requestFocus();
  }

  Future<void> _addSiblingItem(TodoItem sibling) async {
    final db = ref.read(databaseProvider);
    await db.into(db.todoItems).insert(TodoItemsCompanion.insert(
      id: _uuid.v4(),
      listId: widget.listId,
      parentId: Value(sibling.parentId),
      sortOrder: Value(sibling.sortOrder + 1),
    ));
  }

  Future<void> _deleteItem(TodoItem item) async {
    final db = ref.read(databaseProvider);
    // 子孫も削除
    await _deleteDescendants(db, item.id);
    await (db.delete(db.todoItems)..where((t) => t.id.equals(item.id)))
        .go();
    _loadList();
  }

  Future<void> _deleteDescendants(AppDatabase db, String parentId) async {
    final children = await (db.select(db.todoItems)
          ..where((t) => t.parentId.equals(parentId)))
        .get();
    for (final child in children) {
      await _deleteDescendants(db, child.id);
      await (db.delete(db.todoItems)
            ..where((t) => t.id.equals(child.id)))
          .go();
    }
  }

  void _toggleExpand(String itemId) {
    setState(() {
      if (_expandedItems.contains(itemId)) {
        _expandedItems.remove(itemId);
      } else {
        _expandedItems.add(itemId);
      }
    });
    _loadList();
  }

  void _toggleExpandAll() {
    setState(() {
      _allExpanded = !_allExpanded;
      if (_allExpanded) {
        // 全展開
        for (final row in _flatRows) {
          if (_hasChildrenInFlat(row.item.id)) {
            _expandedItems.add(row.item.id);
          }
        }
      } else {
        _expandedItems.clear();
      }
    });
    _loadList();
  }

  void _confirmResetProgress() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CornerRadius.dialog),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('チェックをリセットしますか？',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetProgress();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    child: const Text('リセット',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetProgress() async {
    final db = ref.read(databaseProvider);
    final rootItems = _flatRows
        .where((r) => r.depth == 0)
        .map((r) => r.item)
        .toList();
    for (final item in rootItems) {
      await (db.update(db.todoItems)
            ..where((t) => t.id.equals(item.id)))
          .write(TodoItemsCompanion(isDone: const Value(false)));
    }
    _loadList();
  }
}

/// フラット化されたアイテム行
class _FlatRow {
  final TodoItem item;
  final int depth;

  _FlatRow({required this.item, required this.depth});
}
