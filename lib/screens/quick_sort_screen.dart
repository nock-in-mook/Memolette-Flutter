import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';

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
  _Phase _phase = _Phase.filter;

  // フィルター設定
  _FilterType _filterType = _FilterType.noTag;
  final Set<String> _selectedTagIds = {};

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
      appBar: AppBar(
        title: const Text('爆速メモ整理'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: switch (_phase) {
        _Phase.filter => _buildFilterPhase(),
        _Phase.carousel => _buildCarouselPhase(),
        _Phase.result => _buildResultPhase(),
      },
    );
  }

  // ========================================
  // Phase 1: フィルター選択
  // ========================================
  Widget _buildFilterPhase() {
    final parentTagsAsync = ref.watch(parentTagsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('整理するメモを選択',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // フィルターオプション
          _filterOption('タグなしメモ', _FilterType.noTag, Icons.label_off),
          _filterOption('タイトルなしメモ', _FilterType.noTitle, Icons.title),
          _filterOption(
              '3ヶ月以上見ていないメモ', _FilterType.old, Icons.history),
          _filterOption('すべてのメモ', _FilterType.all, Icons.select_all),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text('タグで絞り込み',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),

          // 親タグ選択
          parentTagsAsync.when(
            data: (tags) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final selected = _selectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.name),
                  selected: selected,
                  selectedColor: TagColors.getColor(tag.colorIndex),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _filterType = _FilterType.byTag;
                        _selectedTagIds.add(tag.id);
                      } else {
                        _selectedTagIds.remove(tag.id);
                        if (_selectedTagIds.isEmpty) {
                          _filterType = _FilterType.noTag;
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => const Text('タグ取得エラー'),
          ),

          const Spacer(),

          // 開始ボタン
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _startSort,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CornerRadius.button)),
              ),
              child: const Text('整理を開始', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterOption(String label, _FilterType type, IconData icon) {
    final selected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _filterType = type;
          if (type != _FilterType.byTag) _selectedTagIds.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(CornerRadius.button),
            border: Border.all(
              color: selected ? Colors.blueAccent : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? Colors.blueAccent : Colors.grey),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                    color: selected ? Colors.blueAccent : Colors.black87,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSort() async {
    final db = ref.read(databaseProvider);
    List<Memo> filtered;

    switch (_filterType) {
      case _FilterType.noTag:
        // タグなしメモ
        final allMemos = await db.select(db.memos).get();
        final taggedIds = (await db.select(db.memoTags).get())
            .map((mt) => mt.memoId)
            .toSet();
        filtered = allMemos.where((m) => !taggedIds.contains(m.id)).toList();
        break;
      case _FilterType.noTitle:
        final allMemos = await db.select(db.memos).get();
        filtered = allMemos.where((m) => m.title.trim().isEmpty).toList();
        break;
      case _FilterType.old:
        final threshold =
            DateTime.now().subtract(const Duration(days: 90));
        final allMemos = await db.select(db.memos).get();
        filtered = allMemos.where((m) {
          final lastSeen = m.lastViewedAt ?? m.updatedAt;
          return lastSeen.isBefore(threshold);
        }).toList();
        break;
      case _FilterType.all:
        filtered = await db.select(db.memos).get();
        break;
      case _FilterType.byTag:
        final Set<String> memoIds = {};
        for (final tagId in _selectedTagIds) {
          final rows = await (db.select(db.memoTags)
                ..where((t) => t.tagId.equals(tagId)))
              .get();
          memoIds.addAll(rows.map((r) => r.memoId));
        }
        final allMemos = await db.select(db.memos).get();
        filtered = allMemos.where((m) => memoIds.contains(m.id)).toList();
        break;
    }

    // ソート: ピン留め → 作成日時降順
    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('対象のメモがありません')),
        );
      }
      return;
    }

    setState(() {
      _allFilteredMemos = filtered;
      _currentSetIndex = 0;
      _loadCurrentSet();
      _phase = _Phase.carousel;
    });
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

enum _Phase { filter, carousel, result }

enum _FilterType { noTag, noTitle, old, all, byTag }
