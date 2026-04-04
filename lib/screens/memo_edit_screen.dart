import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';

/// メモ編集画面（自動保存）
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
      // 閲覧カウント（ソート順は変えない）
      db.incrementViewCount(widget.memoId);
      setState(() => _isLoading = false);
    }
  }

  /// 入力するたびに即座に保存（CLAUDE.mdの指示: debounceなし）
  void _onChanged() {
    final db = ref.read(databaseProvider);
    db.updateMemo(
      id: widget.memoId,
      title: _titleController.text,
      content: _contentController.text,
    );
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActions(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // タイトル入力
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
              // 本文入力
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
                  // キーボードのタイプ（改行入力可能に）
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    // Phase 2以降で拡張（マークダウン切替、タグ付け等）
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
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('共有'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 共有機能実装
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
