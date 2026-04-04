import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import 'todo_list_screen.dart';

// ========================================
// ToDoリスト一覧プロバイダー
// ========================================
final todoListsProvider = StreamProvider<List<TodoList>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.todoLists)
        ..orderBy([
          (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
          (t) => OrderingTerm(
              expression: t.manualSortOrder, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
      .watch();
});

/// 特定リストのルートアイテムプロバイダー
final rootItemsProvider =
    StreamProvider.family<List<TodoItem>, String>((ref, listId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.todoItems)
        ..where(
            (t) => t.listId.equals(listId) & t.parentId.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();
});

/// ToDoリスト一覧画面
class TodoListsScreen extends ConsumerWidget {
  const TodoListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(todoListsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ToDo'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: listsAsync.when(
        data: (lists) => lists.isEmpty
            ? _buildEmptyState(context, ref)
            : _buildListGrid(context, ref, lists),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('ToDoリストがありません',
              style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('＋ボタンで最初のリストを作成しましょう',
              style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildListGrid(
      BuildContext context, WidgetRef ref, List<TodoList> lists) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: lists.length,
        itemBuilder: (context, index) {
          final list = lists[index];
          return _TodoListCard(
            list: list,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TodoListScreen(listId: list.id),
              ),
            ),
            onLongPress: () => _showListActions(context, ref, list),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CornerRadius.dialog),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('新規ToDoリスト',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '例: 買い物リスト',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(CornerRadius.button),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _createList(ref, value.trim());
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          _createList(ref, controller.text.trim());
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('作成'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createList(WidgetRef ref, String title) async {
    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    await db.into(db.todoLists).insert(TodoListsCompanion.insert(
      id: id,
      title: Value(title),
    ));
  }

  void _showListActions(
      BuildContext context, WidgetRef ref, TodoList list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CornerRadius.dialog),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                list.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: list.isPinned ? Colors.orange : null,
              ),
              title: Text(list.isPinned ? '固定を解除' : 'トップに固定'),
              onTap: () {
                final db = ref.read(databaseProvider);
                (db.update(db.todoLists)
                      ..where((t) => t.id.equals(list.id)))
                    .write(TodoListsCompanion(
                        isPinned: Value(!list.isPinned)));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                list.isLocked ? Icons.lock : Icons.lock_outline,
                color: list.isLocked ? Colors.red : null,
              ),
              title: Text(list.isLocked ? 'ロック解除' : '削除防止ロック'),
              onTap: () {
                final db = ref.read(databaseProvider);
                (db.update(db.todoLists)
                      ..where((t) => t.id.equals(list.id)))
                    .write(TodoListsCompanion(
                        isLocked: Value(!list.isLocked)));
                Navigator.pop(context);
              },
            ),
            if (!list.isLocked)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('削除',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref, list);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, TodoList list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CornerRadius.dialog),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text('「${list.title}」を削除しますか？',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('リスト内の全タスクも削除されます'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final db = ref.read(databaseProvider);
                      // アイテムも削除
                      (db.delete(db.todoItems)
                            ..where(
                                (t) => t.listId.equals(list.id)))
                          .go();
                      (db.delete(db.todoLists)
                            ..where((t) => t.id.equals(list.id)))
                          .go();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text('削除',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ToDoリストカード（グリッド用）
class _TodoListCard extends ConsumerWidget {
  final TodoList list;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TodoListCard({
    required this.list,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootItemsAsync = ref.watch(rootItemsProvider(list.id));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CornerRadius.card),
          boxShadow: [AppShadows.card()],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダ
            Row(
              children: [
                if (list.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin,
                        size: 14, color: Colors.orange),
                  ),
                if (list.isLocked)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.lock, size: 14, color: Colors.red),
                  ),
                Expanded(
                  child: Text(
                    list.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // プレビュー（ルートアイテム5件）
            Expanded(
              child: rootItemsAsync.when(
                data: (items) {
                  final preview = items.take(5).toList();
                  final done = items.where((i) => i.isDone).length;
                  final total = items.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...preview.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  item.isDone
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 16,
                                  color: item.isDone
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.isDone
                                          ? Colors.grey
                                          : Colors.black87,
                                      decoration: item.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Spacer(),
                      // 完了カウント
                      if (total > 0)
                        Text(
                          total == done
                              ? '全完了'
                              : '$done/$total 完了',
                          style: TextStyle(
                            fontSize: 11,
                            color: total == done
                                ? Colors.green
                                : Colors.grey[500],
                            fontWeight: total == done
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
