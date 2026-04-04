import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../widgets/markdown_toolbar.dart';

/// メモ編集画面（自動保存 + タグ付け + マークダウン対応）
class MemoEditScreen extends ConsumerStatefulWidget {
  final String memoId;

  const MemoEditScreen({super.key, required this.memoId});

  @override
  ConsumerState<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<MemoEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isLoading = true;
  bool _isMarkdown = false;
  bool _showPreview = false; // マークダウンプレビュー表示
  List<Tag> _attachedTags = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _loadMemo();
  }

  Future<void> _loadMemo() async {
    final db = ref.read(databaseProvider);
    final memo = await db.getMemoById(widget.memoId);
    if (memo != null && mounted) {
      _titleController.text = memo.title;
      _contentController.text = memo.content;
      _isMarkdown = memo.isMarkdown;
      _attachedTags = await db.getTagsForMemo(widget.memoId);
      db.incrementViewCount(widget.memoId);
      setState(() => _isLoading = false);
    }
  }

  /// 入力するたびに即座に保存（debounceなし）
  void _onChanged() {
    final db = ref.read(databaseProvider);
    db.updateMemo(
      id: widget.memoId,
      title: _titleController.text,
      content: _contentController.text,
    );
  }

  void _toggleMarkdown() {
    final db = ref.read(databaseProvider);
    setState(() {
      _isMarkdown = !_isMarkdown;
      if (!_isMarkdown) _showPreview = false;
    });
    db.updateMemo(id: widget.memoId, isMarkdown: _isMarkdown);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // マークダウンプレビュートグル（マークダウンモード時のみ）
          if (_isMarkdown)
            IconButton(
              icon: Icon(
                _showPreview ? Icons.edit : Icons.visibility,
                color: Colors.purple,
              ),
              onPressed: () => setState(() => _showPreview = !_showPreview),
              tooltip: _showPreview ? '編集' : 'プレビュー',
            ),
          // タグ付けボタン
          IconButton(
            icon: const Icon(Icons.label_outline),
            onPressed: () => _showTagSelector(context),
            tooltip: 'タグ',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActions(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 付与済みタグ表示
            if (_attachedTags.isNotEmpty) _buildAttachedTags(),
            // エディタ or プレビュー
            Expanded(
              child: _showPreview
                  ? _buildMarkdownPreview()
                  : _buildEditor(),
            ),
            // マークダウンツールバー（マークダウンモード＆編集中のみ）
            if (_isMarkdown && !_showPreview)
              MarkdownToolbar(
                controller: _contentController,
                onChanged: _onChanged,
              ),
          ],
        ),
      ),
    );
  }

  /// 通常エディタ
  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            onChanged: (_) => _onChanged(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              hintText: 'タイトル',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
            maxLines: 1,
          ),
          const Divider(height: 1),
          Expanded(
            child: TextField(
              controller: _contentController,
              onChanged: (_) => _onChanged(),
              style: const TextStyle(fontSize: 16, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'メモを入力...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ],
      ),
    );
  }

  /// マークダウンプレビュー
  Widget _buildMarkdownPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル（読み取り専用）
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _titleController.text.isEmpty
                  ? 'タイトルなし'
                  : _titleController.text,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _titleController.text.isEmpty
                    ? Colors.grey
                    : Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          // マークダウンプレビュー
          Expanded(
            child: Markdown(
              data: _contentController.text,
              selectable: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                p: const TextStyle(fontSize: 16, height: 1.6),
                code: TextStyle(
                  backgroundColor: Colors.grey[100],
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey[400]!, width: 3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 付与済みタグのチップ表示
  Widget _buildAttachedTags() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: _attachedTags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: TagColors.getColor(tag.colorIndex),
              borderRadius: BorderRadius.circular(CornerRadius.childTag),
              boxShadow: [AppShadows.light()],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tag.name,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _removeTag(tag),
                  child: const Icon(Icons.close,
                      size: 14, color: Colors.black54),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showTagSelector(BuildContext context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TagSelectorSheet(
        memoId: widget.memoId,
        attachedTags: _attachedTags,
        onChanged: (updatedTags) {
          setState(() => _attachedTags = updatedTags);
        },
      ),
    );
  }

  Future<void> _removeTag(Tag tag) async {
    final db = ref.read(databaseProvider);
    await db.removeTagFromMemo(widget.memoId, tag.id);
    setState(() => _attachedTags.removeWhere((t) => t.id == tag.id));
  }

  void _showActions(BuildContext context) {
    FocusScope.of(context).unfocus();
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
            // マークダウン切替
            ListTile(
              leading: Icon(
                Icons.code,
                color: _isMarkdown ? Colors.purple : null,
              ),
              title: Text(_isMarkdown ? 'マークダウンOFF' : 'マークダウンON'),
              onTap: () {
                Navigator.pop(context);
                _toggleMarkdown();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('共有'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// タグ選択シート
class _TagSelectorSheet extends ConsumerStatefulWidget {
  final String memoId;
  final List<Tag> attachedTags;
  final void Function(List<Tag>) onChanged;

  const _TagSelectorSheet({
    required this.memoId,
    required this.attachedTags,
    required this.onChanged,
  });

  @override
  ConsumerState<_TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends ConsumerState<_TagSelectorSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.attachedTags.map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
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
                const Text('タグを選択',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完了'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: allTagsAsync.when(
              data: (allTags) => allTags.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('タグがありません',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: allTags.length,
                      itemBuilder: (context, index) {
                        final tag = allTags[index];
                        final isSelected = _selectedIds.contains(tag.id);
                        final isChild = tag.parentTagId != null;
                        return ListTile(
                          contentPadding: EdgeInsets.only(
                            left: isChild ? 40 : 16,
                            right: 16,
                          ),
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: TagColors.getColor(tag.colorIndex),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(tag.name),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.blueAccent)
                              : const Icon(Icons.circle_outlined,
                                  color: Colors.grey),
                          onTap: () => _toggle(tag),
                        );
                      },
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(Tag tag) async {
    final db = ref.read(databaseProvider);
    if (_selectedIds.contains(tag.id)) {
      await db.removeTagFromMemo(widget.memoId, tag.id);
      _selectedIds.remove(tag.id);
    } else {
      await db.addTagToMemo(widget.memoId, tag.id);
      _selectedIds.add(tag.id);
    }
    final updatedTags = await db.getTagsForMemo(widget.memoId);
    widget.onChanged(updatedTags);
    setState(() {});
  }
}
