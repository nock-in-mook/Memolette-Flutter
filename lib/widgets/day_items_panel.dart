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
  final VoidCallback? onAddTap;

  const DayItemsPanel({
    super.key,
    required this.day,
    required this.onMemoTap,
    required this.onTodoListTap,
    this.onTodoItemTap,
    this.onAddTap,
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
              Text(
                '$totalCount件',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ],
          ),
        ),
        // アイテム一覧 + 追加ボタン
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
                            if (memos.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'メモ', count: memos.length),
                              for (final m in memos)
                                _MemoTile(
                                    memo: m, onTap: () => onMemoTap(m)),
                            ],
                            if (todoLists.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'ToDoリスト',
                                  count: todoLists.length),
                              for (final l in todoLists)
                                _TodoListTile(
                                    list: l, onTap: () => onTodoListTap(l)),
                            ],
                            if (todoItems.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'ToDoアイテム',
                                  count: todoItems.length),
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
                if (onAddTap != null) _AddButton(onTap: onAddTap!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.blue.shade600,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'メモ・ToDoを追加',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Hiragino Sans',
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black38,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
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
    final title =
        memo.title.isEmpty ? (memo.content.isEmpty ? '無題' : memo.content) : memo.title;
    return _Tile(
      icon: Icons.note_outlined,
      iconColor: Colors.amber.shade700,
      title: title,
      subtitle: memo.title.isNotEmpty && memo.content.isNotEmpty
          ? memo.content
          : null,
      onTap: onTap,
    );
  }
}

class _TodoListTile extends StatelessWidget {
  final TodoList list;
  final VoidCallback onTap;

  const _TodoListTile({required this.list, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: Icons.checklist,
      iconColor: Colors.green.shade600,
      title: list.title.isEmpty ? '無題のリスト' : list.title,
      onTap: onTap,
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
      subtitle: item.memo,
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
  final bool strikethrough;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor),
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
                            maxLines: 1,
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
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.black.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
