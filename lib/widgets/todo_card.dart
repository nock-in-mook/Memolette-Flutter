import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';

/// メモ一覧グリッドに混在表示するToDoカード
/// 本家TodoCardView準拠: しおり + タイトル + "ToDo" + 件数
class TodoCard extends ConsumerWidget {
  final TodoList todoList;
  final VoidCallback onTap;
  final bool isHighlighted;

  const TodoCard({
    super.key,
    required this.todoList,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    // ルートアイテムをwatch
    final rootStream = (db.select(db.todoItems)
          ..where(
              (t) => t.listId.equals(todoList.id) & t.parentId.isNull()))
        .watch();

    return StreamBuilder<List<TodoItem>>(
      stream: rootStream,
      builder: (context, snap) {
        final items = snap.data ?? const <TodoItem>[];
        final total = items.length;
        final done = items.where((i) => i.isDone).length;

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Colors.blue.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                  offset: const Offset(-1, 1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル行: しおり + タイトル
                    Row(
                      children: [
                        const Icon(CupertinoIcons.bookmark_fill,
                            size: 11, color: Colors.orange),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            todoList.title.isEmpty
                                ? '(タイトルなし)'
                                : todoList.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: todoList.title.isEmpty
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              fontFamily: 'Hiragino Sans',
                              color: todoList.title.isEmpty
                                  ? Colors.grey.withValues(alpha: 0.5)
                                  : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // "ToDo" + 件数
                    Row(
                      children: [
                        const Text(
                          'ToDo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Hiragino Sans',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$done/$total件',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Hiragino Sans',
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // ピン・ロックアイコン（右上）
                if (todoList.isPinned || todoList.isLocked)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (todoList.isPinned)
                          Icon(Icons.push_pin,
                              size: 8,
                              color: Colors.orange.withValues(alpha: 0.6)),
                        if (todoList.isPinned && todoList.isLocked)
                          const SizedBox(width: 2),
                        if (todoList.isLocked)
                          Icon(Icons.lock,
                              size: 8,
                              color: Colors.orange.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
