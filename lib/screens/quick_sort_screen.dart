import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/keyboard_done_bar.dart';
import '../utils/text_menu_dismisser.dart';

// ========================================
// 爆速モード（QuickSort）
// フロー: フィルター選択 → カルーセル処理 → 結果サマリー
// ========================================

/// 爆速モードのエントリポイント
class QuickSortScreen extends ConsumerStatefulWidget {
  const QuickSortScreen({super.key});

  @override
  ConsumerState<QuickSortScreen> createState() => _QuickSortScreenState();
}

class _QuickSortScreenState extends ConsumerState<QuickSortScreen> {
  // フェーズ管理
  _Phase _phase = _Phase.intro;

  // 処理対象メモ
  List<Memo> _allFilteredMemos = [];
  List<Memo> _activeMemos = [];
  int _currentSetIndex = 0;
  int _currentCardIndex = 0;
  static const int _setSize = 50;

  // 操作追跡
  final Set<String> _taggedMemoIds = {};
  final Set<String> _titledMemoIds = {};
  final Set<String> _editedMemoIds = {};
  final List<String> _deleteQueue = [];

  int get _totalSets =>
      (_allFilteredMemos.length + _setSize - 1) ~/ _setSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      body: KeyboardDoneBar(child: switch (_phase) {
        _Phase.intro => _QuickSortIntro(
          onNext: () => setState(() => _phase = _Phase.filter),
          onCancel: () => Navigator.of(context).pop(),
        ),
        _Phase.filter => _QuickSortFilterPhase(
          onStart: (memos) {
            setState(() {
              _allFilteredMemos = memos;
              _currentSetIndex = 0;
              _loadCurrentSet();
              _phase = _Phase.carousel;
            });
          },
          onBack: () => setState(() => _phase = _Phase.intro),
          onCancel: () => Navigator.of(context).pop(),
        ),
        _Phase.carousel => _buildCarouselPhase(),
        _Phase.result => _buildResultPhase(),
      }),
    );
  }

  void _loadCurrentSet() {
    final start = _currentSetIndex * _setSize;
    final end = (start + _setSize).clamp(0, _allFilteredMemos.length);
    _activeMemos = _allFilteredMemos.sublist(start, end);
    _currentCardIndex = 0;
  }

  // ========================================
  // Phase 2: カルーセル処理
  // ========================================
  Widget _buildCarouselPhase() {
    if (_activeMemos.isEmpty) {
      return const Center(child: Text('メモがありません'));
    }

    final memo = _activeMemos[_currentCardIndex];
    final progress =
        '${_currentCardIndex + 1} / ${_activeMemos.length}';
    final setInfo = _totalSets > 1
        ? '  (セット ${_currentSetIndex + 1}/$_totalSets)'
        : '';

    return Column(
      children: [
        // プログレスバー
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text('$progress$setInfo',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const Spacer(),
              // 完了ボタン
              TextButton(
                onPressed: _finishCurrentSet,
                child: const Text('完了'),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (_currentCardIndex + 1) / _activeMemos.length,
          backgroundColor: Colors.grey[200],
          valueColor:
              const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
        ),

        // メモカード
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _QuickSortCard(
              memo: memo,
              onTagged: () => _taggedMemoIds.add(memo.id),
              onTitled: () => _titledMemoIds.add(memo.id),
              onEdited: () => _editedMemoIds.add(memo.id),
            ),
          ),
        ),

        // ナビゲーションバー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 前へ
              IconButton(
                onPressed:
                    _currentCardIndex > 0 ? _prevCard : null,
                icon: const Icon(Icons.arrow_back_ios),
              ),
              // 削除
              IconButton(
                onPressed: () => _deleteCurrent(memo),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                iconSize: 28,
              ),
              // 次へ
              IconButton(
                onPressed: _currentCardIndex < _activeMemos.length - 1
                    ? _nextCard
                    : null,
                icon: const Icon(Icons.arrow_forward_ios),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _prevCard() => setState(() => _currentCardIndex--);

  void _nextCard() => setState(() => _currentCardIndex++);

  void _deleteCurrent(Memo memo) {
    if (memo.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ロックされているメモは削除できません')),
      );
      return;
    }
    setState(() {
      _deleteQueue.add(memo.id);
      _activeMemos.removeAt(_currentCardIndex);
      if (_currentCardIndex >= _activeMemos.length) {
        _currentCardIndex =
            (_activeMemos.length - 1).clamp(0, _activeMemos.length);
      }
      if (_activeMemos.isEmpty) {
        _finishCurrentSet();
      }
    });
  }

  void _finishCurrentSet() {
    // 削除キューを実行
    final db = ref.read(databaseProvider);
    for (final id in _deleteQueue) {
      db.deleteMemo(id);
    }

    setState(() {
      _phase = _Phase.result;
    });
  }

  // ========================================
  // Phase 3: 結果サマリー
  // ========================================
  Widget _buildResultPhase() {
    final hasNextSet = _currentSetIndex + 1 < _totalSets;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.check_circle_outline,
              size: 72, color: Colors.green),
          const SizedBox(height: 16),
          const Text('整理完了！',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),

          // 結果カウンター
          _resultCounter(Icons.label, 'タグ付け', _taggedMemoIds.length),
          _resultCounter(Icons.title, 'タイトル追加', _titledMemoIds.length),
          _resultCounter(Icons.edit, '内容編集', _editedMemoIds.length),
          _resultCounter(
              Icons.delete, '削除', _deleteQueue.length,
              color: Colors.red),

          const Spacer(),

          if (hasNextSet)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentSetIndex++;
                    _loadCurrentSet();
                    _taggedMemoIds.clear();
                    _titledMemoIds.clear();
                    _editedMemoIds.clear();
                    _deleteQueue.clear();
                    _phase = _Phase.carousel;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                    '次のセットへ (${_currentSetIndex + 2}/$_totalSets)'),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ホームに戻る'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCounter(IconData icon, String label, int count,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.blueAccent),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text('$count件',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color ?? Colors.blueAccent)),
        ],
      ),
    );
  }
}

// ========================================
// カルーセル内のメモカード
// ========================================
class _QuickSortCard extends ConsumerStatefulWidget {
  final Memo memo;
  final VoidCallback onTagged;
  final VoidCallback onTitled;
  final VoidCallback onEdited;

  const _QuickSortCard({
    required this.memo,
    required this.onTagged,
    required this.onTitled,
    required this.onEdited,
  });

  @override
  ConsumerState<_QuickSortCard> createState() => _QuickSortCardState();
}

class _QuickSortCardState extends ConsumerState<_QuickSortCard> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<Tag> _memoTags = [];
  bool _isEditingTitle = false;
  bool _isEditingContent = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo.title);
    _contentController = TextEditingController(text: widget.memo.content);
    _loadTags();
  }

  @override
  void didUpdateWidget(covariant _QuickSortCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memo.id != widget.memo.id) {
      _titleController.text = widget.memo.title;
      _contentController.text = widget.memo.content;
      _isEditingTitle = false;
      _isEditingContent = false;
      _loadTags();
    }
  }

  Future<void> _loadTags() async {
    final db = ref.read(databaseProvider);
    final tags = await db.getTagsForMemo(widget.memo.id);
    if (mounted) setState(() => _memoTags = tags);
  }

  void _saveTitle() {
    final db = ref.read(databaseProvider);
    db.updateMemo(id: widget.memo.id, title: _titleController.text);
    if (_titleController.text.trim().isNotEmpty) widget.onTitled();
    setState(() => _isEditingTitle = false);
  }

  void _saveContent() {
    final db = ref.read(databaseProvider);
    db.updateMemo(id: widget.memo.id, content: _contentController.text);
    widget.onEdited();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CornerRadius.card),
        boxShadow: [AppShadows.medium()],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ステータスアイコン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                if (widget.memo.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child:
                        Icon(Icons.push_pin, size: 16, color: Colors.orange),
                  ),
                if (widget.memo.isLocked)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock, size: 16, color: Colors.red),
                  ),
                if (widget.memo.isMarkdown)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('MD',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple)),
                  ),
                const Spacer(),
                // タグ付けボタン
                IconButton(
                  icon: const Icon(Icons.label_outline, size: 20),
                  onPressed: () => _showTagPicker(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // タイトル
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isEditingTitle
                ? TextField(
                    controller: _titleController,
                    autofocus: true,
                    onTap: TextMenuDismisser.wrap(null),
                    contextMenuBuilder: TextMenuDismisser.builder,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'タイトルを入力',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveTitle(),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _isEditingTitle = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _titleController.text.isEmpty
                            ? 'タイトルなし'
                            : _titleController.text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _titleController.text.isEmpty
                              ? Colors.grey
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),

          const Divider(height: 1),

          // 本文
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isEditingContent
                  ? TextField(
                      controller: _contentController,
                      autofocus: true,
                      onTap: TextMenuDismisser.wrap(null),
                      contextMenuBuilder: TextMenuDismisser.builder,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'メモを入力...',
                      ),
                      onChanged: (_) => _saveContent(),
                    )
                  : GestureDetector(
                      onTap: () =>
                          setState(() => _isEditingContent = true),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _contentController.text.isEmpty
                              ? '（内容なし）'
                              : _contentController.text,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _contentController.text.isEmpty
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // タグ表示
          if (_memoTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                children: _memoTags
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: TagColors.getColor(tag.colorIndex),
                            borderRadius: BorderRadius.circular(
                                CornerRadius.childTag),
                          ),
                          child: Text(tag.name,
                              style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showTagPicker(BuildContext context) {
    FocusScope.of(context).unfocus();
    final allTagsAsync = ref.read(allTagsProvider);
    final currentIds = _memoTags.map((t) => t.id).toSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CornerRadius.dialog),
            ),
            child: allTagsAsync.when(
              data: (allTags) => ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('タグを選択',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ...allTags.map((tag) {
                    final selected = currentIds.contains(tag.id);
                    return ListTile(
                      leading: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: TagColors.getColor(tag.colorIndex),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(tag.name),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: Colors.blueAccent)
                          : const Icon(Icons.circle_outlined,
                              color: Colors.grey),
                      contentPadding: EdgeInsets.only(
                          left: tag.parentTagId != null ? 40 : 16,
                          right: 16),
                      onTap: () async {
                        final db = ref.read(databaseProvider);
                        if (selected) {
                          await db.removeTagFromMemo(
                              widget.memo.id, tag.id);
                          currentIds.remove(tag.id);
                        } else {
                          await db.addTagToMemo(
                              widget.memo.id, tag.id);
                          currentIds.add(tag.id);
                          widget.onTagged();
                        }
                        _loadTags();
                        setSheetState(() {});
                      },
                    );
                  }),
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('エラー')),
            ),
          );
        });
      },
    );
  }
}

// ========================================
// フィルター選択画面（Swift版準拠）
// 複数条件OR選択、件数表示、タグ展開
// ========================================
class _QuickSortFilterPhase extends ConsumerStatefulWidget {
  final void Function(List<Memo> memos) onStart;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  const _QuickSortFilterPhase({
    required this.onStart,
    required this.onBack,
    required this.onCancel,
  });

  @override
  ConsumerState<_QuickSortFilterPhase> createState() =>
      _QuickSortFilterPhaseState();
}

class _QuickSortFilterPhaseState
    extends ConsumerState<_QuickSortFilterPhase> {
  // フィルタ条件（複数選択可）
  bool _filterNoTag = false;
  bool _filterNoTitle = false;
  bool _filterOld = false;
  bool _filterAll = false;
  bool _filterByTag = false;
  final Set<String> _selectedTagIds = {};

  // メモ・タグキャッシュ
  List<Memo> _allMemos = [];
  List<Tag> _parentTags = [];
  Set<String> _taggedMemoIds = {};
  // タグID → メモIDの逆引きマップ
  Map<String, Set<String>> _tagToMemoIds = {};
  bool _loaded = false;

  DateTime get _threeMonthsAgo =>
      DateTime.now().subtract(const Duration(days: 90));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final memos = await db.select(db.memos).get();
    final tags = await db.select(db.tags).get();
    final memoTags = await db.select(db.memoTags).get();
    // タグ→メモの逆引きマップを構築
    final tagMap = <String, Set<String>>{};
    for (final mt in memoTags) {
      tagMap.putIfAbsent(mt.tagId, () => {}).add(mt.memoId);
    }
    if (!mounted) return;
    setState(() {
      _allMemos = memos;
      _parentTags = tags.where((t) => t.parentTagId == null).toList();
      _taggedMemoIds = memoTags.map((mt) => mt.memoId).toSet();
      _tagToMemoIds = tagMap;
      _loaded = true;
    });
  }

  // フィルタ適用後のメモリスト
  List<Memo> get _filteredMemos {
    if (!_loaded) return [];
    if (_filterAll) {
      return _sortedMemos(_allMemos);
    }
    final result = <String>{};
    for (final memo in _allMemos) {
      if (_filterNoTag && !_taggedMemoIds.contains(memo.id)) {
        result.add(memo.id);
      }
      if (_filterNoTitle && memo.title.trim().isEmpty) {
        result.add(memo.id);
      }
      if (_filterOld) {
        final lastAccess = memo.lastViewedAt ?? memo.updatedAt;
        if (lastAccess.isBefore(_threeMonthsAgo)) {
          result.add(memo.id);
        }
      }
      if (_filterByTag && _selectedTagIds.isNotEmpty) {
        // キャッシュ済みの逆引きマップで判定
        for (final tagId in _selectedTagIds) {
          final memoIds = _tagToMemoIds[tagId];
          if (memoIds != null && memoIds.contains(memo.id)) {
            result.add(memo.id);
            break;
          }
        }
      }
    }
    return _sortedMemos(
        _allMemos.where((m) => result.contains(m.id)).toList());
  }

  List<Memo> _sortedMemos(List<Memo> memos) {
    final sorted = List<Memo>.from(memos);
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.manualSortOrder != b.manualSortOrder) {
        return b.manualSortOrder.compareTo(a.manualSortOrder);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int get _filteredCount => _filteredMemos.length;

  // 各フィルタ条件の件数
  int get _noTagCount =>
      _allMemos.where((m) => !_taggedMemoIds.contains(m.id)).length;
  int get _noTitleCount =>
      _allMemos.where((m) => m.title.trim().isEmpty).length;
  int get _tagFilteredCount {
    final memoIds = <String>{};
    for (final tagId in _selectedTagIds) {
      final ids = _tagToMemoIds[tagId];
      if (ids != null) memoIds.addAll(ids);
    }
    return memoIds.length;
  }

  int get _oldCount => _allMemos.where((m) {
        final lastAccess = m.lastViewedAt ?? m.updatedAt;
        return lastAccess.isBefore(_threeMonthsAgo);
      }).length;

  // 排他制御: 「すべて」を選ぶと他OFF
  void _toggleFilter(String key) {
    setState(() {
      switch (key) {
        case 'noTag':
          _filterNoTag = !_filterNoTag;
          if (_filterNoTag) _filterAll = false;
        case 'noTitle':
          _filterNoTitle = !_filterNoTitle;
          if (_filterNoTitle) _filterAll = false;
        case 'old':
          _filterOld = !_filterOld;
          if (_filterOld) _filterAll = false;
        case 'byTag':
          _filterByTag = !_filterByTag;
          if (_filterByTag) {
            _filterAll = false;
          } else {
            _selectedTagIds.clear();
          }
        case 'all':
          _filterAll = !_filterAll;
          if (_filterAll) {
            _filterNoTag = false;
            _filterNoTitle = false;
            _filterOld = false;
            _filterByTag = false;
            _selectedTagIds.clear();
          }
      }
    });
  }

  bool get _anyFilterSelected =>
      _filterNoTag ||
      _filterNoTitle ||
      _filterOld ||
      _filterAll ||
      (_filterByTag && _selectedTagIds.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          // ナビバー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  label: const Text('戻る', style: TextStyle(fontSize: 16)),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('閉じる',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              ],
            ),
          ),

          // フィルタ案内ヘッダー
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('対象のメモを選んでください',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Text('複数選択可',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue)),
          const SizedBox(height: 16),

          // スクロール領域
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // フィルタ条件リスト
                  _buildFilterList(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 開始ボタン（固定フッター）
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildFilterList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // タグなし
            _buildFilterRow(
              icon: Icons.label_off,
              iconColor: Colors.orange,
              title: 'タグなしのメモ',
              count: _noTagCount,
              isOn: _filterNoTag,
              onTap: () => _toggleFilter('noTag'),
            ),
            _filterDivider(),

            // タイトルなし
            _buildFilterRow(
              icon: Icons.title,
              iconColor: Colors.blue,
              title: 'タイトルなしのメモ',
              count: _noTitleCount,
              isOn: _filterNoTitle,
              onTap: () => _toggleFilter('noTitle'),
            ),
            _filterDivider(),

            // 3ヶ月以上
            _buildFilterRow(
              icon: Icons.access_time,
              iconColor: Colors.purple,
              title: '3ヶ月以上開いていない',
              count: _oldCount,
              isOn: _filterOld,
              onTap: () => _toggleFilter('old'),
            ),
            _filterDivider(),

            // 特定のタグ
            _buildFilterRow(
              icon: Icons.label,
              iconColor: Colors.green,
              title: '特定のタグのメモ',
              count: (_filterByTag && _selectedTagIds.isNotEmpty)
                  ? _tagFilteredCount
                  : null,
              isOn: _filterByTag && _selectedTagIds.isNotEmpty,
              trailing: Icon(
                _filterByTag
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: _filterByTag ? Colors.orange : Colors.grey[400],
              ),
              onTap: () => _toggleFilter('byTag'),
            ),

            // タグ選択リスト（展開時のみ）
            if (_filterByTag) _buildTagSelection(),

            _filterDivider(),

            // すべて
            _buildFilterRow(
              icon: Icons.all_inbox,
              iconColor: Colors.grey,
              title: 'すべてのメモ',
              count: _allMemos.length,
              isOn: _filterAll,
              onTap: () => _toggleFilter('all'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int? count,
    required bool isOn,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            if (count != null) ...[
              Text('$count件',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(width: 10),
            ],
            // チェックマーク円
            Icon(
              isOn ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: isOn ? Colors.orange : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSelection() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: _parentTags.map((tag) {
          final isSelected = _selectedTagIds.contains(tag.id);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedTagIds.remove(tag.id);
                } else {
                  _selectedTagIds.add(tag.id);
                }
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 50, right: 16, top: 10, bottom: 10),
              child: Row(
                children: [
                  // タグ色丸
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: TagColors.getColor(tag.colorIndex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tag.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    '${_tagToMemoIds[tag.id]?.length ?? 0}件',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 18,
                    color: isSelected ? Colors.green : Colors.grey[300],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _filterDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }

  Widget _buildStartButton() {
    final count = _filteredCount;
    final enabled = _anyFilterSelected && count > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: enabled ? () => widget.onStart(_filteredMemos) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? Colors.orange : Colors.grey[400],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: enabled ? 2 : 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 20),
              const SizedBox(width: 8),
              Text(
                '開始（$count件）',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================
// イントロ画面（説明）
// ========================================
class _QuickSortIntro extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onCancel;

  const _QuickSortIntro({
    required this.onNext,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ナビバー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('閉じる',
                      style: TextStyle(fontSize: 16, color: Colors.blue)),
                ),
                const Spacer(),
              ],
            ),
          ),

          const Spacer(flex: 2),

          // メインコンテンツ
          const Text(
            '爆速メモ整理モード',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Icon(Icons.bolt, size: 48, color: Colors.orange),
          const SizedBox(height: 20),

          // 説明文
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  'お好みの条件で抽出したメモを連続で表示し、一気に',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // チェックリスト（中央配置＋左揃え）
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      'タイトル編集',
                      'タグ付け',
                      '本文編集',
                      'ロック（削除防止）',
                      '削除',
                    ].map((text) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_box,
                                  size: 20, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(text,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ができるモードです。',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),

          // 次へボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '次へ',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Phase { intro, filter, carousel, result }
