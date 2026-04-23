import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/keyboard_done_bar.dart';
import '../utils/responsive.dart';
import '../utils/safe_dialog.dart';
import '../utils/text_menu_dismisser.dart';
import '../utils/toast.dart';
import '../widgets/trapezoid_tab_shape.dart';
import 'todo_list_screen.dart';

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

  /// iPad 横画面スプリットビュー時に右カラムで開いている listId。
  /// narrow レイアウト (iPhone / iPad 縦) では未使用。
  String? _selectedListId;

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
    final isWide = Responsive.isWide(context);
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: KeyboardDoneBar(child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).viewPadding.top - 4,
        ),
        child: StreamBuilder<List<TodoList>>(
          stream: _watchLists(),
          builder: (context, snap) {
            final lists = snap.data ?? const <TodoList>[];
            if (isWide) {
              _ensureSelection(lists);
              return _buildWideLayout(lists);
            }
            return _buildNarrowLayout(lists);
          },
        ),
      )),
    );
  }

  /// 狭幅（iPhone / iPad 縦）: 従来どおり縦積み。詳細は画面遷移で開く。
  Widget _buildNarrowLayout(List<TodoList> lists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        _buildTodoTab(),
        Expanded(
          child: Container(
            color: _todoTabColor,
            child: lists.isEmpty
                ? _buildEmptyState()
                : _buildListGrid(lists),
          ),
        ),
      ],
    );
  }

  /// iPad 横画面: 左=リスト一覧 / 右=選択中リストの詳細。
  Widget _buildWideLayout(List<TodoList> lists) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左カラム（リスト一覧）
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(),
              _buildTodoTab(),
              Expanded(
                child: Container(
                  color: _todoTabColor,
                  child: lists.isEmpty
                      ? _buildEmptyState()
                      : _buildListGrid(lists),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // 右カラム（詳細）
        Expanded(
          child: _buildDetailPane(lists),
        ),
      ],
    );
  }

  /// 右カラム。lists が空 or 未選択なら案内、選ばれていれば TodoListScreen を埋め込む。
  Widget _buildDetailPane(List<TodoList> lists) {
    final id = _selectedListId;
    if (id == null || lists.isEmpty) {
      return Center(
        child: Text(
          'リストを選択してください',
          style: TextStyle(
            fontSize: 15,
            fontFamily: 'Hiragino Sans',
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    return TodoListScreen(
      // listId 変更で内部 State をリセットしたいので key に含める
      key: ValueKey(id),
      listId: id,
      embedded: true,
    );
  }

  /// 選択中リストが削除された/未選択の場合に、先頭を自動選択する。
  void _ensureSelection(List<TodoList> lists) {
    final current = _selectedListId;
    if (current != null && lists.any((l) => l.id == current)) return;
    final next = lists.isEmpty ? null : lists.first.id;
    if (current == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedListId = next);
    });
  }

  /// ルートアイテムをwatch（リスト単位）
  Stream<List<TodoItem>> _watchRootItems(String listId) {
    final db = ref.read(databaseProvider);
    return (db.select(db.todoItems)
          ..where((t) => t.listId.equals(listId) & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// リスト一覧（本家準拠リッチカード・2列）
  Widget _buildListGrid(List<TodoList> lists) {
    // 2列に分割（左列: 偶数インデックス、右列: 奇数インデックス）
    final leftItems = <TodoList>[];
    final rightItems = <TodoList>[];
    for (var i = 0; i < lists.length; i++) {
      if (i.isEven) {
        leftItems.add(lists[i]);
      } else {
        rightItems.add(lists[i]);
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildColumn(leftItems)),
              const SizedBox(width: 8),
              Expanded(child: _buildColumn(rightItems)),
            ],
          ),
          // リスト作成ボタン（本家準拠: 白い＋アイコン + 白テキスト）
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: GestureDetector(
              onTap: _createListAndOpen,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Icon(CupertinoIcons.add,
                          size: 11, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'リストを作成',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.white,
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

  Widget _buildColumn(List<TodoList> lists) {
    return Column(
      children: [
        for (final list in lists)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
            onTap: () => _openList(list.id),
            onLongPress: () => _showListActions(list),
            behavior: HitTestBehavior.opaque,
            child: StreamBuilder<List<TodoItem>>(
              stream: _watchRootItems(list.id),
              builder: (context, snap) {
                final rootItems = snap.data ?? const <TodoItem>[];
                final total = rootItems.length;
                final done = rootItems.where((i) => i.isDone).length;
                final progress = total > 0 ? done / total : 0.0;
                return Stack(
                  children: [
                    Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ヘッダー（アイコン＋タイトル＋ミニドーナツ）
                      Row(
                        children: [
                          const Icon(CupertinoIcons.bookmark_fill,
                              size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              list.title.isEmpty ? '無題のリスト' : list.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Hiragino Sans',
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (total > 0) ...[
                            const SizedBox(width: 4),
                            Padding(
                              padding: EdgeInsets.only(
                                  top: (list.isPinned || list.isLocked) ? 10 : 0),
                              child: _buildMiniDonut(progress),
                            ),
                          ],
                        ],
                      ),
                      // ルート項目プレビュー（最大5件）
                      if (rootItems.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in rootItems.take(5))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.isDone
                                            ? CupertinoIcons.checkmark_square_fill
                                            : CupertinoIcons.square,
                                        size: 12,
                                        color: item.isDone
                                            ? Colors.green
                                            : Colors.grey.withValues(alpha: 0.35),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Hiragino Sans',
                                            color: item.isDone
                                                ? Colors.grey
                                                : Colors.black87,
                                            decoration: item.isDone
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      // フッター行（「他○件」左 + 「○完了」右）
                      if (total > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (rootItems.length > 5)
                              Text(
                                '他${rootItems.length - 5}件',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Hiragino Sans',
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              done == total ? '全完了' : '$done/$total 完了',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Hiragino Sans',
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                    ),
                    // ピン・ロックアイコン（右上に横並び）
                    if (list.isPinned || list.isLocked)
                      Positioned(
                        right: 4, top: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (list.isPinned)
                              const Icon(Icons.push_pin,
                                  size: 10, color: Colors.orange),
                            if (list.isPinned && list.isLocked)
                              const SizedBox(width: 3),
                            if (list.isLocked)
                              const Icon(Icons.lock,
                                  size: 11, color: Colors.red),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// ミニドーナツ（カード用、30x30）
  Widget _buildMiniDonut(double progress) {
    final percent = (progress * 100).round();
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                  Colors.grey.withValues(alpha: 0.15)),
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? Colors.green : Colors.blue),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Hiragino Sans',
                  color: progress >= 1.0 ? Colors.green : Colors.black87,
                  height: 1.0,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Hiragino Sans',
                  color: progress >= 1.0 ? Colors.green : Colors.black87,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openList(String id) {
    // iPad 横画面は右カラムで開く（画面遷移しない）
    if (Responsive.isWide(context)) {
      setState(() => _selectedListId = id);
      return;
    }
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
    final title = await focusSafe(
      context,
      () => showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'newTodoList',
        barrierColor: Colors.black.withValues(alpha: 0.4),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, _, _) => const _NewListDialog(),
        transitionBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (title == null || title.isEmpty) return;
    final db = ref.read(databaseProvider);
    final created = await db.createTodoList(title: title);
    final id = created.id;
    if (!mounted) return;
    // iPad 横画面は右カラムで開く、それ以外は画面遷移
    if (Responsive.isWide(context)) {
      setState(() => _selectedListId = id);
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => TodoListScreen(listId: id),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  /// 長押しメニュー（ボトムシート: ピン固定 / ロック / 削除）
  Future<void> _showListActions(TodoList list) async {
    final action = await focusSafe(
      context,
      () => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (sheetCtx) {
          return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 項目リスト（すりガラス調）
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TodoMenuActionRow(
                            icon: list.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                            label: list.isPinned
                                ? '固定を解除'
                                : 'トップに常時固定',
                            onTap: () =>
                                Navigator.of(sheetCtx).pop('pin'),
                          ),
                          _TodoMenuActionRow(
                            icon: list.isLocked
                                ? Icons.lock_open
                                : Icons.lock_outline,
                            label: list.isLocked ? 'ロックを解除' : '削除防止ロック',
                            onTap: () =>
                                Navigator.of(sheetCtx).pop('lock'),
                          ),
                          if (list.isLocked)
                            _TodoMenuActionRow(
                              icon: Icons.lock,
                              label: '削除ロック中',
                              destructive: true,
                              disabled: true,
                              onTap: () {},
                            )
                          else
                            _TodoMenuActionRow(
                              icon: Icons.delete_outline,
                              label: '削除',
                              destructive: true,
                              onTap: () =>
                                  Navigator.of(sheetCtx).pop('delete'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // キャンセルボタン
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'キャンセル',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                            fontFamily: 'Hiragino Sans',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );

    if (!mounted) return;
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'pin':
        await (db.update(db.todoLists)..where((t) => t.id.equals(list.id)))
            .write(TodoListsCompanion(
          isPinned: Value(!list.isPinned),
          updatedAt: Value(DateTime.now()),
        ));
        break;
      case 'lock':
        final wasLocked = list.isLocked;
        await (db.update(db.todoLists)..where((t) => t.id.equals(list.id)))
            .write(TodoListsCompanion(
          isLocked: Value(!list.isLocked),
          updatedAt: Value(DateTime.now()),
        ));
        if (mounted) {
          showToast(context,
              wasLocked ? 'ロックを解除しました' : 'リストをロックしました');
        }
        break;
      case 'delete':
        _showDeleteConfirmDialog(list);
        break;
    }
  }

  /// 削除確認ダイアログ
  void _showDeleteConfirmDialog(TodoList list) {
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
                  const Text('ToDoリストを削除', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Hiragino Sans')),
                  const SizedBox(height: 12),
                  const Text('ToDoリストを削除します。よろしいですか？',
                    style: TextStyle(fontSize: 13, fontFamily: 'Hiragino Sans',
                      color: Color(0x993C3C43))),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteList(list.id);
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
                      child: const Text('キャンセル', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, fontFamily: 'Hiragino Sans',
                        color: Color(0x993C3C43))),
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

  /// リストと配下の全アイテムを削除
  Future<void> _deleteList(String listId) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.todoItems)..where((t) => t.listId.equals(listId))).go();
    await (db.delete(db.todoLists)..where((t) => t.id.equals(listId))).go();
  }

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
    return SuppressKeyboardDoneBar(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 300),
        child: Center(
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
    ),
    ),
    );
  }
}

/// メニュー項目行（メモ一覧の _MenuActionRow と同じスタイル）
class _TodoMenuActionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final bool disabled;
  final VoidCallback onTap;

  const _TodoMenuActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.disabled = false,
  });

  @override
  State<_TodoMenuActionRow> createState() => _TodoMenuActionRowState();
}

class _TodoMenuActionRowState extends State<_TodoMenuActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.destructive ? Colors.red : Colors.black87;
    final color = widget.disabled ? base.withValues(alpha: 0.4) : base;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel:
          widget.disabled ? null : () => setState(() => _pressed = false),
      onTapUp:
          widget.disabled ? null : (_) => setState(() => _pressed = false),
      onTap: widget.disabled ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 46,
        color: _pressed
            ? Colors.black.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
