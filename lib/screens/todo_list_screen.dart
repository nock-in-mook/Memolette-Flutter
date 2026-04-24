import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/safe_dialog.dart';
import '../utils/text_menu_dismisser.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/frosted_alert_dialog.dart';
import '../widgets/new_tag_sheet.dart';
import '../widgets/tag_dial_view.dart';

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
  /// 埋め込みモード: iPad 横画面の右カラムに埋め込まれる時は true。
  /// Scaffold/SafeArea を外し、戻るボタンを非表示にする（閉じる動線は左側にあるため）。
  final bool embedded;
  const TodoListScreen({
    super.key,
    required this.listId,
    this.embedded = false,
  });

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  String? _editingItemId;
  // 追加先の親ID（null=ルート）。連続入力で同じ階層に追加するため保持
  String? _addingParentId;
  final Set<String> _expandedItems = {};
  // メモ編集中のアイテムID（null=メモ編集なし）
  String? _memoEditingItemId;
  // メモ表示中（閲覧）のアイテムID
  String? _memoViewItemId;
  // 選択削除モード
  bool _isSelectMode = false;
  final Set<String> _selectedItems = {};
  // スワイプ削除の一斉クローズ通知
  final ValueNotifier<int> _swipeCloseNotifier = ValueNotifier<int>(0);
  bool _isAnySwipeOpen = false;

  // ルーレット
  bool _rouletteOpen = false;
  bool _showTagHistory = false;
  List<TagHistory> _tagHistoryItems = [];
  // 履歴スクロールシェブロン
  bool _historyCanScrollUp = false;
  bool _historyCanScrollDown = false;

  void _closeSwipeIfOpen() {
    if (_isAnySwipeOpen) {
      _swipeCloseNotifier.value++;
      _isAnySwipeOpen = false;
    }
  }

  bool _isEditingTitle = false;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _swipeCloseNotifier.dispose();
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

  // 初回展開フラグ
  bool _didInitialExpand = false;

  bool _isAllExpanded(List<TodoItem> allItems) {
    final parents = allItems.where((i) => _hasChildren(i.id, allItems)).map((i) => i.id).toSet();
    return parents.isNotEmpty && parents.every((id) => _expandedItems.contains(id));
  }

  void _expandAll(List<TodoItem> allItems, {bool withMemo = false}) {
    setState(() {
      for (final item in allItems) {
        if (_hasChildren(item.id, allItems)) {
          _expandedItems.add(item.id);
        }
      }
      if (withMemo) {
        for (final item in allItems) {
          if ((item.memo ?? '').isNotEmpty) {
            _memoViewItemId = null; // 複数展開は未対応、将来対応
          }
        }
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedItems.clear();
      _memoEditingItemId = null;
      _memoViewItemId = null;
    });
  }

  void _showExpandDialog(List<TodoItem> allItems) {
    focusSafe(
      context,
      () => showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, anim1, anim2) {
          return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('メモを含む項目があります',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        fontFamily: 'Hiragino Sans')),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _expandAll(allItems);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text('リストのみ展開',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                            fontFamily: 'Hiragino Sans', color: Color(0xFF007AFF))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _expandAll(allItems, withMemo: true);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBF5AF2).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text('メモも全展開',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                            fontFamily: 'Hiragino Sans', color: Color(0xFFBF5AF2))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Text('キャンセル',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                            fontFamily: 'Hiragino Sans',
                            color: Colors.black.withValues(alpha: 0.5))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
        transitionBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      ),
    );
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
    if (_isAnySwipeOpen) {
      _closeSwipeIfOpen();
      return;
    }
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

  /// アイテムと全子孫を再帰的に削除
  Future<void> _deleteItemRecursive(String itemId, List<TodoItem> allItems) async {
    final db = ref.read(databaseProvider);
    final children = allItems.where((i) => i.parentId == itemId).toList();
    for (final child in children) {
      await _deleteItemRecursive(child.id, allItems);
    }
    await (db.delete(db.todoItems)..where((t) => t.id.equals(itemId))).go();
  }

  Future<void> _toggleDone(TodoItem item) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id)))
        .write(TodoItemsCompanion(
      isDone: Value(!item.isDone),
      updatedAt: Value(DateTime.now()),
    ));
  }

  void _toggleMemo(TodoItem item) {
    if (_isSelectMode) return;
    if (_isAnySwipeOpen) { _closeSwipeIfOpen(); return; }
    setState(() {
      if (_memoEditingItemId == item.id || _memoViewItemId == item.id) {
        // 展開中/編集中 → 折りたたみ
        _memoEditingItemId = null;
        _memoViewItemId = null;
      } else if ((item.memo ?? '').isEmpty) {
        // メモ空 → 編集モード
        _memoEditingItemId = item.id;
        _memoViewItemId = null;
      } else {
        // メモあり＆折りたたみ中 → 展開
        _memoViewItemId = item.id;
        _memoEditingItemId = null;
      }
    });
  }

  Future<void> _saveMemo(String itemId, String text) async {
    final trimmed = text.trim();
    final db = ref.read(databaseProvider);
    await (db.update(db.todoItems)..where((t) => t.id.equals(itemId)))
        .write(TodoItemsCompanion(
      memo: Value(trimmed.isEmpty ? null : trimmed),
      updatedAt: Value(DateTime.now()),
    ));
    if (!mounted) return;
    setState(() {
      _memoEditingItemId = null;
      _memoViewItemId = null;
    });
  }

  Future<void> _showMemoDeleteDialog(String itemId) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'メモを削除',
      message: 'このメモを削除しますか？',
    );
    if (confirmed && mounted) _saveMemo(itemId, '');
  }

  void _toggleExpand(String itemId) {
    if (_isAnySwipeOpen) {
      _closeSwipeIfOpen();
      return;
    }
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
  // 選択削除
  // ========================================
  void _toggleSelect(String itemId, List<TodoItem> allItems) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
      // 親選択時は子孫も連動
      _selectDescendants(itemId, allItems);
    });
  }

  void _selectDescendants(String itemId, List<TodoItem> allItems) {
    final isSelected = _selectedItems.contains(itemId);
    for (final child in allItems.where((i) => i.parentId == itemId)) {
      if (isSelected) {
        _selectedItems.add(child.id);
      } else {
        _selectedItems.remove(child.id);
      }
      _selectDescendants(child.id, allItems);
    }
  }

  Future<void> _deleteSelectedItems(List<TodoItem> allItems) async {
    final toDelete = _selectedItems.toSet();
    for (final id in toDelete) {
      await _deleteItemRecursive(id, allItems);
    }
    setState(() {
      _isSelectMode = false;
      _selectedItems.clear();
    });
  }

  void _showDeleteSelectedConfirm(List<TodoItem> allItems) {
    final count = _selectedItems.length;
    focusSafe(
      context,
      () => showGeneralDialog(
        context: context,
        barrierDismissible: true, barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('選択した項目を削除', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Hiragino Sans')),
                  const SizedBox(height: 12),
                  Text('$count件の項目を削除しますか？',
                    style: TextStyle(fontSize: 13, fontFamily: 'Hiragino Sans',
                      color: Colors.black.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteSelectedItems(allItems);
                    },
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Text('削除する', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans', color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text('キャンセル', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                        color: Colors.black.withValues(alpha: 0.5))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _clearAllItems() async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.todoItems)
          ..where((t) => t.listId.equals(widget.listId)))
        .go();
    setState(() {
      _expandedItems.clear();
      _memoEditingItemId = null;
      _memoViewItemId = null;
    });
  }

  void _showDeleteMenu(List<TodoItem> allItems) {
    focusSafe(
      context,
      () => showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('項目を削除', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Hiragino Sans')),
                  const SizedBox(height: 16),
                  // 選択して削除
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() { _isSelectMode = true; _selectedItems.clear(); });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.checkmark_circle, size: 14, color: Color(0xFF007AFF)),
                          SizedBox(width: 6),
                          Text('選択して削除', style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                            color: Color(0xFF007AFF))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 全件削除
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showClearAllDialog(allItems);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.trash, size: 14, color: Colors.red),
                          SizedBox(width: 6),
                          Text('全件削除', style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                            color: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text('キャンセル', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                        color: Colors.black.withValues(alpha: 0.5))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _showClearAllDialog(List<TodoItem> allItems) {
    focusSafe(
      context,
      () => showGeneralDialog(
        context: context,
        barrierDismissible: true, barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, _, __) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('全項目を削除', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Hiragino Sans')),
                  const SizedBox(height: 12),
                  Text('${allItems.length}件の項目を全て削除します\nリスト自体は残ります',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontFamily: 'Hiragino Sans',
                      color: Colors.black.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showClearAllConfirm();
                    },
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Text('全て削除する', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans', color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text('キャンセル', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                        color: Colors.black.withValues(alpha: 0.5))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _showClearAllConfirm() {
    focusSafe(
      context,
      () => showGeneralDialog(
      context: context,
      barrierDismissible: true, barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('本当によろしいですか？', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Hiragino Sans')),
                  const SizedBox(height: 8),
                  Text('全項目を削除します。この操作は取り消せません。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontFamily: 'Hiragino Sans',
                      color: Colors.black.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _clearAllItems();
                    },
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Text('削除する', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, fontFamily: 'Hiragino Sans', color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text('キャンセル', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                        color: Colors.black.withValues(alpha: 0.5))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ========================================
  // build
  // ========================================
  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      onTap: () {
        _closeSwipeIfOpen();
        // ルーレット閉じはグレー背景タップで行う（ここで閉じると履歴ボタン等が競合する）
      },
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(),
              _buildTitle(),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 0.5,
                color: Colors.black.withValues(alpha: 0.15),
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildItemList(),
                    // フッター（下端フロート）
                    Positioned(
                      left: 0, right: 0, bottom: 8,
                      child: _buildFooter(),
                    ),
                    // ルーレットオーバーレイ（常に配置、アニメーションで開閉）
                    _buildRouletteOverlay(),
                  ],
                ),
              ),
            ],
          ),
          // タグ履歴オーバーレイ（トレー下端のすぐ下に表示）
          if (_showTagHistory && _rouletteOpen)
            Positioned(
              right: 16,
              top: 273 + 150,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                child: _buildTagHistoryOverlay(),
              ),
            ),
        ],
      ),
    );
    if (widget.embedded) {
      // iPad 横画面の右カラム埋め込み: Scaffold/SafeArea は親側で担保
      return ColoredBox(color: Colors.white, child: content);
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: content),
    );
  }

  Widget _buildFooter() {
    return StreamBuilder<List<TodoItem>>(
      stream: _watchAllItems(),
      builder: (context, snap) {
        final allItems = snap.data ?? const <TodoItem>[];
        if (allItems.isEmpty || _editingItemId != null || _memoEditingItemId != null) {
          return const SizedBox.shrink();
        }
        if (_isSelectMode) {
          // 選択モードではヒント非表示
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // キャンセル
              GestureDetector(
                onTap: () => setState(() { _isSelectMode = false; _selectedItems.clear(); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: Text('キャンセル', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                    color: Colors.black.withValues(alpha: 0.5))),
                ),
              ),
              const SizedBox(width: 12),
              // N件削除
              GestureDetector(
                onTap: _selectedItems.isEmpty ? null : () => _showDeleteSelectedConfirm(allItems),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: _selectedItems.isEmpty ? Colors.grey : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.trash, size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('${_selectedItems.length}件削除', style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                        color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        // 通常モード: ヒントテキスト + 削除メニューボタン
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヒントテキスト
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.hand_draw, size: 12,
                  color: Colors.black.withValues(alpha: 0.16)),
                const SizedBox(width: 5),
                Text('タップで編集 ・ 長押しで並び替え ・ 左スワイプで削除',
                  style: TextStyle(fontSize: 13, fontFamily: 'Hiragino Sans',
                    color: Colors.black.withValues(alpha: 0.16))),
              ],
            ),
            const SizedBox(height: 8),
            // 削除ボタン
            GestureDetector(
              onTap: () => _showDeleteMenu(allItems),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.list_bullet, size: 14,
                      color: Colors.red.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Text('削除', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Hiragino Sans',
                      color: Colors.red.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
          // 戻るボタン（埋め込みモードでは非表示: 左カラム側に閉じる導線あり）
          if (!widget.embedded)
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
          // 右上: 全展開/全収納ボタン
          Positioned(
            right: 12,
            top: 4,
            child: StreamBuilder<List<TodoItem>>(
              stream: _watchAllItems(),
              builder: (context, snap) {
                final allItems = snap.data ?? const <TodoItem>[];
                final hasAnyChild = allItems.any((i) => _hasChildren(i.id, allItems));
                if (!hasAnyChild) return const SizedBox.shrink();
                if (!_didInitialExpand && allItems.isNotEmpty) {
                  _didInitialExpand = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _expandAll(allItems);
                  });
                }
                final expanded = _isAllExpanded(allItems);
                return GestureDetector(
                  onTap: () {
                    if (expanded) {
                      _collapseAll();
                    } else {
                      final hasAnyMemo = allItems.any((i) => (i.memo ?? '').isNotEmpty);
                      if (hasAnyMemo) {
                        _showExpandDialog(allItems);
                      } else {
                        _expandAll(allItems);
                      }
                    }
                  },
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
                    child: Text(
                      expanded ? '全収納' : '全展開',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Hiragino Sans',
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),
                );
              },
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
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        onSubmitted: (_) => _saveTitle(),
        onTapOutside: (_) => _saveTitle(),
      );
    }
    return GestureDetector(
      onTap: () {
        if (_isSelectMode) return;
        if (_isAnySwipeOpen) {
          _closeSwipeIfOpen();
          return;
        }
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1行目: ブックマーク + タイトル（フル幅） + 円グラフ
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.bookmark_fill,
                          size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTitleEditable(list)),
                      if (total > 0) ...[
                        const SizedBox(width: 8),
                        _buildProgressDonut(rootItems, progress),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 2行目: 完了数 + タグバッジ + リセット（常に表示）
                  Row(
                    children: [
                      Text(
                        '$done/$total 完了',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Hiragino Sans',
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: _buildTagBadge(),
                      ),
                      // リセットボタン（チェックが1つ以上あるとき）
                      if (done > 0) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showResetDialog(rootItems, done),
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
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // タグバッジ用テキストスタイル（メモ入力画面と同じ）
  static const TextStyle _parentTagTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: '.SF Pro Rounded',
    fontFamilyFallback: ['SF Pro Rounded', 'Hiragino Sans'],
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
    color: Colors.black,
  );
  static const TextStyle _childTagTextStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    fontFamily: '.SF Pro Rounded',
    fontFamilyFallback: ['SF Pro Rounded', 'Hiragino Sans'],
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
    color: Colors.black,
  );
  static const StrutStyle _parentStrutStyle = StrutStyle(
    fontSize: 11, height: 1.0, forceStrutHeight: true, leading: 0,
  );
  static const StrutStyle _childStrutStyle = StrutStyle(
    fontSize: 10, height: 1.0, forceStrutHeight: true, leading: 0,
  );
  static const TextHeightBehavior _tightHeight = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// タグバッジ（タップでルーレット開閉、メモ入力画面と同じ重ね表示）
  Widget _buildTagBadge() {
    return StreamBuilder<List<Tag>>(
      stream: ref.read(databaseProvider).watchTagsForTodoList(widget.listId),
      builder: (context, snap) {
        final tags = snap.data ?? const <Tag>[];
        final parentTag = tags.where((t) => t.parentTagId == null).firstOrNull;
        final childTag = parentTag != null
            ? tags.where((t) => t.parentTagId == parentTag.id).firstOrNull
            : null;

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => setState(() => _rouletteOpen = !_rouletteOpen),
            behavior: HitTestBehavior.opaque,
            child: parentTag != null
                ? _buildTagDisplay(parentTag, childTag)
                : Container(
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
        );
      },
    );
  }

  /// 親タグ＋子タグの重ね合わせ表示（本家 tagDisplay 準拠）
  Widget _buildTagDisplay(Tag parent, Tag? child) {
    final parentColor = TagColors.getColor(parent.colorIndex);

    if (child != null) {
      final childColor = TagColors.getColor(child.colorIndex);
      final parentWidget = Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
        decoration: BoxDecoration(
          color: parentColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          parent.name,
          style: _parentTagTextStyle,
          strutStyle: _parentStrutStyle,
          textHeightBehavior: _tightHeight,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      final childWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: childColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          child.name,
          style: _childTagTextStyle,
          strutStyle: _childStrutStyle,
          textHeightBehavior: _tightHeight,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      return IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: parentWidget),
            Flexible(
              child: Transform.translate(
                offset: const Offset(-4, 1.5),
                child: childWidget,
              ),
            ),
          ],
        ),
      );
    }

    // 親タグのみ
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: parentColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        parent.name,
        style: _parentTagTextStyle,
        strutStyle: _parentStrutStyle,
        textHeightBehavior: _tightHeight,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// ルーレットオーバーレイ（グレー背景 + トレー + ダイヤル）
  Widget _buildRouletteOverlay() {
    final allTags = ref.watch(allTagsProvider).valueOrNull ?? const <Tag>[];
    final parentTags = allTags.where((t) => t.parentTagId == null).toList();

    return StreamBuilder<List<Tag>>(
      stream: ref.read(databaseProvider).watchTagsForTodoList(widget.listId),
      builder: (context, snap) {
        final attachedTags = snap.data ?? const <Tag>[];
        final currentParent =
            attachedTags.where((t) => t.parentTagId == null).firstOrNull;
        final currentChild = currentParent != null
            ? attachedTags
                .where((t) => t.parentTagId == currentParent.id)
                .firstOrNull
            : null;

        final parentOptions = [
          const TagDialOption(id: null, name: 'タグなし', color: Colors.white),
          ...parentTags.map((t) => TagDialOption(
                id: t.id,
                name: t.name,
                color: TagColors.getColor(t.colorIndex),
              )),
        ];

        final childTags = currentParent != null
            ? allTags
                .where((t) => t.parentTagId == currentParent.id)
                .toList()
            : <Tag>[];
        final childOptions = [
          const TagDialOption(id: null, name: '子タグなし', color: Colors.white),
          ...childTags.map((t) => TagDialOption(
                id: t.id,
                name: t.name,
                color: TagColors.getColor(t.colorIndex),
              )),
        ];

        // トレーサイズ（メモ入力画面と同じ）
        const double trayBodyWidth = 300.0;
        const double tabW = 19.0;
        const double trayTotalWidth = trayBodyWidth + tabW;
        const double dialOverhang = 60.0;
        const Color trayColor = Color.fromRGBO(142, 142, 147, 1);

        // スライドオフセット（閉じ時: トレー全幅分右に隠す）
        final slideOffset = _rouletteOpen ? 0.0 : (trayTotalWidth + dialOverhang);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // グレー背景（タップで閉じる、フェードアニメ）
            Positioned(
              left: 0, right: 0, top: -200, bottom: 0,
              child: IgnorePointer(
                ignoring: !_rouletteOpen,
                child: GestureDetector(
                  onTap: _closeRoulette,
                  child: AnimatedOpacity(
                    opacity: _rouletteOpen ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            // トレー + ルーレット（スライドアニメ）
            Positioned(
              right: 0,
              top: 0,
              height: 22 + 211 + 40,
              width: trayTotalWidth + dialOverhang,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(slideOffset, 0, 0),
              child: GestureDetector(
                onTap: () {}, // トレー内タップではオーバーレイを閉じない
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // トレー背景（タップで収納）
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _closeRoulette,
                        behavior: HitTestBehavior.opaque,
                        child: CustomPaint(
                        painter: _TrayPainter(
                          color: trayColor,
                          tabWidth: tabW,
                          tabHeight: 22,
                          tabRadius: 6,
                          bodyRadius: 10,
                          innerRadius: 10,
                        ),
                        child: SizedBox(
                          width: trayTotalWidth,
                          child: Column(
                            children: [
                              // ラベル帯（22pt）
                              SizedBox(
                                height: 22,
                                child: Stack(
                                  children: [
                                    // しまう三角マーク（タップで閉じる）
                                    Positioned(
                                      left: 0, top: 0, bottom: 0, width: tabW,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _closeRoulette,
                                        child: Center(
                                          child: Text(
                                            '\u25B6',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 親タグラベル
                                    Positioned(
                                      right: 221, top: 0, height: 22,
                                      child: Center(
                                        child: Text(
                                          '親タグ',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(alpha: 0.75),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 子タグラベル
                                    Positioned(
                                      right: 104, top: 0, height: 22,
                                      child: Center(
                                        child: Text(
                                          '子タグ',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(alpha: 0.75),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 収納ボタン（ルーレット211ptの中央に配置）
                              SizedBox(
                                height: 211,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _closeRoulette,
                                    child: Transform.translate(
                                      offset: const Offset(-8, 0),
                                      child: SizedBox(
                                        width: 36,
                                        child: Center(
                                          child: Text(
                                            '\u203A',
                                            style: TextStyle(
                                              fontSize: 60,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white.withValues(alpha: 0.5),
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // 下部ボタン（親タグ追加 / 子タグ追加 / 履歴）
                              SizedBox(
                                height: 40,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 親タグ追加
                                    Positioned(
                                      right: 191, top: 0,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _openAddParentTagSheet,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_circle, size: 14,
                                                color: Colors.white.withValues(alpha: 0.9)),
                                            const SizedBox(width: 3),
                                            Text('親タグ追加',
                                              style: TextStyle(fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withValues(alpha: 0.9))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 子タグ追加
                                    Positioned(
                                      right: 78, top: 0,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _openAddChildTagSheet,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_circle_outline, size: 13,
                                                color: Colors.white.withValues(alpha: 0.8)),
                                            const SizedBox(width: 3),
                                            Text('子タグ追加',
                                              style: TextStyle(fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withValues(alpha: 0.8))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 履歴
                                    Positioned(
                                      right: 8, top: 9,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _toggleTagHistory,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                _showTagHistory
                                                    ? Icons.keyboard_arrow_down
                                                    : Icons.chevron_right,
                                                size: 12,
                                                color: Colors.white.withValues(alpha: 0.8)),
                                            const SizedBox(width: 3),
                                            Text('履歴',
                                              style: TextStyle(fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withValues(alpha: 0.8))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                    // ルーレット（トレー上のダイヤル）
                    Positioned(
                      right: 0,
                      top: 22,
                      height: 211,
                      width: trayBodyWidth + dialOverhang,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Transform.translate(
                          offset: Offset(-dialOverhang, 0),
                          child: TagDialView(
                            height: 211,
                            parentOptions: parentOptions,
                            childOptions: childOptions,
                            selectedParentId: currentParent?.id,
                            selectedChildId: currentChild?.id,
                            isOpen: true,
                            onParentSelected: (id) =>
                                _onRouletteTagSelected(id, false),
                            onChildSelected: (id) =>
                                _onRouletteTagSelected(id, true),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ルーレットでタグ選択時の処理
  Future<void> _onRouletteTagSelected(String? id, bool isChild) async {
    final db = ref.read(databaseProvider);
    final attachedTags = await db.getTagsForTodoList(widget.listId);

    if (id == null) {
      // 「タグなし」/「子タグなし」選択 → タグを外す
      if (!isChild) {
        for (final tag in attachedTags) {
          await db.removeTagFromTodoList(widget.listId, tag.id);
        }
      } else {
        for (final tag
            in attachedTags.where((t) => t.parentTagId != null)) {
          await db.removeTagFromTodoList(widget.listId, tag.id);
        }
      }
    } else {
      if (!isChild) {
        // 親タグ選択: 既存の親・子タグを外して新しい親タグを付ける
        for (final tag in attachedTags) {
          await db.removeTagFromTodoList(widget.listId, tag.id);
        }
        await db.addTagToTodoList(widget.listId, id);
      } else {
        // 子タグ選択: 既存の子タグを外して新しい子タグを付ける
        for (final tag
            in attachedTags.where((t) => t.parentTagId != null)) {
          await db.removeTagFromTodoList(widget.listId, tag.id);
        }
        await db.addTagToTodoList(widget.listId, id);
      }
    }
    if (mounted) setState(() {});
  }

  /// 親タグ追加シート
  Future<void> _openAddParentTagSheet() async {
    FocusScope.of(context).unfocus();
    final newTagId = await NewTagSheet.show(context: context);
    if (newTagId == null) return;
    await _onRouletteTagSelected(newTagId, false);
  }

  /// 子タグ追加シート（親タグ未選択時は警告）
  Future<void> _openAddChildTagSheet() async {
    FocusScope.of(context).unfocus();
    final db = ref.read(databaseProvider);
    final attachedTags = await db.getTagsForTodoList(widget.listId);
    final parentTag =
        attachedTags.where((t) => t.parentTagId == null).firstOrNull;
    if (parentTag == null) {
      if (!mounted) return;
      await showFrostedAlert(
        context: context,
        title: '親タグを選んでください',
        message: '子タグを追加するには、先にルーレットで親タグを選択してください。',
      );
      return;
    }
    final newTagId = await NewTagSheet.show(
      context: context,
      parentTagId: parentTag.id,
    );
    if (newTagId == null) return;
    await _onRouletteTagSelected(newTagId, true);
  }

  /// ルーレットを閉じる（タグ履歴を記録）
  Future<void> _closeRoulette() async {
    if (!_rouletteOpen) return;
    final db = ref.read(databaseProvider);
    final attachedTags = await db.getTagsForTodoList(widget.listId);
    final parentTag =
        attachedTags.where((t) => t.parentTagId == null).firstOrNull;
    if (parentTag != null) {
      final childTag = attachedTags
          .where((t) => t.parentTagId == parentTag.id)
          .firstOrNull;
      await db.recordTagHistory(parentTag.id, childTagId: childTag?.id);
    }
    if (mounted) {
      setState(() {
        _rouletteOpen = false;
        _showTagHistory = false;
      });
    }
  }

  /// 履歴表示トグル
  Future<void> _toggleTagHistory() async {
    if (_showTagHistory) {
      setState(() => _showTagHistory = false);
    } else {
      final db = ref.read(databaseProvider);
      final items = await db.getRecentTagHistory();
      setState(() {
        _tagHistoryItems = items;
        _showTagHistory = true;
        _historyCanScrollUp = false;
        _historyCanScrollDown = items.length > 4; // 4件超えたらスクロール可能とみなす
      });
    }
  }

  /// 履歴からタグを選択
  Future<void> _selectFromHistory(TagHistory item) async {
    // 親タグを選択
    await _onRouletteTagSelected(item.parentTagId, false);
    // 子タグがあれば選択
    if (item.childTagId != null) {
      await _onRouletteTagSelected(item.childTagId!, true);
    }
    setState(() => _showTagHistory = false);
  }

  /// タグ履歴オーバーレイ
  Widget _buildTagHistoryOverlay() {
    final allTags = ref.watch(allTagsProvider).valueOrNull ?? const <Tag>[];

    return Container(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
            child: Row(
              children: [
                const Text('タグ履歴',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: '.SF Pro Rounded',
                    )),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showTagHistory = false),
                  child: Icon(CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: Colors.grey.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          if (_tagHistoryItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('まだ履歴がありません',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            Flexible(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final metrics = notification.metrics;
                  final canUp = metrics.pixels > 0;
                  final canDown = metrics.pixels < metrics.maxScrollExtent;
                  if (canUp != _historyCanScrollUp ||
                      canDown != _historyCanScrollDown) {
                    setState(() {
                      _historyCanScrollUp = canUp;
                      _historyCanScrollDown = canDown;
                    });
                  }
                  return false;
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  itemCount: _tagHistoryItems.length,
                  itemBuilder: (context, index) {
                  final item = _tagHistoryItems[index];
                  final pTag = allTags
                      .where((t) => t.id == item.parentTagId)
                      .firstOrNull;
                  if (pTag == null) return const SizedBox.shrink();
                  final cTag = item.childTagId != null
                      ? allTags
                          .where((t) => t.id == item.childTagId)
                          .firstOrNull
                      : null;

                  return GestureDetector(
                    onTap: () => _selectFromHistory(item),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: IntrinsicHeight(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 130),
                                padding: EdgeInsets.fromLTRB(
                                    6, 3, cTag != null ? 9 : 6, 3),
                                decoration: BoxDecoration(
                                  color: TagColors.getColor(pTag.colorIndex),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pTag.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: '.SF Pro Rounded',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (cTag != null)
                              Flexible(
                                child: Transform.translate(
                                  offset: const Offset(-4, 1),
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 110),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: TagColors.getColor(cTag.colorIndex),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      cTag.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: '.SF Pro Rounded',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              ),
            ),
          // 下スクロールシェブロン
          if (_historyCanScrollDown)
            Center(
              child: Icon(Icons.keyboard_arrow_down,
                  size: 32, color: Colors.grey.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressDonut(List<TodoItem> items, double progress) {
    final percent = (progress * 100).round();
    final hasDone = items.any((i) => i.isDone);
    final doneCount = items.where((i) => i.isDone).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: hasDone ? () => _showResetDialog(items, doneCount) : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
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
        ),
      ],
    );
  }

  /// チェックリセット確認ダイアログ
  void _showResetDialog(List<TodoItem> items, int doneCount) {
    focusSafe(
      context,
      () => showGeneralDialog(
        context: context,
        barrierDismissible: true, barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('チェックをリセット', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Hiragino Sans')),
                  const SizedBox(height: 12),
                  Text('$doneCount件の完了チェックを外します',
                    style: TextStyle(fontSize: 13, fontFamily: 'Hiragino Sans',
                      color: Colors.black.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _resetAll(items);
                    },
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Text('リセットする', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans', color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text('キャンセル', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                        color: Colors.black.withValues(alpha: 0.5))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
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
                  if (_isSelectMode) {
                    return KeyedSubtree(
                      key: ValueKey(row.id),
                      child: const SizedBox.shrink(),
                    );
                  }
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

    return _SwipeDeleteRow(
      key: key ?? ValueKey(item.id),
      enabled: !isEditing,
      onDelete: () => _deleteItemRecursive(item.id, allItems),
      closeNotifier: _swipeCloseNotifier,
      onOpened: () => _isAnySwipeOpen = true,
      onClosed: () => _isAnySwipeOpen = false,
      child: Stack(
        children: [
          // 背景色帯（インデント付き）
          Positioned(
            left: bandLeft,
            right: 16,
            top: 0,
            bottom: 0,
          child: Container(color: _depthBgColors[depth.clamp(0, _maxDepth)]),
        ),
        // 祖先の縦線（編集中・選択モード中は非表示）
        if (depth > 0 && _editingItemId == null && !_isSelectMode)
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 選択モード: チェックマーク
          if (_isSelectMode)
            GestureDetector(
              onTap: () => _toggleSelect(item.id, allItems),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _selectedItems.contains(item.id)
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 22,
                  color: _selectedItems.contains(item.id)
                      ? Colors.red
                      : Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          // チェックボックス
          GestureDetector(
            onTap: _isSelectMode
                ? () => _toggleSelect(item.id, allItems)
                : () => _toggleDone(item),
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
                      if (_isSelectMode) {
                        _toggleSelect(item.id, allItems);
                        return;
                      }
                      if (_isAnySwipeOpen) {
                        _closeSwipeIfOpen();
                        return;
                      }
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
          // メモボタン（項目名編集中も表示）
            Builder(builder: (context) {
              final isMemoActive = _memoEditingItemId == item.id || _memoViewItemId == item.id;
              return GestureDetector(
                onTap: () => _toggleMemo(item),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: isMemoActive
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                                blurRadius: 5,
                                spreadRadius: 0,
                              ),
                            ],
                          )
                        : null,
                    child: Center(
                      child: Transform.rotate(
                        angle: 1.5708, // 90°
                        child: Icon(
                          (item.memo ?? '').isNotEmpty
                              ? CupertinoIcons.doc_fill
                              : CupertinoIcons.doc,
                          size: 16,
                          color: isMemoActive
                              ? const Color(0xFF007AFF)
                              : (item.memo ?? '').isNotEmpty
                                  ? _depthAccentColors[depth.clamp(0, _maxDepth)]
                                  : Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
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
      // メモ展開エリア
      if (_memoEditingItemId == item.id || _memoViewItemId == item.id)
        _buildMemoArea(item, depth),
      // メモ1行プレビュー（閉じてるとき＋メモあり）
      if (_memoEditingItemId != item.id && _memoViewItemId != item.id && (item.memo ?? '').isNotEmpty)
        _buildMemoPreview(item, depth),
            ],
          ),
      ),
      ],
    ),
    );
  }

  Widget _buildMemoArea(TodoItem item, int depth) {
    final memoColor = _depthAccentColors[depth.clamp(0, _maxDepth)];
    final isEditing = _memoEditingItemId == item.id;

    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: memoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // メモアイコン（線のみ、常時表示）
          Transform.rotate(
            angle: 1.5708,
            child: Icon(CupertinoIcons.doc, size: 11, color: memoColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: isEditing
                ? _MemoEditField(
                    key: ValueKey('memo_${item.id}'),
                    initialText: item.memo ?? '',
                    placeholder: '"${item.title}" にメモを追加',
                    color: memoColor,
                    onCommit: (text) => _saveMemo(item.id, text),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _memoEditingItemId = item.id;
                            _memoViewItemId = null;
                          }),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            item.memo ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Hiragino Sans',
                              color: memoColor,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showMemoDeleteDialog(item.id),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(CupertinoIcons.trash,
                              size: 11, color: memoColor.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoPreview(TodoItem item, int depth) {
    final memoColor = _depthAccentColors[depth.clamp(0, _maxDepth)];
    return GestureDetector(
      onTap: () => _toggleMemo(item),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 4, top: 2),
        child: Row(
          children: [
            Transform.rotate(
              angle: 1.5708,
              child: Icon(CupertinoIcons.doc_fill,
                  size: 11, color: memoColor),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.memo ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Hiragino Sans',
                  color: memoColor,
                ),
              ),
            ),
          ],
        ),
      ),
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
          // 祖先の縦線 + 自分のL字（編集中・選択モード中は非表示）
          if (_editingItemId == null && !_isSelectMode) ...[
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
        contentPadding: EdgeInsets.symmetric(horizontal: 10),
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

/// メモ編集用TextField
class _MemoEditField extends StatefulWidget {
  final String initialText;
  final String placeholder;
  final Color color;
  final void Function(String text) onCommit;

  const _MemoEditField({
    super.key,
    required this.initialText,
    required this.placeholder,
    required this.color,
    required this.onCommit,
  });

  @override
  State<_MemoEditField> createState() => _MemoEditFieldState();
}

class _MemoEditFieldState extends State<_MemoEditField> {
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

  void _commit() {
    if (_committed) return;
    _committed = true;
    widget.onCommit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: 10,
      minLines: 1,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFamily: 'Hiragino Sans',
        color: widget.color,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        hintText: widget.placeholder,
        hintStyle: TextStyle(
          fontSize: 13,
          fontFamily: 'Hiragino Sans',
          color: widget.color.withValues(alpha: 0.4),
        ),
      ),
      onTap: TextMenuDismisser.wrap(null),
      contextMenuBuilder: TextMenuDismisser.builder,
      onTapOutside: (_) => _commit(),
    );
  }
}

/// iOS風スワイプ削除: 左スワイプで赤い「削除」ボタンを露出、タップで削除
class _SwipeDeleteRow extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback onDelete;
  final ValueNotifier<int>? closeNotifier;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  const _SwipeDeleteRow({
    super.key,
    required this.child,
    required this.enabled,
    required this.onDelete,
    this.closeNotifier,
    this.onOpened,
    this.onClosed,
  });

  @override
  State<_SwipeDeleteRow> createState() => _SwipeDeleteRowState();
}

class _SwipeDeleteRowState extends State<_SwipeDeleteRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const double _buttonWidth = 80;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onOpened?.call();
      } else if (status == AnimationStatus.dismissed) {
        widget.onClosed?.call();
      }
    });
    widget.closeNotifier?.addListener(_onCloseAll);
  }

  void _onCloseAll() {
    if (_controller.value > 0) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    widget.closeNotifier?.removeListener(_onCloseAll);
    _controller.dispose();
    super.dispose();
  }

  void close() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final val = _controller.value - details.primaryDelta! / _buttonWidth;
        _controller.value = val.clamp(0.0, 1.0);
      },
      onHorizontalDragEnd: (details) {
        if (_controller.value > 0.5) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 赤い削除ボタン（背面右端）
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _buttonWidth,
            child: GestureDetector(
              onTap: () {
                close();
                widget.onDelete();
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.trash, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('削除', style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Hiragino Sans',
                    )),
                  ],
                ),
              ),
            ),
          ),
          // メインコンテンツ（スライドする）
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-_buttonWidth * _controller.value, 0),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _controller.value > 0 ? close : null,
              child: ColoredBox(
                color: Colors.white,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// トレー背景（メモ入力画面と同じ形状）
class _TrayPainter extends CustomPainter {
  final Color color;
  final double tabWidth;
  final double tabHeight;
  final double tabRadius;
  final double bodyRadius;
  final double innerRadius;

  _TrayPainter({
    required this.color,
    required this.tabWidth,
    required this.tabHeight,
    required this.tabRadius,
    required this.bodyRadius,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyTop = tabHeight;
    final bodyLeftX = tabWidth;
    final ir = innerRadius.clamp(0.0, bodyTop);

    final path = Path();

    path.moveTo(0, tabRadius);
    path.arcTo(
      Rect.fromLTWH(0, 0, tabRadius * 2, tabRadius * 2),
      3.14159, 3.14159 / 2, false,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);

    path.lineTo(bodyLeftX + bodyRadius, size.height);
    path.arcTo(
      Rect.fromLTWH(bodyLeftX, size.height - bodyRadius * 2, bodyRadius * 2, bodyRadius * 2),
      3.14159 / 2, 3.14159 / 2, false,
    );

    path.lineTo(bodyLeftX, bodyTop + ir);
    path.arcTo(
      Rect.fromLTWH(bodyLeftX - ir * 2, bodyTop, ir * 2, ir * 2),
      0, -3.14159 / 2, false,
    );

    path.lineTo(tabRadius, bodyTop);
    path.arcTo(
      Rect.fromLTWH(0, bodyTop - tabRadius * 2, tabRadius * 2, tabRadius * 2),
      3.14159 / 2, 3.14159 / 2, false,
    );

    path.close();

    // 影
    canvas.save();
    canvas.translate(-2, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrayPainter old) => old.color != color;
}
