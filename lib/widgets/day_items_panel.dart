import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';

/// カレンダー画面の「選択された日のアイテム一覧」パネル
class DayItemsPanel extends ConsumerWidget {
  final DateTime day;
  final ValueChanged<Memo> onMemoTap;
  final ValueChanged<TodoList> onTodoListTap;
  final ValueChanged<TodoItem>? onTodoItemTap;
  final VoidCallback? onAddMemo;
  final VoidCallback? onAddTodoList;
  // 指定するとヘッダ右端に × ボタンが出てパネルを閉じる UI を提供
  final VoidCallback? onClose;

  const DayItemsPanel({
    super.key,
    required this.day,
    required this.onMemoTap,
    required this.onTodoListTap,
    this.onTodoItemTap,
    this.onAddMemo,
    this.onAddTodoList,
    this.onClose,
  });

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(memosForDayProvider(day)).valueOrNull ??
        const <Memo>[];
    final todoLists = ref.watch(todoListsForDayProvider(day)).valueOrNull ??
        const <TodoList>[];
    final todoItems = ref.watch(todoItemsForDayProvider(day)).valueOrNull ??
        const <TodoItem>[];
    final totalCount = memos.length + todoLists.length + todoItems.length;

    final wd = _weekdayLabels[day.weekday - 1];
    final wdColor = day.weekday == DateTime.sunday
        ? Colors.red.shade400
        : day.weekday == DateTime.saturday
            ? Colors.blue.shade400
            : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ヘッダ（日付 + × ボタン）
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
              Text(
                '($wd)',
                style: TextStyle(
                  fontSize: 14,
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
        // アイテム一覧（縦並び 1 列、メモ → ToDo の順）+ 追加バー（固定）
        Expanded(
          child: Container(
            color: Colors.lightBlue.shade50,
            child: Column(
              children: [
                Expanded(
                  child: totalCount == 0
                      ? const _EmptyState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          children: [
                            if (memos.isNotEmpty) ...[
                              _SectionHeader(
                                label: 'メモ',
                                icon: Icons.note_outlined,
                                color: Colors.amber.shade700,
                              ),
                              for (final m in memos)
                                _MemoTile(
                                    memo: m, onTap: () => onMemoTap(m)),
                            ],
                            if (todoLists.isNotEmpty || todoItems.isNotEmpty) ...[
                              _SectionHeader(
                                label: 'ToDo',
                                icon: Icons.checklist,
                                color: Colors.green.shade600,
                              ),
                              for (final l in todoLists)
                                _TodoListTile(
                                    list: l, onTap: () => onTodoListTap(l)),
                              for (final it in todoItems)
                                _TodoItemTile(
                                  item: it,
                                  onTap: onTodoItemTap == null
                                      ? null
                                      : () => onTodoItemTap!(it),
                                ),
                            ],
                          ],
                        ),
                ),
                if (onAddMemo != null && onAddTodoList != null)
                  _AddBar(
                    onAddMemo: onAddMemo!,
                    onAddTodoList: onAddTodoList!,
                  ),
              ],
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
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

/// 各カードに共通する枠（白背景、角丸、タップ波紋）
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                fontSize: 14,
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
                height: 1.35,
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        list.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
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
                if (i > 0) const SizedBox(height: 4),
                Row(
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
                const Icon(
                  CupertinoIcons.bookmark_fill,
                  size: 13,
                  color: Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
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
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
