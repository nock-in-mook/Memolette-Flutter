import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/text_menu_dismisser.dart';

const _uuid = Uuid();

// 本家 TodoListsView の緑色
const Color _todoTabColor = Color(0xFF8CD18C);

/// ToDoリスト詳細画面（最小実装）
/// - タイトル表示・編集
/// - ルートアイテムの一覧
/// - 末尾の+ボタンで新規追加（インライン入力）
/// - チェックボックスで完了切替
class TodoListScreen extends ConsumerStatefulWidget {
  final String listId;

  const TodoListScreen({super.key, required this.listId});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  // 編集中アイテム（実体は _EditingItemField が担当）
  String? _editingItemId;

  // タイトル編集
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

  Stream<List<TodoItem>> _watchItems() {
    final db = ref.read(databaseProvider);
    return (db.select(db.todoItems)
          ..where((t) => t.listId.equals(widget.listId) & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  // ========================================
  // CRUD
  // ========================================
  /// 新しい空行を作成して編集状態に入る
  Future<void> _createItem() async {
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.todoItems)
          ..where((t) => t.listId.equals(widget.listId) & t.parentId.isNull()))
        .get();
    final id = _uuid.v4();
    await db.into(db.todoItems).insert(TodoItemsCompanion.insert(
          id: id,
          listId: widget.listId,
          title: const Value(''),
          sortOrder: Value(existing.length),
        ));
    if (!mounted) return;
    setState(() => _editingItemId = id);
    // _EditingItemField の initState で自動的にフォーカスが入る
  }

  /// 編集中の項目を保存（_EditingItemField から呼ばれる）
  /// chainNext=true（Enter押下時）かつ非空なら次の行を作って連続入力
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
      setState(() => _editingItemId = null);
      if (chainNext && !wasEmpty) {
        await _createItem();
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
            // タイトルと項目の仕切り線
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
          // 中央: アイコン + 「ToDo リスト」
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
          // 左: 戻るボタン（角丸背景つき）
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

  /// タイトル本体（編集中はTextField、それ以外はタップ可能Text）
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
        // 進捗はアイテムストリームから取得
        return StreamBuilder<List<TodoItem>>(
          stream: _watchItems(),
          builder: (context, itemsSnap) {
            final items = itemsSnap.data ?? const <TodoItem>[];
            final total = items.length;
            final done = items.where((i) => i.isDone).length;
            final progress = total > 0 ? done / total : 0.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左側: タイトル + 完了件数
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // しおり + タイトルを中央揃えで横並び
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
                  // タグなしピル
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
                  // 右側: 円グラフ + リセット
                  if (total > 0) _buildProgressDonut(items, progress),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 円グラフ（進捗%表示）+ 下にリセットボタン
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
              // 背景円
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(
                      Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              // 進捗円
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  valueColor:
                      AlwaysStoppedAnimation(Colors.blue.shade500),
                ),
              ),
              // パーセント
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
        // リセットボタン: 完了中の項目があるときだけ有効
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

  /// 全項目を未完了に戻す
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

  Widget _buildItemList() {
    return StreamBuilder<List<TodoItem>>(
      stream: _watchItems(),
      builder: (context, snap) {
        final items = snap.data ?? const <TodoItem>[];
        final isEmpty = items.isEmpty;
        // アイテム行は左右フルブリード（仕切り線と緑枠の端を一致させる）。
        // 上下padding0、項目間の区切りは透明な1pxスペースで表現
        // 下部余白を大きく取り、連続追加でリストが上下動するのを少しでも軽減
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 200),
          itemCount: items.length + 1, // 末尾に+ボタン
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _buildAddButton(emptyState: isEmpty);
            }
            return _buildItemRow(items[index]);
          },
          ),
        );
      },
    );
  }

  Widget _buildItemRow(TodoItem item) {
    final isEditing = _editingItemId == item.id;
    return Container(
      // 仕切り線と幅を揃える（左右16ptマージン）
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        // 本家準拠: SwiftUI .green.opacity(0.10) (= iOS systemGreen at 10%)
        color: const Color(0xFF34C759).withValues(alpha: 0.10),
        // 項目間の仕切り線（iOS リスト標準のセパレータ相当）
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
                // 本家 SwiftUI .green (iOS systemGreen 相当)
                color: item.isDone
                    ? const Color(0xFF34C759)
                    : Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // タイトル or 入力欄
          Expanded(
            child: isEditing
                ? _EditingItemField(
                    // ValueKey で行が変わったら StatefulWidget も新規になる →
                    // initState が必ず走り、新しい FocusNode が確実にフォーカスを取る
                    key: ValueKey('edit_${item.id}'),
                    initialText: item.title,
                    onCommit: (text) => _commitEditWithText(text),
                    onCommitChain: (text) => _commitEditWithText(text, chainNext: true),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() => _editingItemId = item.id);
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
        ],
      ),
    );
  }

  Widget _buildAddButton({required bool emptyState}) {
    // 本家準拠: チェックボックスと同じレイアウト構造で中心を自動的に合わせる
    const Color sysGreen = Color(0xFF34C759);
    return GestureDetector(
      onTap: _createItem,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // アイテム行と完全一致の余白構造（margin 16 + padding 4）
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // チェックボックスと同じ寸法: 内側 padding 2 + 40pt 枠
            Padding(
              padding: const EdgeInsets.all(2),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    CupertinoIcons.add_circled_solid,
                    size: 26,
                    color: sysGreen.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 空のときだけテキスト表示。それ以外は空のExpandedで行全体をタップ可能に
            Expanded(
              child: emptyState
                  ? Text(
                      '最初の項目を追加しましょう',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Hiragino Sans',
                        color: sysGreen.withValues(alpha: 0.6),
                      ),
                    )
                  : const SizedBox(height: 44),
            ),
          ],
        ),
      ),
    );
  }
}

/// 編集中の単一行 TextField を独自 StatefulWidget で持つ。
/// 行ごとに新しいインスタンスが生成され、initState で自身の FocusNode に
/// 確実にフォーカスを取らせるため、連続追加でもタイミング問題が起きない。
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
    // ウィジェットがマウントされた次のフレームでフォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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
