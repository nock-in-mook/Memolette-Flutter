import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';

/// メモ入力エリア（ホーム画面上部に常駐）
/// Swift版の MemoInputView に対応
class MemoInputArea extends ConsumerStatefulWidget {
  final String? editingMemoId;
  final void Function(String id) onMemoCreated;
  final VoidCallback onClosed;
  final String? selectedParentTagId;
  final String? selectedChildTagId;

  const MemoInputArea({
    super.key,
    this.editingMemoId,
    required this.onMemoCreated,
    required this.onClosed,
    this.selectedParentTagId,
    this.selectedChildTagId,
  });

  @override
  ConsumerState<MemoInputArea> createState() => _MemoInputAreaState();
}

class _MemoInputAreaState extends ConsumerState<MemoInputArea> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  List<Tag> _attachedTags = [];
  bool _hasMemo = false;

  @override
  void didUpdateWidget(covariant MemoInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMemoId != oldWidget.editingMemoId) {
      if (widget.editingMemoId != null) {
        _loadMemo(widget.editingMemoId!);
      } else {
        _clearInput();
      }
    }
  }

  Future<void> _loadMemo(String id) async {
    final db = ref.read(databaseProvider);
    final memo = await db.getMemoById(id);
    if (memo != null && mounted) {
      _titleController.text = memo.title;
      _contentController.text = memo.content;
      _attachedTags = await db.getTagsForMemo(id);
      setState(() => _hasMemo = true);
    }
  }

  void _clearInput() {
    _titleController.clear();
    _contentController.clear();
    _attachedTags = [];
    setState(() => _hasMemo = false);
  }

  /// 入力内容を即座に保存
  void _onChanged() {
    if (widget.editingMemoId == null) {
      // 新規メモ自動作成（タイトルか本文に入力があれば）
      if (_titleController.text.isNotEmpty ||
          _contentController.text.isNotEmpty) {
        _createAndSave();
      }
      return;
    }
    final db = ref.read(databaseProvider);
    db.updateMemo(
      id: widget.editingMemoId!,
      title: _titleController.text,
      content: _contentController.text,
    );
  }

  Future<void> _createAndSave() async {
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo(
      title: _titleController.text,
      content: _contentController.text,
    );
    // タグ自動付与
    if (widget.selectedParentTagId != null) {
      await db.addTagToMemo(memo.id, widget.selectedParentTagId!);
    }
    if (widget.selectedChildTagId != null) {
      await db.addTagToMemo(memo.id, widget.selectedChildTagId!);
    }
    _attachedTags = await db.getTagsForMemo(memo.id);
    widget.onMemoCreated(memo.id);
    setState(() => _hasMemo = true);
  }

  void _confirm() {
    FocusScope.of(context).unfocus();
    _clearInput();
    widget.onClosed();
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
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CornerRadius.card),
        border: Border.all(
          color: _hasMemo
              ? Colors.blueAccent.withValues(alpha: 0.5)
              : Colors.grey.shade300,
          width: _hasMemo ? 2 : 1,
        ),
        boxShadow: [AppShadows.card()],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー: タイトル + タグ
          _buildHeader(),
          // 本文
          _buildContent(),
          // ツールバー
          _buildToolbar(),
        ],
      ),
    );
  }

  /// ヘッダー（タイトル＋タグバッジ）
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        children: [
          // タイトル入力
          Expanded(
            child: TextField(
              controller: _titleController,
              onChanged: (_) => _onChanged(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'タイトル（任意）',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              maxLines: 1,
            ),
          ),
          // クリアボタン
          if (_titleController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _titleController.clear();
                _onChanged();
              },
              child: const Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          // 区切り線
          if (_attachedTags.isNotEmpty)
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          // タグバッジ
          ..._attachedTags.take(2).map((tag) => Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: TagColors.getColor(tag.colorIndex),
                  borderRadius: BorderRadius.circular(CornerRadius.childTag),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag.name.length > 5
                          ? '${tag.name.substring(0, 5)}...'
                          : tag.name,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: () async {
                        if (widget.editingMemoId != null) {
                          final db = ref.read(databaseProvider);
                          await db.removeTagFromMemo(
                              widget.editingMemoId!, tag.id);
                          _attachedTags = await db
                              .getTagsForMemo(widget.editingMemoId!);
                          setState(() {});
                        }
                      },
                      child: const Icon(Icons.close,
                          size: 12, color: Colors.black54),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// 本文入力
  Widget _buildContent() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: TextField(
          controller: _contentController,
          onChanged: (_) => _onChanged(),
          style: const TextStyle(fontSize: 15, height: 1.5),
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
    );
  }

  /// ツールバー
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Row(
        children: [
          // 削除ボタン
          GestureDetector(
            onTap: _hasMemo ? _deleteMemo : null,
            child: Icon(Icons.delete_outline,
                size: 18,
                color:
                    _hasMemo ? Colors.red.withValues(alpha: 0.5) : Colors.grey.shade300),
          ),
          const SizedBox(width: 12),
          // MDトグル
          Text('MD',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.grey[500],
              )),
          const SizedBox(width: 4),
          SizedBox(
            width: 34,
            height: 20,
            child: Switch(
              value: false,
              onChanged: (_) {},
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Spacer(),
          // Undo / Redo
          Icon(Icons.undo, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Icon(Icons.redo, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 12),
          // コピー
          GestureDetector(
            onTap: () {},
            child: Text('コピー',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ),
          const SizedBox(width: 12),
          // 確定 / メモを閉じる
          if (_hasMemo)
            GestureDetector(
              onTap: _confirm,
              child: Row(
                children: [
                  Icon(Icons.check, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 2),
                  const Text('確定',
                      style: TextStyle(
                          fontSize: 14, color: Colors.blueAccent)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _deleteMemo() {
    if (widget.editingMemoId == null) return;
    final db = ref.read(databaseProvider);
    db.deleteMemo(widget.editingMemoId!);
    _clearInput();
    widget.onClosed();
  }
}
