import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../constants/memo_bg_colors.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/responsive.dart';
import '../utils/safe_dialog.dart';
import '../utils/text_menu_dismisser.dart';
import '../utils/toast.dart';
import '../widgets/bg_color_picker_dialog.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/trapezoid_tab_shape.dart';
import '../widgets/wide_todo_pane.dart';
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
  /// 初期値は null（何も開いていない状態）。ユーザーがリストをタップして初めて開く。
  String? _selectedListId;

  /// 結合モード中のタップ順序（最大5）。モードOFFのとき常に空。
  bool _isMergeMode = false;
  final List<String> _mergeOrder = <String>[];
  static const int _mergeMax = 5;

  /// 選択削除モード（メモ混在フォルダの選択削除と同等の体験）
  bool _isSelectDeleteMode = false;
  final Set<String> _selectedDeleteIds = <String>{};

  void _enterMergeMode() {
    setState(() {
      _isMergeMode = true;
      _mergeOrder.clear();
      _selectedListId = null; // 右カラムは閉じる
    });
  }

  void _exitMergeMode() {
    setState(() {
      _isMergeMode = false;
      _mergeOrder.clear();
    });
  }

  void _enterSelectDeleteMode() {
    setState(() {
      _isSelectDeleteMode = true;
      _selectedDeleteIds.clear();
      _selectedListId = null;
    });
  }

  void _exitSelectDeleteMode() {
    setState(() {
      _isSelectDeleteMode = false;
      _selectedDeleteIds.clear();
    });
  }

  void _toggleSelectDeleteSelection(String id, bool isLocked) {
    if (isLocked) {
      showToast(context, 'このToDoはロック中です');
      return;
    }
    setState(() {
      if (_selectedDeleteIds.contains(id)) {
        _selectedDeleteIds.remove(id);
      } else {
        _selectedDeleteIds.add(id);
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedDeleteIds.length;
    if (count == 0) return;
    final ids = _selectedDeleteIds.toList();
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: '選択したToDoを削除',
      message: '$count件のToDoを削除します。よろしいですか？',
    );
    if (!confirmed || !mounted) return;
    final db = ref.read(databaseProvider);
    for (final id in ids) {
      await (db.delete(db.todoLists)..where((t) => t.id.equals(id))).go();
    }
    if (!mounted) return;
    _exitSelectDeleteMode();
  }

  /// ToDoカード背景色（チェックボックス可読性のため、メモカードより薄め）
  Color _cardBgColor(int bgColorIndex) {
    if (bgColorIndex == 0) return Colors.white;
    final base = MemoBgColors.getColor(bgColorIndex);
    return Color.lerp(base, Colors.white, 0.4) ?? base;
  }

  /// 選択削除モード時の上部バナー（1行・TODOタブに重ねて表示）
  Widget _buildSelectDeleteBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Text(
        '削除するToDoを選択してください',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: 'Hiragino Sans',
          color: Colors.black87,
        ),
      ),
    );
  }

  /// 左下フロート削除ボタン（メモ一覧フッターのゴミ箱と同じ見た目）
  Widget _buildDeleteFloatingButton(bool hasItems) {
    const secondary = Color(0x993C3C43);
    final disabledColor = Colors.grey.withValues(alpha: 0.35);
    return Positioned(
      left: 14,
      bottom: 24,
      child: GestureDetector(
        onTap: hasItems ? _enterSelectDeleteMode : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0x66999999), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            CupertinoIcons.delete_simple,
            size: 17,
            color: hasItems ? secondary : disabledColor,
          ),
        ),
      ),
    );
  }

  /// 選択削除モード時のカード左上バッジ。選択中は赤塗り+チェック、未選択は空円。
  Widget _selectDeleteBadge(String id) {
    final selected = _selectedDeleteIds.contains(id);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? Colors.red : Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.red : Colors.grey.shade500,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(CupertinoIcons.checkmark_alt,
              size: 14, color: Colors.white)
          : null,
    );
  }

  /// 結合モード時のカード左上バッジ。選択中は青塗り+番号、未選択は空円。
  Widget _mergeBadge(String id) {
    final idx = _mergeOrder.indexOf(id);
    final selected = idx >= 0;
    const accent = Color(0xFF007AFF);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : Colors.grey.shade500,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: selected
          ? Text(
              '${idx + 1}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Hiragino Sans',
                height: 1.0,
              ),
            )
          : null,
    );
  }

  void _toggleMergeSelection(String id) {
    setState(() {
      if (_mergeOrder.contains(id)) {
        _mergeOrder.remove(id);
      } else if (_mergeOrder.length < _mergeMax) {
        _mergeOrder.add(id);
      } else {
        showToast(context, '結合できるのは最大$_mergeMax個までです');
      }
    });
  }

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
      // KeyboardDoneBar は MaterialApp.builder で全体に掛かっているためここで包まない
      body: Padding(
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
      ),
    );
  }

  /// 狭幅（iPhone / iPad 縦）: 従来どおり縦積み。詳細は画面遷移で開く。
  Widget _buildNarrowLayout(List<TodoList> lists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        if (_isMergeMode) _buildMergeBanner(),
        _buildTodoTab(),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: _todoTabColor,
                child: lists.isEmpty
                    ? _buildEmptyState()
                    : _buildListGrid(lists),
              ),
              if (!_isMergeMode && !_isSelectDeleteMode)
                _buildDeleteFloatingButton(lists.isNotEmpty),
            ],
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
              if (_isMergeMode) _buildMergeBanner(),
              _buildTodoTab(),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      color: _todoTabColor,
                      child: lists.isEmpty
                          ? _buildEmptyState()
                          : _buildListGrid(lists),
                    ),
                    if (!_isMergeMode && !_isSelectDeleteMode)
                      _buildDeleteFloatingButton(lists.isNotEmpty),
                  ],
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

  /// 右カラム。lists が空 or 未選択なら案内、選ばれていれば WideTodoPane を埋め込む。
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
    return WideTodoPane(
      listId: id,
      onClose: () => setState(() => _selectedListId = null),
    );
  }

  /// 選択中のリストが削除されたときだけ選択を外す。自動先頭選択はしない。
  /// 起動直後や閉じたあとは「リストを選択してください」案内を維持する。
  void _ensureSelection(List<TodoList> lists) {
    final current = _selectedListId;
    if (current == null) return;
    if (lists.any((l) => l.id == current)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedListId = null);
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
                      child: Icon(Icons.add,
                          size: 14, weight: 900, color: Colors.white),
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
            onTap: () {
              if (_isSelectDeleteMode) {
                _toggleSelectDeleteSelection(list.id, list.isLocked);
                return;
              }
              _openList(list.id);
            },
            onLongPress: (_isMergeMode || _isSelectDeleteMode)
                ? null
                : () => _showListActions(list),
            behavior: HitTestBehavior.opaque,
            child: StreamBuilder<List<TodoItem>>(
              stream: _watchRootItems(list.id),
              builder: (context, snap) {
                final rootItems = snap.data ?? const <TodoItem>[];
                final total = rootItems.length;
                final done = rootItems.where((i) => i.isDone).length;
                final progress = total > 0 ? done / total : 0.0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardBgColor(list.bgColorIndex),
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
                    // eventDate / ピン / ロックアイコン（右上に横並び）
                    if (list.eventDate != null ||
                        list.isPinned ||
                        list.isLocked)
                      Positioned(
                        right: 4, top: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (list.eventDate != null) ...[
                              const Icon(Icons.event_outlined,
                                  size: 11, color: Colors.orange),
                              const SizedBox(width: 3),
                            ],
                            if (list.isPinned) ...[
                              const Icon(Icons.push_pin,
                                  size: 10, color: Colors.orange),
                              if (list.isLocked) const SizedBox(width: 3),
                            ],
                            if (list.isLocked)
                              const Icon(Icons.lock,
                                  size: 11, color: Colors.red),
                          ],
                        ),
                      ),
                    // 結合で生成されたリスト: しおり上端寄りに配置
                    // 結合モード中はチェックボックス(left:-6,24px→右端x=18)との
                    // 重なりを避けるため left=22 へ右に逃がす
                    if (list.isMerged)
                      Positioned(
                        left: (_isMergeMode || _isSelectDeleteMode) ? 22 : 12,
                        top: 4,
                        child: const Icon(
                          Icons.merge_type,
                          size: 14,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    // 結合モード時の番号バッジ（丸の直径の25% 上に浮かせる → top=-6）
                    if (_isMergeMode)
                      Positioned(
                        left: -6,
                        top: -6,
                        child: _mergeBadge(list.id),
                      ),
                    // 選択削除モード時のチェックバッジ
                    if (_isSelectDeleteMode)
                      Positioned(
                        left: -6,
                        top: -6,
                        child: _selectDeleteBadge(list.id),
                      ),
                    // 結合/選択削除モード中、未選択カードを薄く
                    if ((_isMergeMode &&
                            !_mergeOrder.contains(list.id)) ||
                        (_isSelectDeleteMode &&
                            !_selectedDeleteIds.contains(list.id)))
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
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
    // 結合モード中は選択トグル
    if (_isMergeMode) {
      _toggleMergeSelection(id);
      return;
    }
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
    if (_isMergeMode) return _buildMergeToolbar();
    if (_isSelectDeleteMode) return _buildSelectDeleteToolbar();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
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
          // 結合モード起動
          GestureDetector(
            onTap: _enterMergeMode,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF007AFF), width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.merge_type,
                      size: 14, color: Color(0xFF007AFF)),
                  SizedBox(width: 4),
                  Text(
                    '結合',
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
          const SizedBox(width: 8),
          // 新規ボタン（カプセル型）
          GestureDetector(
            onTap: _createListAndOpen,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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

  /// 選択削除モード中のツールバー: キャンセル / N件選択中 / 削除
  Widget _buildSelectDeleteToolbar() {
    final canDelete = _selectedDeleteIds.isNotEmpty;
    final count = _selectedDeleteIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitSelectDeleteMode,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'キャンセル',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF007AFF),
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _exitSelectDeleteMode,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    count == 0 ? '' : '$count件 選択中',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Hiragino Sans',
                      color: Color(0x993C3C43),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: canDelete ? _confirmDeleteSelected : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: canDelete
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: canDelete
                      ? Colors.red
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.delete_simple,
                      size: 14,
                      color: canDelete
                          ? Colors.red
                          : Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    '削除',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: canDelete
                          ? Colors.red
                          : Colors.grey.withValues(alpha: 0.5),
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

  /// 結合モード中のツールバー: キャンセル / 選択案内 / 結合実行
  Widget _buildMergeToolbar() {
    final canMerge = _mergeOrder.length >= 2;
    const accent = Color(0xFF007AFF);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitMergeMode,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'キャンセル',
                  style: TextStyle(
                    fontSize: 16,
                    color: accent,
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ),
            ),
          ),
          // キャンセルと結合するボタンの間の余白タップで結合モードを抜ける
          Expanded(
            child: GestureDetector(
              onTap: _exitMergeMode,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    _mergeOrder.isEmpty ? '' : '${_mergeOrder.length}個 選択中',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Hiragino Sans',
                      color: Color(0x993C3C43),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: canMerge ? _showMergeConfirmDialog : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: canMerge
                    ? accent.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: canMerge
                      ? accent
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.merge_type,
                      size: 14,
                      color:
                          canMerge ? accent : Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    '結合する',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          canMerge ? accent : Colors.grey.withValues(alpha: 0.5),
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

  /// 結合モード時の案内バナー（ツールバーと TodoTab の間に表示）
  Widget _buildMergeBanner() {
    const accent = Color(0xFF007AFF);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.merge_type, size: 18, color: accent),
              SizedBox(width: 6),
              Text(
                'リストの結合',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Hiragino Sans',
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '結合したいリストを選んでください。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Hiragino Sans',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '（選択順に結合、最大$_mergeMaxつまで）',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Hiragino Sans',
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  /// 結合確定ダイアログ（タイトル編集 + 警告）
  Future<void> _showMergeConfirmDialog() async {
    if (_mergeOrder.length < 2) return;
    final db = ref.read(databaseProvider);
    // 選択順のリストタイトルを取得
    final titles = <String>[];
    for (final id in _mergeOrder) {
      final l = await (db.select(db.todoLists)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      titles.add((l?.title ?? '').isEmpty ? '無題のリスト' : l!.title);
    }
    if (!mounted) return;
    final defaultTitle = titles.join('-');

    final result = await focusSafe(
      context,
      () => showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, _, _) => _MergeTitleDialog(
          defaultTitle: defaultTitle,
          sourceTitles: titles,
        ),
        transitionBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );

    if (result == null || !mounted) return; // キャンセル
    final newTitle = result.trim().isEmpty ? defaultTitle : result.trim();

    final newList = await db.mergeTodoLists(
      sourceListIds: _mergeOrder,
      newTitle: newTitle,
    );
    if (!mounted) return;
    setState(() {
      _isMergeMode = false;
      _mergeOrder.clear();
      // 作成した新リストを右カラムで開く（iPad 横のとき）
      if (Responsive.isWide(context)) {
        _selectedListId = newList.id;
      }
    });
    // narrow は一覧のまま（トースト通知）
    if (mounted && !Responsive.isWide(context)) {
      showToast(context, '「$newTitle」を作成しました');
    }
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
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
                            icon: Icons.palette_outlined,
                            label: '背景色',
                            onTap: () =>
                                Navigator.of(sheetCtx).pop('bgColor'),
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
      case 'bgColor':
        if (!mounted) return;
        final selected = await focusSafe(
          context,
          () => showDialog<int>(
            context: context,
            builder: (_) =>
                BgColorPickerDialog(current: list.bgColorIndex),
          ),
        );
        if (selected != null && mounted) {
          await db.setTodoListBgColor(list.id, selected);
        }
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

  /// 削除確認ダイアログ（共通部品 showConfirmDeleteDialog 使用）
  Future<void> _showDeleteConfirmDialog(TodoList list) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'ToDoリストを削除',
      message: 'ToDoリストを削除します。よろしいですか？',
    );
    if (confirmed) await _deleteList(list.id);
  }

  /// リストと配下の全アイテムを削除
  Future<void> _deleteList(String listId) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.todoItems)..where((t) => t.listId.equals(listId))).go();
    await (db.delete(db.todoLists)..where((t) => t.id.equals(listId))).go();
  }

  Widget _buildTodoTab() {
    // 横幅いっぱいの単一タブ（検索結果タブと同型のレイアウト）。
    // 「ここにはタブは増やせない」という視覚的アピールも兼ねる。
    return SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildTodoTabContent()),
          if (_isSelectDeleteMode)
            Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Center(child: _buildSelectDeleteBanner()),
            ),
        ],
      ),
    );
  }

  Widget _buildTodoTabContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
    );
  }
}

/// 結合確定ダイアログ（タイトル編集 + 警告）
class _MergeTitleDialog extends StatefulWidget {
  final String defaultTitle;
  final List<String> sourceTitles;

  const _MergeTitleDialog({
    required this.defaultTitle,
    required this.sourceTitles,
  });

  @override
  State<_MergeTitleDialog> createState() => _MergeTitleDialogState();
}

class _MergeTitleDialogState extends State<_MergeTitleDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultTitle);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '新しいリストのタイトル',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ×ボタンをStackで重ねる: TextField の右 padding を確保して
                  // テキストが ×に重ならないようにする
                  Stack(
                    children: [
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onTap: TextMenuDismisser.wrap(null),
                        contextMenuBuilder: TextMenuDismisser.builder,
                        minLines: 1,
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'Hiragino Sans',
                          color: Colors.black87,
                          height: 1.35,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          // 右に ×分のスペースを確保（テキストは ellipsis されず
                          // 折り返し2行までで収まるように contentPadding で制御）
                          contentPadding: const EdgeInsets.fromLTRB(
                              12, 12, 40, 12),
                          filled: true,
                          fillColor: const Color(0x14787880),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: _controller.clear,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  size: 20,
                                  color: Colors.grey.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '※ 元のリストは残ります',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '※ タグは新リストに引き継がれません',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 確定
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pop(_controller.text),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF007AFF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '結合する',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Hiragino Sans',
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Hiragino Sans',
                          color: Colors.black54,
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
    return Padding(
        padding: const EdgeInsets.only(bottom: 300),
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
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
