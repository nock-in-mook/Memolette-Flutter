import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';

/// カレンダー画面の「選択された日のアイテム一覧」パネル
/// - iPad 横画面: 右カラムに常時表示
/// - 縦画面: showModalBottomSheet で日付タップ時に表示
class DayItemsPanel extends ConsumerWidget {
  final DateTime day;
  final ValueChanged<Memo> onMemoTap;
  final ValueChanged<TodoList> onTodoListTap;
  final ValueChanged<TodoItem>? onTodoItemTap;
  final VoidCallback? onAddMemo;
  final VoidCallback? onAddTodoList;

  const DayItemsPanel({
    super.key,
    required this.day,
    required this.onMemoTap,
    required this.onTodoListTap,
    this.onTodoItemTap,
    this.onAddMemo,
    this.onAddTodoList,
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
        // ヘッダ
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
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
              // メモ件数（アイコン + 数字）
              Icon(Icons.note_outlined,
                  size: 15, color: Colors.amber.shade700),
              const SizedBox(width: 3),
              Text(
                '${memos.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
              const SizedBox(width: 10),
              // ToDo 件数（リスト + アイテムの合算）
              Icon(Icons.checklist,
                  size: 15, color: Colors.green.shade600),
              const SizedBox(width: 3),
              Text(
                '${todoLists.length + todoItems.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ],
          ),
        ),
        // アイテム一覧（スクロール）+ 追加バー（固定）
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Expanded(
                  child: totalCount == 0
                      ? const _EmptyState()
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            for (final m in memos)
                              _MemoTile(
                                  memo: m, onTap: () => onMemoTap(m)),
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

class _AddBar extends StatelessWidget {
  final VoidCallback onAddMemo;
  final VoidCallback onAddTodoList;

  const _AddBar({required this.onAddMemo, required this.onAddTodoList});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
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
      color: Colors.grey.shade50,
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

class _MemoTile extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;

  const _MemoTile({required this.memo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasTitle = memo.title.isNotEmpty;
    final title = hasTitle
        ? memo.title
        : (memo.content.isEmpty ? '無題' : memo.content.split('\n').first);
    final subtitle = hasTitle ? memo.content : null;
    return _Tile(
      icon: Icons.note_outlined,
      iconColor: Colors.amber.shade700,
      title: title,
      subtitle: (subtitle != null && subtitle.isNotEmpty) ? subtitle : null,
      maxSubtitleLines: 3,
      onTap: onTap,
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
    // ルート直下のアイテムのみ対象（深い階層は表示しない）
    final query = db.select(db.todoItems)
      ..where((t) => t.listId.equals(list.id) & t.parentId.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
      ..limit(3);
    final stream = query.watch();

    return StreamBuilder<List<TodoItem>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? const <TodoItem>[];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.checklist,
                          size: 18, color: Colors.green.shade600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            list.title.isEmpty ? '無題のリスト' : list.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Hiragino Sans',
                              color: Colors.black87,
                            ),
                          ),
                          for (final it in items) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  it.isDone
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 14,
                                  color: it.isDone
                                      ? Colors.grey.shade500
                                      : Colors.black45,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    it.title.isEmpty ? '無題' : it.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Hiragino Sans',
                                      color: it.isDone
                                          ? Colors.black38
                                          : Colors.black54,
                                      decoration: it.isDone
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
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.chevron_right,
                          size: 18,
                          color: Colors.black.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ),
            ),
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
    return _Tile(
      icon: item.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
      iconColor: item.isDone ? Colors.grey.shade500 : Colors.green.shade400,
      title: item.title.isEmpty ? '無題' : item.title,
      subtitle: (item.memo == null || item.memo!.isEmpty) ? null : item.memo,
      maxSubtitleLines: 3,
      strikethrough: item.isDone,
      onTap: onTap,
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final int maxSubtitleLines;
  final bool strikethrough;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.maxSubtitleLines = 1,
    this.strikethrough = false,
    this.onTap,
  });

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Hiragino Sans',
                          decoration: strikethrough
                              ? TextDecoration.lineThrough
                              : null,
                          color: strikethrough
                              ? Colors.black45
                              : Colors.black87,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            maxLines: maxSubtitleLines,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontFamily: 'Hiragino Sans',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.chevron_right,
                      size: 18, color: Colors.black.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
