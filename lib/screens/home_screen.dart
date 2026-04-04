import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../widgets/memo_card.dart';
import '../widgets/tag_edit_dialog.dart';
import 'memo_edit_screen.dart';

/// ホーム画面: タブ付きメモ一覧（バッグ表示）
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  // 現在選択中のタブインデックス
  // 0=すべて, 1=タグなし, 2以降=親タグ
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final parentTagsAsync = ref.watch(parentTagsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Memolette'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          // タグ追加ボタン
          IconButton(
            icon: const Icon(Icons.label_outline),
            onPressed: () => _showCreateTagDialog(context),
            tooltip: 'タグを追加',
          ),
        ],
      ),
      body: Column(
        children: [
          // タブバー
          parentTagsAsync.when(
            data: (parentTags) => _buildTabBar(parentTags),
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox(height: 48),
          ),
          // メモ一覧
          Expanded(
            child: parentTagsAsync.when(
              data: (parentTags) => _buildMemoList(parentTags),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewMemo(context),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// タブバー（すべて・タグなし・親タグ群）
  Widget _buildTabBar(List<Tag> parentTags) {
    // タブ上限チェック: selectedIndexが範囲外にならないように
    final maxIndex = 1 + parentTags.length; // 0=すべて, 1=タグなし, 2+
    if (_selectedTabIndex > maxIndex) {
      _selectedTabIndex = 0;
    }

    return Container(
      color: Colors.white,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          // 「すべて」タブ
          _buildTab(
            label: 'すべて',
            color: TagColors.allTabColor,
            isSelected: _selectedTabIndex == 0,
            onTap: () => setState(() => _selectedTabIndex = 0),
          ),
          // 「タグなし」タブ
          _buildTab(
            label: 'タグなし',
            color: TagColors.palette[0],
            isSelected: _selectedTabIndex == 1,
            onTap: () => setState(() => _selectedTabIndex = 1),
          ),
          // 親タグタブ
          for (int i = 0; i < parentTags.length; i++)
            _buildTab(
              label: parentTags[i].name,
              color: TagColors.getColor(parentTags[i].colorIndex),
              isSelected: _selectedTabIndex == i + 2,
              onTap: () => setState(() => _selectedTabIndex = i + 2),
              onLongPress: () =>
                  _showTagActions(context, parentTags[i]),
            ),
          // 「+」追加ボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: GestureDetector(
              onTap: () => _showCreateTagDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius:
                      BorderRadius.circular(CornerRadius.parentTag),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, size: 18, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 個別タブウィジェット
  Widget _buildTab({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(CornerRadius.parentTag),
            boxShadow: isSelected ? [AppShadows.light()] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  /// タブに応じたメモ一覧
  Widget _buildMemoList(List<Tag> parentTags) {
    if (_selectedTabIndex == 0) {
      // すべて
      return _AllMemosGrid(
        onTapMemo: _openMemo,
        onLongPressMemo: (m) => _showMemoActions(context, m),
      );
    } else if (_selectedTabIndex == 1) {
      // タグなし
      return _UntaggedMemosGrid(
        onTapMemo: _openMemo,
        onLongPressMemo: (m) => _showMemoActions(context, m),
      );
    } else {
      // タグ別
      final tagIndex = _selectedTabIndex - 2;
      if (tagIndex >= parentTags.length) return const SizedBox();
      final tag = parentTags[tagIndex];
      return _TagMemosGrid(
        tagId: tag.id,
        onTapMemo: _openMemo,
        onLongPressMemo: (m) => _showMemoActions(context, m),
      );
    }
  }

  Future<void> _createNewMemo(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final nav = Navigator.of(context);
    final memo = await db.createMemo();
    if (mounted) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => MemoEditScreen(memoId: memo.id),
        ),
      );
    }
  }

  void _openMemo(Memo memo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(memoId: memo.id),
      ),
    );
  }

  /// タグ作成ダイアログ
  Future<void> _showCreateTagDialog(BuildContext context) async {
    final result = await showDialog<TagEditResult>(
      context: context,
      builder: (_) => const TagEditDialog(),
    );
    if (result != null) {
      final db = ref.read(databaseProvider);
      await db.createTag(
        name: result.name,
        colorIndex: result.colorIndex,
        parentTagId: result.parentTagId,
      );
    }
  }

  /// タグ長押しメニュー
  void _showTagActions(BuildContext context, Tag tag) {
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
            // ヘッダ
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: TagColors.getColor(tag.colorIndex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(tag.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            // 編集
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('編集'),
              onTap: () {
                Navigator.pop(context);
                _editTag(tag);
              },
            ),
            // 子タグ追加
            ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right),
              title: const Text('子タグを追加'),
              onTap: () {
                Navigator.pop(context);
                _addChildTag(tag);
              },
            ),
            // 削除
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTag(tag);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editTag(Tag tag) async {
    final result = await showDialog<TagEditResult>(
      context: context,
      builder: (_) => TagEditDialog(existingTag: tag),
    );
    if (result != null) {
      final db = ref.read(databaseProvider);
      await db.updateTag(
        id: tag.id,
        name: result.name,
        colorIndex: result.colorIndex,
      );
    }
  }

  Future<void> _addChildTag(Tag parentTag) async {
    final result = await showDialog<TagEditResult>(
      context: context,
      builder: (_) => TagEditDialog(parentTagId: parentTag.id),
    );
    if (result != null) {
      final db = ref.read(databaseProvider);
      await db.createTag(
        name: result.name,
        colorIndex: result.colorIndex,
        parentTagId: parentTag.id,
      );
    }
  }

  void _confirmDeleteTag(Tag tag) {
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
            Text('「${tag.name}」を削除しますか？',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('子タグも一緒に削除されます。メモは削除されません。',
                textAlign: TextAlign.center),
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
                      db.deleteTag(tag.id);
                      Navigator.pop(context);
                      // タブをリセット
                      setState(() => _selectedTabIndex = 0);
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

  /// メモ長押しメニュー
  void _showMemoActions(BuildContext context, Memo memo) {
    final db = ref.read(databaseProvider);
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
                memo.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: memo.isPinned ? Colors.orange : null,
              ),
              title: Text(memo.isPinned ? 'ピン留め解除' : 'ピン留め'),
              onTap: () {
                db.updateMemo(id: memo.id, isPinned: !memo.isPinned);
                Navigator.pop(context);
              },
            ),
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
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                if (memo.isLocked) {
                  _showLockedWarning();
                } else {
                  _confirmDeleteMemo(db, memo);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLockedWarning() {
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
            const Icon(Icons.lock, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            const Text('このメモはロックされています',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _confirmDeleteMemo(AppDatabase db, Memo memo) {
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

// ========================================
// メモグリッド: 全メモ
// ========================================
class _AllMemosGrid extends ConsumerWidget {
  final void Function(Memo) onTapMemo;
  final void Function(Memo) onLongPressMemo;

  const _AllMemosGrid({
    required this.onTapMemo,
    required this.onLongPressMemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(allMemosProvider);
    return memosAsync.when(
      data: (memos) => memos.isEmpty
          ? _emptyState('メモがありません', '＋ボタンで最初のメモを作成しましょう')
          : _grid(memos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
    );
  }

  Widget _grid(List<Memo> memos) {
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
        itemBuilder: (_, index) {
          final memo = memos[index];
          return MemoCard(
            memo: memo,
            onTap: () => onTapMemo(memo),
            onLongPress: () => onLongPressMemo(memo),
          );
        },
      ),
    );
  }
}

// ========================================
// メモグリッド: タグなし
// ========================================
class _UntaggedMemosGrid extends ConsumerWidget {
  final void Function(Memo) onTapMemo;
  final void Function(Memo) onLongPressMemo;

  const _UntaggedMemosGrid({
    required this.onTapMemo,
    required this.onLongPressMemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(untaggedMemosProvider);
    return memosAsync.when(
      data: (memos) => memos.isEmpty
          ? _emptyState('タグなしメモはありません', '')
          : _grid(memos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
    );
  }

  Widget _grid(List<Memo> memos) {
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
        itemBuilder: (_, index) {
          final memo = memos[index];
          return MemoCard(
            memo: memo,
            onTap: () => onTapMemo(memo),
            onLongPress: () => onLongPressMemo(memo),
          );
        },
      ),
    );
  }
}

// ========================================
// メモグリッド: タグ別
// ========================================
class _TagMemosGrid extends ConsumerWidget {
  final String tagId;
  final void Function(Memo) onTapMemo;
  final void Function(Memo) onLongPressMemo;

  const _TagMemosGrid({
    required this.tagId,
    required this.onTapMemo,
    required this.onLongPressMemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosForTagProvider(tagId));
    return memosAsync.when(
      data: (memos) => memos.isEmpty
          ? _emptyState('このタグのメモはありません', '')
          : _grid(memos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
    );
  }

  Widget _grid(List<Memo> memos) {
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
        itemBuilder: (_, index) {
          final memo = memos[index];
          return MemoCard(
            memo: memo,
            onTap: () => onTapMemo(memo),
            onLongPress: () => onLongPressMemo(memo),
          );
        },
      ),
    );
  }
}

/// 共通の空状態ウィジェット
Widget _emptyState(String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.note_add_outlined, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(title, style: TextStyle(fontSize: 18, color: Colors.grey[500])),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        ],
      ],
    ),
  );
}
