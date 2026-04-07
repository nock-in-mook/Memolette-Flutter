import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../widgets/memo_card.dart';
import '../widgets/memo_input_area.dart';
import '../widgets/tag_edit_dialog.dart';
import '../widgets/trapezoid_tab_shape.dart';
import 'memo_edit_screen.dart';
import 'quick_sort_screen.dart';
import 'todo_lists_screen.dart';

/// ホーム画面（Swift版レイアウト準拠）
/// 上: メモ入力エリア常駐
/// 中: 機能バー + 親タグタブ + 子タグドロワー
/// 下: メモグリッド + ボトムバー
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // タブ: 0=すべて, 1=タグなし, 2+=親タグ
  int _selectedTabIndex = 0;
  // 子タグドロワー
  bool _childDrawerOpen = false;
  String? _selectedChildTagId;
  // グリッドサイズ: 2 or 3列
  int _gridColumns = 2;
  // 入力エリア用
  String? _editingMemoId;

  @override
  Widget build(BuildContext context) {
    final parentTagsAsync = ref.watch(parentTagsProvider);
    final parentTags = parentTagsAsync.valueOrNull ?? const <Tag>[];
    final currentColor = _currentTabColor(parentTags);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // キーボードでオーバーフローしないように
      body: Padding(
        // SafeAreaを使わず手動で上部パディング制御
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).viewPadding.top - 4,
          bottom: MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          children: [
            // 1. 検索バー
            _buildSearchBar(),
            // 2. メモ入力エリア（常駐）
            MemoInputArea(
              editingMemoId: _editingMemoId,
              onMemoCreated: (id) => setState(() => _editingMemoId = id),
              onClosed: () => setState(() => _editingMemoId = null),
              selectedParentTagId: _currentParentTagId(parentTags),
              selectedChildTagId: _selectedChildTagId,
            ),
            // 3. 機能バー（爆速・ToDo・ドロワーハンドル）
            _buildFunctionBar(),
            // 4. 親タグタブ
            parentTagsAsync.when(
              data: (tags) => _buildTabBar(tags),
              loading: () => const SizedBox(height: 40),
              error: (_, _) => const SizedBox(height: 40),
            ),
            // 5〜8. フォルダ本体（タブと一体化したカラー領域）
            // 下部ボタン類（ゴミ箱・上へ移動・メモ作成・グリッド数）はフォルダ内フロート
            Expanded(
              child: Container(
                color: currentColor,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        if (_childDrawerOpen)
                          _buildChildTagDrawer(parentTags),
                        _buildCountBar(parentTags),
                        Expanded(
                          child: parentTagsAsync.when(
                            data: (tags) => _buildMemoGrid(tags),
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('エラー: $e')),
                          ),
                        ),
                      ],
                    ),
                    // フロートする下部ボタン群
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: _buildFloatingBottomBar(parentTags),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _currentParentTagId(List<Tag> parentTags) {
    if (_selectedTabIndex < 2) return null;
    final idx = _selectedTabIndex - 2;
    if (idx >= parentTags.length) return null;
    return parentTags[idx].id;
  }

  /// 現在選択中タブの色（フォルダ背景用）
  Color _currentTabColor(List<Tag> parentTags) {
    if (_selectedTabIndex == 0) return TagColors.allTabColor;
    if (_selectedTabIndex == 1) return TagColors.palette[0];
    final idx = _selectedTabIndex - 2;
    if (idx >= parentTags.length) return TagColors.palette[0];
    return TagColors.getColor(parentTags[idx].colorIndex);
  }

  // ========================================
  // 1. 検索バー
  // ========================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
      child: Row(
        children: [
          // ＋ボタン（小さめ、線太め）
          GestureDetector(
            onTap: _createNewMemo,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF007AFF), width: 1.5),
              ),
              child: const Icon(Icons.add, size: 14, color: Color(0xFF007AFF)),
            ),
          ),
          const Spacer(),
          // 検索バー（中央配置、固定幅、角丸控えめ）
          Container(
            width: 180,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text('メモを探す',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
          const Spacer(),
          // 設定ギア（線画細め、サイズ統一）
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.settings_outlined,
                size: 22, color: Color(0xFF007AFF)),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 3. 機能バー
  // ========================================
  Widget _buildFunctionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // 爆速モード
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuickSortScreen()),
            ),
            child: const Icon(Icons.bolt, size: 22, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          // ToDoリスト
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TodoListsScreen()),
            ),
            child: const Icon(Icons.checklist, size: 22, color: Colors.green),
          ),
          const Spacer(),
          // ドロワーハンドル（上下のシェブロン）
          const Icon(Icons.expand_less, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  // ========================================
  // 4. 親タグタブ
  // ========================================
  Widget _buildTabBar(List<Tag> parentTags) {
    final maxIndex = 1 + parentTags.length;
    if (_selectedTabIndex > maxIndex) _selectedTabIndex = 0;

    // タブの底辺がフォルダ本体の上端と完璧に一致するように、
    // crossAxisAlignment.end で下端揃え
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildTab(
              label: 'すべて',
              color: TagColors.allTabColor,
              isSelected: _selectedTabIndex == 0,
              onTap: () => setState(() {
                _selectedTabIndex = 0;
                _childDrawerOpen = false;
                _selectedChildTagId = null;
              }),
            ),
            _buildTab(
              label: 'タグなし',
              color: TagColors.palette[0],
              isSelected: _selectedTabIndex == 1,
              onTap: () => setState(() {
                _selectedTabIndex = 1;
                _childDrawerOpen = false;
                _selectedChildTagId = null;
              }),
            ),
            for (int i = 0; i < parentTags.length; i++)
              _buildTab(
                label: parentTags[i].name,
                color: TagColors.getColor(parentTags[i].colorIndex),
                isSelected: _selectedTabIndex == i + 2,
                onTap: () => setState(() {
                  _selectedTabIndex = i + 2;
                  _selectedChildTagId = null;
                }),
                onLongPress: () => _showTagActions(parentTags[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    // タグ名を最大5文字に
    final displayLabel =
        label.length > 5 ? '${label.substring(0, 5)}...' : label;

    // 選択中は不透明、非選択は薄め
    final bgColor = isSelected ? color : color.withValues(alpha: 0.55);

    final tab = CustomPaint(
      painter: TrapezoidTabPainter(
        color: bgColor,
        shadows: isSelected
            ? [
                const Shadow(
                  color: Color(0x4D000000), // black 0.3
                  offset: Offset(-3, 3),
                  blurRadius: 4,
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          displayLabel,
          // 行高1.0で詰める＋strutで余分な leading を削除
          strutStyle: const StrutStyle(
            fontSize: 14,
            height: 1.0,
            forceStrutHeight: true,
            leading: 0,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          style: TextStyle(
            fontSize: 14,
            height: 1.0,
            leadingDistribution: TextLeadingDistribution.even,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.black54,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        // 1.08倍スケール（下端基点）
        child: Transform.scale(
          scale: isSelected ? 1.08 : 1.0,
          alignment: Alignment.bottomCenter,
          child: tab,
        ),
      ),
    );
  }

  // ========================================
  // 5. 子タグドロワー
  // ========================================
  Widget _buildChildTagDrawer(List<Tag> parentTags) {
    final parentId = _currentParentTagId(parentTags);
    if (parentId == null) return const SizedBox();

    final childTagsAsync = ref.watch(childTagsProvider(parentId));

    return childTagsAsync.when(
      data: (children) {
        if (children.isEmpty) return const SizedBox();
        return Container(
          height: 36,
          color: Colors.grey[100],
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // ▶ 閉じるボタン
              GestureDetector(
                onTap: () =>
                    setState(() => _childDrawerOpen = false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(Icons.play_arrow, size: 16, color: Colors.grey),
                ),
              ),
              // 「すべて」子タグフィルター解除
              _buildChildTab('すべて', null, children),
              // 子タグ
              for (final child in children)
                _buildChildTab(child.name, child.id, children,
                    color: TagColors.getColor(child.colorIndex)),
              // 子タグ追加ボタン
              GestureDetector(
                onTap: () => _addChildTag(parentId),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 36),
      error: (_, _) => const SizedBox(),
    );
  }

  Widget _buildChildTab(String label, String? childId, List<Tag> children,
      {Color? color}) {
    final isSelected = _selectedChildTagId == childId;
    return GestureDetector(
      onTap: () => setState(() => _selectedChildTagId = childId),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Colors.white)
              : (color?.withValues(alpha: 0.3) ?? Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.blueAccent, width: 1.5)
              : Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  // ========================================
  // 6. 件数バー
  // ========================================
  Widget _buildCountBar(List<Tag> parentTags) {
    final parentId = _currentParentTagId(parentTags);
    final hasChildren = parentId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          // 件数はStreamで取得（簡易表示）
          _MemoCountText(
            tabIndex: _selectedTabIndex,
            parentTags: parentTags,
            childTagId: _selectedChildTagId,
          ),
          const Spacer(),
          // 子タグドロワートグル
          if (hasChildren)
            GestureDetector(
              onTap: () =>
                  setState(() => _childDrawerOpen = !_childDrawerOpen),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _childDrawerOpen
                          ? Icons.arrow_left
                          : Icons.arrow_right,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    Text('子タグ',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================
  // 7. メモグリッド
  // ========================================
  Widget _buildMemoGrid(List<Tag> parentTags) {
    if (_selectedTabIndex == 0) {
      return _MemoGridView(
        stream: ref.watch(allMemosProvider),
        gridColumns: _gridColumns,
        onTap: _openMemo,
        onLongPress: (m) => _showMemoActions(m),
      );
    } else if (_selectedTabIndex == 1) {
      return _MemoGridView(
        stream: ref.watch(untaggedMemosProvider),
        gridColumns: _gridColumns,
        onTap: _openMemo,
        onLongPress: (m) => _showMemoActions(m),
      );
    } else {
      final parentId = _currentParentTagId(parentTags);
      if (parentId == null) return const SizedBox();
      // 子タグフィルタリング
      final tagId = _selectedChildTagId ?? parentId;
      return _MemoGridView(
        stream: ref.watch(memosForTagProvider(tagId)),
        gridColumns: _gridColumns,
        onTap: _openMemo,
        onLongPress: (m) => _showMemoActions(m),
      );
    }
  }

  // ========================================
  // 8. フォルダ内フロート ボトムバー
  // ========================================
  Widget _buildFloatingBottomBar(List<Tag> parentTags) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 左: 選択削除・移動
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36),
            color: Colors.grey[600],
          ),
          IconButton(
            icon: const Icon(Icons.vertical_align_top, size: 20),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36),
            color: Colors.grey[600],
          ),
          const Spacer(),
          // 中央: このフォルダにメモ作成
          GestureDetector(
            onTap: () => _createMemoInFolder(parentTags),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 16, color: Colors.blueAccent),
                  SizedBox(width: 4),
                  Text('このフォルダに\nメモ作成',
                      style: TextStyle(
                          fontSize: 11, color: Colors.blueAccent),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          const Spacer(),
          // 右: グリッドサイズ切替
          GestureDetector(
            onTap: () => setState(() {
              _gridColumns = _gridColumns == 2 ? 3 : (_gridColumns == 3 ? 1 : 2);
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _gridColumns == 1
                    ? '1列'
                    : '$_gridColumns×${_gridColumns + 1}',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // アクション
  // ========================================

  Future<void> _createNewMemo() async {
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo();
    setState(() => _editingMemoId = memo.id);
  }

  Future<void> _createMemoInFolder(List<Tag> parentTags) async {
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo();
    // 現在のタブのタグを自動付与
    final parentId = _currentParentTagId(parentTags);
    if (parentId != null) {
      await db.addTagToMemo(memo.id, parentId);
    }
    if (_selectedChildTagId != null) {
      await db.addTagToMemo(memo.id, _selectedChildTagId!);
    }
    setState(() => _editingMemoId = memo.id);
  }

  void _openMemo(Memo memo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(memoId: memo.id),
      ),
    );
  }

  void _showTagActions(Tag tag) {
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
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('編集'),
              onTap: () {
                Navigator.pop(context);
                _editTag(tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right),
              title: const Text('子タグを追加'),
              onTap: () {
                Navigator.pop(context);
                _addChildTag(tag.id);
              },
            ),
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

  Future<void> _addChildTag(String parentId) async {
    final result = await showDialog<TagEditResult>(
      context: context,
      builder: (_) => TagEditDialog(parentTagId: parentId),
    );
    if (result != null) {
      final db = ref.read(databaseProvider);
      await db.createTag(
        name: result.name,
        colorIndex: result.colorIndex,
        parentTagId: parentId,
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
                      ref.read(databaseProvider).deleteTag(tag.id);
                      Navigator.pop(context);
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

  void _showMemoActions(Memo memo) {
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
                if (!memo.isLocked) {
                  db.deleteMemo(memo.id);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ========================================
// メモ件数テキスト
// ========================================
class _MemoCountText extends ConsumerWidget {
  final int tabIndex;
  final List<Tag> parentTags;
  final String? childTagId;

  const _MemoCountText({
    required this.tabIndex,
    required this.parentTags,
    this.childTagId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<Memo>> memosAsync;
    if (tabIndex == 0) {
      memosAsync = ref.watch(allMemosProvider);
    } else if (tabIndex == 1) {
      memosAsync = ref.watch(untaggedMemosProvider);
    } else {
      final idx = tabIndex - 2;
      if (idx >= parentTags.length) return const SizedBox();
      final tagId = childTagId ?? parentTags[idx].id;
      memosAsync = ref.watch(memosForTagProvider(tagId));
    }

    return memosAsync.when(
      data: (memos) => Text(
        '${memos.length}件',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      loading: () => const SizedBox(),
      error: (_, _) => const SizedBox(),
    );
  }
}

// ========================================
// メモグリッドビュー（共通）
// ========================================
class _MemoGridView extends StatelessWidget {
  final AsyncValue<List<Memo>> stream;
  final int gridColumns;
  final void Function(Memo) onTap;
  final void Function(Memo) onLongPress;

  const _MemoGridView({
    required this.stream,
    required this.gridColumns,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return stream.when(
      data: (memos) => memos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_add_outlined,
                      size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('メモがありません',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey[500])),
                ],
              ),
            )
          : Padding(
              // 下端はフロートボタン分の余白
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 56),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: gridColumns == 1 ? 3.0 : 1.0,
                ),
                itemCount: memos.length,
                itemBuilder: (_, index) {
                  final memo = memos[index];
                  return MemoCard(
                    memo: memo,
                    onTap: () => onTap(memo),
                    onLongPress: () => onLongPress(memo),
                  );
                },
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
    );
  }
}
