import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../widgets/memo_card.dart';
import 'memo_edit_screen.dart';

/// ホーム画面: メモ一覧（グリッド表示）
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(allMemosProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Memolette'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: memosAsync.when(
        data: (memos) => memos.isEmpty
            ? _buildEmptyState(context, ref)
            : _buildMemoGrid(context, ref, memos),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
      // 新規メモ作成ボタン
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewMemo(context, ref),
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
          Icon(Icons.note_add_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'メモがありません',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            '＋ボタンで最初のメモを作成しましょう',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoGrid(
      BuildContext context, WidgetRef ref, List<Memo> memos) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: memos.length,
        itemBuilder: (context, index) {
          final memo = memos[index];
          return MemoCard(
            memo: memo,
            onTap: () => _openMemo(context, memo),
            onLongPress: () => _showMemoActions(context, ref, memo),
          );
        },
      ),
    );
  }

  Future<void> _createNewMemo(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo();
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemoEditScreen(memoId: memo.id),
        ),
      );
    }
  }

  void _openMemo(BuildContext context, Memo memo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(memoId: memo.id),
      ),
    );
  }

  /// メモの長押しメニュー（カスタムリッチUI）
  void _showMemoActions(BuildContext context, WidgetRef ref, Memo memo) {
    final db = ref.read(databaseProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ピン留めトグル
            ListTile(
              leading: Icon(
                memo.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: memo.isPinned ? Colors.orange : null,
              ),
              title: Text(memo.isPinned ? 'ピン留め解除' : 'ピン留め'),
              onTap: () {
                db.updateMemo(id: memo.id, isPinned: !memo.isPinned);
                Navigator.pop(context);
              },
            ),
            // ロックトグル
            ListTile(
              leading: Icon(
                memo.isLocked ? Icons.lock : Icons.lock_outline,
                color: memo.isLocked ? Colors.red : null,
              ),
              title: Text(memo.isLocked ? 'ロック解除' : 'ロック（削除防止）'),
              onTap: () {
                db.updateMemo(id: memo.id, isLocked: !memo.isLocked);
                Navigator.pop(context);
              },
            ),
            // 削除
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                if (memo.isLocked) {
                  _showLockedWarning(context);
                } else {
                  _confirmDelete(context, db, memo);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLockedWarning(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            const Text('このメモはロックされています',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('削除するにはロックを解除してください'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppDatabase db, Memo memo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_forever, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('メモを削除しますか？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      db.deleteMemo(memo.id);
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
