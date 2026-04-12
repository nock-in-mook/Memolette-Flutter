import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/keyboard_done_bar.dart';
import '../utils/text_menu_dismisser.dart';
import '../widgets/trapezoid_tab_shape.dart';
import 'todo_list_screen.dart';

const _uuid = Uuid();

/// ToDoリスト一覧画面
/// 本家 TodoListsView 準拠: 単一の緑「TODO」台形タブ + 緑背景の全画面
class TodoListsScreen extends ConsumerStatefulWidget {
  const TodoListsScreen({super.key});

  @override
  ConsumerState<TodoListsScreen> createState() => _TodoListsScreenState();
}

class _TodoListsScreenState extends ConsumerState<TodoListsScreen> {
  // 本家 TodoListsView の緑色（red:0.55, green:0.82, blue:0.55）
  static const Color _todoTabColor = Color(0xFF8CD18C);

  Stream<List<TodoList>> _watchLists() {
    final db = ref.read(databaseProvider);
    return (db.select(db.todoLists)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(
                expression: t.manualSortOrder, mode: OrderingMode.desc),
            (t) => OrderingTerm(
                expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: KeyboardDoneBar(child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).viewPadding.top - 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ツールバー（閉じる + 新規ボタン）
            _buildToolbar(),
            // TODOタブ
            _buildTodoTab(),
            // 緑色のフォルダ本体（リストがあれば一覧、なければ空状態）
            Expanded(
              child: Container(
                color: _todoTabColor,
                child: StreamBuilder<List<TodoList>>(
                  stream: _watchLists(),
                  builder: (context, snap) {
                    final lists = snap.data ?? const <TodoList>[];
                    if (lists.isEmpty) return _buildEmptyState();
                    return _buildListGrid(lists);
                  },
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }

  /// 最小限のリスト一覧（本家と同じ2列・簡素カード）
  Widget _buildListGrid(List<TodoList> lists) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _openList(list.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.bookmark_fill,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      list.title.isEmpty ? '無題のリスト' : list.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Hiragino Sans',
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openList(String id) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => TodoListScreen(listId: id),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
      child: Row(
        children: [
          // 閉じる
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 56,
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '閉じる',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF007AFF),
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          // 新規ボタン
          GestureDetector(
            onTap: _createListAndOpen,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF007AFF), width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.add,
                      size: 14, color: Color(0xFF007AFF)),
                  SizedBox(width: 4),
                  Text(
                    '新規',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                      fontFamily: 'Hiragino Sans',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 空状態（本家 emptyView 準拠）
  /// アイコン + テキスト + 「リストを作成」白ボタン、上下にSpacerでやや上寄せ
  Widget _buildEmptyState() {
    return Column(
      children: [
        const Spacer(),
        Icon(
          CupertinoIcons.checkmark_square,
          size: 48,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 24),
        Text(
          'ToDoリストはまだありません',
          style: TextStyle(
            fontSize: 17,
            fontFamily: 'Hiragino Sans',
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _createListAndOpen,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.add, size: 16, color: _todoTabColor),
                const SizedBox(width: 6),
                Text(
                  'リストを作成',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Hiragino Sans',
                    color: _todoTabColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        const Spacer(),
      ],
    );
  }

  /// 新規リスト作成ダイアログを表示
  Future<void> _createListAndOpen() async {
    final title = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'newTodoList',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => const _NewListDialog(),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
    if (title == null || title.isEmpty) return;
    final db = ref.read(databaseProvider);
    final id = _uuid.v4();
    await db.into(db.todoLists).insert(TodoListsCompanion.insert(
          id: id,
          title: Value(title),
        ));
    if (!mounted) return;
    // 即時遷移（スライドアニメなし）
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => TodoListScreen(listId: id),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // ダイアログクラスは末尾で定義
  Widget _buildTodoTab() {
    // タブ自体は左寄せ、本家準拠で1.08倍スケール（選択中相当）
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Transform.scale(
          scale: 1.08,
          alignment: Alignment.bottomCenter,
          child: CustomPaint(
            painter: const TrapezoidTabPainter(
              color: _todoTabColor,
              shadows: [
                Shadow(
                  color: Color(0x66000000),
                  offset: Offset(-3, 3),
                  blurRadius: 5,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.checkmark_square,
                      size: 14, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    'TODO',
                    strutStyle: StrutStyle(
                      fontSize: 14,
                      height: 1.0,
                      forceStrutHeight: true,
                      leading: 0,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.0,
                      fontFamily: 'Hiragino Sans',
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 新規ToDoリスト作成ダイアログ
/// 本家 newListDialogOverlay 準拠
class _NewListDialog extends StatefulWidget {
  const _NewListDialog();

  @override
  State<_NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<_NewListDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    children: [
                      Icon(CupertinoIcons.checkmark_square,
                          size: 32, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        '新しいリスト',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'リストのタイトルを入力してください',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0x993C3C43),
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
                    ],
                  ),
                ),
                // テキスト入力
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onTap: TextMenuDismisser.wrap(null),
                    contextMenuBuilder: TextMenuDismisser.builder,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Hiragino Sans',
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      hintText: '例: 買い物リスト',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: Colors.black.withValues(alpha: 0.3),
                        fontFamily: 'Hiragino Sans',
                      ),
                      filled: true,
                      fillColor: const Color(0x14787880), // tertiarySystemFill
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _commit(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 0.5,
                  color: Colors.black.withValues(alpha: 0.15),
                ),
                // 作成ボタン
                GestureDetector(
                  onTap:
                      _controller.text.trim().isEmpty ? null : _commit,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Text(
                        '作成する',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Hiragino Sans',
                          color: _controller.text.trim().isEmpty
                              ? Colors.grey
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 0.5,
                  color: Colors.black.withValues(alpha: 0.15),
                ),
                // キャンセルボタン
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    height: 48,
                    child: Center(
                      child: Text(
                        'キャンセル',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Hiragino Sans',
                          color: Color(0x993C3C43),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
