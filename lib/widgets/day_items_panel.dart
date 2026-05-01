import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';

/// DayItemsPanel 内で発生した最後の pointer down/up のタイムスタンプ（epoch ms）。
/// home_screen の `_wrapUnfocusOnTap.onPointerUp` がこれを参照して、シート内
/// タップで誤ってシートを閉じないように判定する。
final calendarSheetLastTouchProvider = StateProvider<int>((_) => 0);

/// シート内のカード以外でタップが起きるたびに increment。
/// 各 _SwipeDeleteRow が watch していて、値が変わると自身の削除ボタンを閉じる
/// （iOS 風のキャンセル動作）。
final calendarSheetSwipeCloseProvider = StateProvider<int>((_) => 0);

/// カレンダー画面の「選択された日のアイテム一覧」パネル
class DayItemsPanel extends ConsumerStatefulWidget {
  final DateTime day;
  final ValueChanged<Memo> onMemoTap;
  final ValueChanged<TodoList> onTodoListTap;
  final ValueChanged<TodoItem>? onTodoItemTap;
  final VoidCallback? onAddMemo;
  final VoidCallback? onAddTodoList;
  // 指定するとヘッダ右端に × ボタンが出てパネルを閉じる UI を提供
  final VoidCallback? onClose;
  // スワイプ削除のコールバック（指定された種別のみスワイプ可能になる）。
  // Future<void> を返すこと。確認ダイアログの完了を await できるようにするため。
  final Future<void> Function(Memo)? onMemoDelete;
  final Future<void> Function(TodoList)? onTodoListDelete;
  final Future<void> Function(TodoItem)? onTodoItemDelete;
  // 縦積みレイアウト。iPad 横画面のカレンダー右カラム等、横幅が狭い時に true。
  // 上にメモボックス、下に ToDo ボックス、各々独立に FAB を持つ。
  final bool stacked;

  const DayItemsPanel({
    super.key,
    required this.day,
    required this.onMemoTap,
    required this.onTodoListTap,
    this.onTodoItemTap,
    this.onAddMemo,
    this.onAddTodoList,
    this.onClose,
    this.onMemoDelete,
    this.onTodoListDelete,
    this.onTodoItemDelete,
    this.stacked = false,
  });

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  ConsumerState<DayItemsPanel> createState() => _DayItemsPanelState();
}

class _DayItemsPanelState extends ConsumerState<DayItemsPanel> {
  // シート内タップ vs ドラッグ判定用の起点座標
  Offset? _downPos;

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final onMemoTap = widget.onMemoTap;
    final onTodoListTap = widget.onTodoListTap;
    final onTodoItemTap = widget.onTodoItemTap;
    final onAddMemo = widget.onAddMemo;
    final onAddTodoList = widget.onAddTodoList;
    final onClose = widget.onClose;
    final onMemoDelete = widget.onMemoDelete;
    final onTodoListDelete = widget.onTodoListDelete;
    final onTodoItemDelete = widget.onTodoItemDelete;
    final stacked = widget.stacked;
    final memos = ref.watch(memosForDayProvider(day)).valueOrNull ??
        const <Memo>[];
    final todoLists = ref.watch(todoListsForDayProvider(day)).valueOrNull ??
        const <TodoList>[];
    final todoItems = ref.watch(todoItemsForDayProvider(day)).valueOrNull ??
        const <TodoItem>[];
    final totalCount = memos.length + todoLists.length + todoItems.length;

    final wd = DayItemsPanel._weekdayLabels[day.weekday - 1];
    final wdColor = day.weekday == DateTime.sunday
        ? Colors.red.shade400
        : day.weekday == DateTime.saturday
            ? Colors.blue.shade400
            : Colors.black54;

    // シート内 pointer 発生を Provider に記録。home_screen の
    // `_wrapUnfocusOnTap.onPointerUp` が、シート内タップでは閉じないように参照する。
    // また、タップ（座標差分小）ならスワイプ削除ボタンを一斉に閉じる。
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _downPos = e.position;
        ref.read(calendarSheetLastTouchProvider.notifier).state =
            DateTime.now().millisecondsSinceEpoch;
      },
      onPointerUp: (e) {
        ref.read(calendarSheetLastTouchProvider.notifier).state =
            DateTime.now().millisecondsSinceEpoch;
        final down = _downPos;
        _downPos = null;
        if (down == null) return;
        final dx = (e.position.dx - down.dx).abs();
        final dy = (e.position.dy - down.dy).abs();
        if (dx <= 8 && dy <= 8) {
          // タップとみなして全 SwipeDeleteRow に閉じる通知。カードタップ時も
          // 通知が走るが、削除ボタンが開いていない行は無視するので無害。
          ref.read(calendarSheetSwipeCloseProvider.notifier).state++;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // ヘッダ（日付 + × ボタン、上下 padding は 80%）
        Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
          decoration: BoxDecoration(
            color: Colors.lightBlue.shade50,
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${day.year}年${day.month}月${day.day}日',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
              Text(
                '($wd)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: wdColor,
                ),
              ),
              const Spacer(),
              if (onClose != null)
                InkResponse(
                  onTap: onClose,
                  radius: 18,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // アイテム一覧 + 各列下端にフロート FAB
        // stacked=false: 横 2 列（左=メモ / 右=ToDo）
        // stacked=true:  縦並び（上=メモ / 下=ToDo）— iPad 横画面の右カラム等の狭幅向け
        Expanded(
          child: Container(
            // grey.shade100 と shade200 の中間（ほんのり濃い）
            color: const Color(0xFFF1F1F1),
            child: totalCount == 0 && onAddMemo == null && onAddTodoList == null
                ? const _EmptyState()
                : Builder(builder: (_) {
                    final memoColumn = _ColumnList(
                      sectionLabel: 'メモ',
                      sectionIcon: Icons.note_outlined,
                      sectionColor: Colors.amber.shade700,
                      isEmpty: memos.isEmpty,
                      children: [
                        for (final m in memos)
                          _SwipeDeleteRow(
                            onDelete: onMemoDelete == null
                                ? null
                                : () => onMemoDelete(m),
                            child: _MemoTile(
                                memo: m, onTap: () => onMemoTap(m)),
                          ),
                      ],
                    );
                    final todoColumn = _ColumnList(
                      sectionLabel: 'ToDo',
                      sectionIcon: Icons.checklist,
                      sectionColor: Colors.green.shade600,
                      isEmpty: todoLists.isEmpty && todoItems.isEmpty,
                      children: [
                        for (final l in todoLists)
                          _SwipeDeleteRow(
                            onDelete: onTodoListDelete == null
                                ? null
                                : () => onTodoListDelete(l),
                            child: _TodoListTile(
                                list: l, onTap: () => onTodoListTap(l)),
                          ),
                        for (final it in todoItems)
                          _SwipeDeleteRow(
                            onDelete: onTodoItemDelete == null
                                ? null
                                : () => onTodoItemDelete(it),
                            child: _TodoItemTile(
                              item: it,
                              onTap: onTodoItemTap == null
                                  ? null
                                  : () => onTodoItemTap(it),
                            ),
                          ),
                      ],
                    );
                    final memoFab = onAddMemo != null
                        ? _FloatAddFab(
                            accent: Colors.amber.shade700,
                            onTap: onAddMemo,
                          )
                        : null;
                    final todoFab = onAddTodoList != null
                        ? _FloatAddFab(
                            accent: Colors.green.shade600,
                            onTap: onAddTodoList,
                          )
                        : null;
                    final dividerColor =
                        Colors.black.withValues(alpha: 0.15);
                    if (stacked) {
                      // 縦並び: 各エリアごとに独立した Stack(List + FAB)
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                memoColumn,
                                if (memoFab != null)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 14,
                                    child: Center(child: memoFab),
                                  ),
                              ],
                            ),
                          ),
                          Container(height: 0.5, color: dividerColor),
                          Expanded(
                            child: Stack(
                              children: [
                                todoColumn,
                                if (todoFab != null)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 14,
                                    child: Center(child: todoFab),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    // 横 2 列
                    return Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: memoColumn),
                            Container(width: 0.5, color: dividerColor),
                            Expanded(child: todoColumn),
                          ],
                        ),
                        if (memoFab != null || todoFab != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 14,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                      child:
                                          memoFab ?? const SizedBox.shrink()),
                                ),
                                const SizedBox(width: 0.5),
                                Expanded(
                                  child: Center(
                                      child:
                                          todoFab ?? const SizedBox.shrink()),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }),
          ),
        ),
      ],
    ),
    );
  }
}

/// 左右の列の中身（セクション見出し + 内容 + 下端の FAB スペース）。
/// 各列が独立してスクロールできるように個別の ListView を持つ。
class _ColumnList extends StatelessWidget {
  final String sectionLabel;
  final IconData sectionIcon;
  final Color sectionColor;
  final bool isEmpty;
  final List<Widget> children;

  const _ColumnList({
    required this.sectionLabel,
    required this.sectionIcon,
    required this.sectionColor,
    required this.isEmpty,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 80), // 下端は FAB スペース
      children: [
        _SectionHeader(
          label: sectionLabel,
          icon: sectionIcon,
          color: sectionColor,
        ),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'なし',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withValues(alpha: 0.35),
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}

/// 円形フロート追加ボタン。＋アイコンのみのシンプル仕様。
class _FloatAddFab extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _FloatAddFab({
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 33,
          height: 33,
          // Container を縦横に重ねて「＋」を描画。Text や Icon だとフォントの
          // ベースラインで微妙に下にずれるので Stack で確実に中央に。
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 15, height: 3, child: ColoredBox(color: Colors.white)),
              SizedBox(width: 3, height: 15, child: ColoredBox(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Hiragino Sans',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBar extends StatelessWidget {
  final VoidCallback onAddMemo;
  final VoidCallback onAddTodoList;

  const _AddBar({required this.onAddMemo, required this.onAddTodoList});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade50,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _AddRowButton(
                icon: Icons.note_outlined,
                iconColor: Colors.amber.shade700,
                label: 'メモ',
                onTap: onAddMemo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AddRowButton(
                icon: Icons.checklist,
                iconColor: Colors.green.shade600,
                label: 'ToDo',
                onTap: onAddTodoList,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRowButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _AddRowButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.lightBlue.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.08),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Hiragino Sans',
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // グレー丸 + 白抜き + ボタン（小さめ）
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade400,
                ),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      Container(
                        width: 2.5,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note,
                size: 40, color: Colors.black.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            const Text(
              'この日のメモ・ToDoはありません',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 各カードに共通する枠（白背景、角丸、薄いドロップシャドウ、タップ波紋）
class _CardShell extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _CardShell({this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// タイトル / 本文の間に挟む薄い仕切り線
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 0.5,
        color: Colors.black.withValues(alpha: 0.12),
      ),
    );
  }
}

class _MemoTile extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;

  const _MemoTile({required this.memo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasTitle = memo.title.isNotEmpty;
    final hasContent = memo.content.isNotEmpty;
    return _CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTitle)
            Text(
              memo.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Hiragino Sans',
                color: Colors.black87,
              ),
            ),
          if (hasTitle && hasContent) const _Divider(),
          if (hasContent)
            Text(
              memo.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontFamily: 'Hiragino Sans',
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }
}

class _TodoListTile extends ConsumerWidget {
  final TodoList list;
  final VoidCallback onTap;

  const _TodoListTile({required this.list, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final query = db.select(db.todoItems)
      ..where((t) => t.listId.equals(list.id) & t.parentId.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
      ..limit(3);
    final stream = query.watch();

    return StreamBuilder<List<TodoItem>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? const <TodoItem>[];
        final hasTitle = list.title.isNotEmpty;
        return _CardShell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTitle)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.bookmark_fill,
                      size: 13,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        list.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Hiragino Sans',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              if (hasTitle && items.isNotEmpty) const _Divider(),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 3),
                // 配下項目はリスト名より少しインデントして階層を表現
                Padding(
                  padding: EdgeInsets.only(left: hasTitle ? 12 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].isDone
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          items[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Hiragino Sans',
                            color: items[i].isDone
                                ? Colors.black38
                                : Colors.black54,
                            decoration: items[i].isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TodoItemTile extends StatelessWidget {
  final TodoItem item;
  final VoidCallback? onTap;

  const _TodoItemTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasTitle = item.title.isNotEmpty;
    final hasMemo = item.memo != null && item.memo!.isNotEmpty;
    return _CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTitle)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  item.isDone
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 15,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Hiragino Sans',
                      color: item.isDone ? Colors.black45 : Colors.black87,
                      decoration: item.isDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          if (hasTitle && hasMemo) const _Divider(),
          if (hasMemo)
            Text(
              item.memo!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontFamily: 'Hiragino Sans',
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }
}

/// iOS 風スワイプ削除: 左スワイプで赤い「削除」ボタン露出、タップで onDelete。
/// onDelete が null の場合は素通り（child のみ表示）。
/// 削除ボタンタップ時は onDelete を await し、完了後にボタンを閉じる
/// （確認ダイアログ表示中に削除ボタンが消えるのを防ぐ）。
/// シート内の他の場所がタップされたら（calendarSheetSwipeCloseProvider 経由）
/// 自動で閉じる。
class _SwipeDeleteRow extends ConsumerStatefulWidget {
  final Widget child;
  final Future<void> Function()? onDelete;

  const _SwipeDeleteRow({required this.child, this.onDelete});

  @override
  ConsumerState<_SwipeDeleteRow> createState() => _SwipeDeleteRowState();
}

class _SwipeDeleteRowState extends ConsumerState<_SwipeDeleteRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const double _buttonWidth = 72;
  // 自分の削除ボタンタップ中は close 通知を無視する。Listener.onPointerUp が
  // 削除ボタン押下でも発火 → calendarSheetSwipeCloseProvider++ で自分が
  // close されるのを防ぐ。
  bool _holdingForDialog = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    if (widget.onDelete == null) return widget.child;
    // シート内の別の場所がタップされたら自分の削除ボタンを閉じる
    ref.listen<int>(calendarSheetSwipeCloseProvider, (_, _) {
      if (_holdingForDialog) return;
      if (_controller.value > 0) _close();
    });
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final v = _controller.value - d.primaryDelta! / _buttonWidth;
        _controller.value = v.clamp(0.0, 1.0);
      },
      onHorizontalDragEnd: (_) {
        if (_controller.value > 0.5) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      // 列の幅（メモ列 / ToDo列）を超えてカードがはみ出さないよう clip する。
      // 中央の仕切り線をまたいで反対側のエリアに侵入するのを防ぐ。
      child: ClipRect(
        child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 赤い削除ボタン（背面）。_CardShell の外側 Padding 分内側にずらす。
          Positioned(
            right: 4,
            top: 3,
            bottom: 3,
            width: _buttonWidth,
            child: Listener(
              // 削除ボタンへの pointer down で flag を立て、外側 Listener の
              // onPointerUp が calendarSheetSwipeCloseProvider を increment しても
              // 自分の close 通知を無視できるようにする。onTapDown より早い順序。
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _holdingForDialog = true,
              onPointerCancel: (_) => _holdingForDialog = false,
              child: GestureDetector(
                onTapCancel: () => _holdingForDialog = false,
                onTap: () async {
                  // ダイアログ完了まで閉じない（どのカードへの操作だったか
                  // ユーザーが見失わないように削除ボタンを保持する）
                  try {
                    await widget.onDelete!();
                  } finally {
                    _holdingForDialog = false;
                  }
                  if (mounted) _close();
                },
                child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.trash, color: Colors.white, size: 14),
                    SizedBox(width: 3),
                    Text(
                      '削除',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => Transform.translate(
              offset: Offset(-_buttonWidth * _controller.value, 0),
              child: child,
            ),
            child: SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _controller.value > 0 ? _close : null,
                behavior: HitTestBehavior.translucent,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
