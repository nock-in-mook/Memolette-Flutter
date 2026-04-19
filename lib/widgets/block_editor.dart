import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/image_storage.dart';
import '../utils/text_menu_dismisser.dart';
import '../utils/toast.dart';
import 'frosted_alert_dialog.dart';
import 'image_viewer.dart';

/// Phase 10++ ブロックエディタ（実験版）
///
/// - 本文を「TextBlock と ImageBlock の配列」として扱う
/// - DB上の `Memos.content` は U+FFFC (Object Replacement Character) で
///   画像IDを挟み込んだ文字列として保存される：
///     text1 `\uFFFC`imageId`\uFFFC` text2 `\uFFFC`imageId2`\uFFFC` text3
/// - 各 TextBlock はそれぞれ TextField。画像挿入はフォーカス中の TextBlock を
///   カーソル位置で分割して間に ImageBlock を入れる
/// - 画像削除時は前後の TextBlock を自動マージ
///
/// 使い方: 親が `GlobalKey&lt;BlockEditorState&gt;` を持ち、`insertImageFromPicker()`
/// を呼び出す。content は onContentChanged でリアルタイムに通知される。
class BlockEditor extends ConsumerStatefulWidget {
  /// 画像挿入時に使う memoId を返すコールバック。親が `_selfCreatedMemoId ?? widget.editingMemoId` を返す想定。
  /// 実メモがまだない場合、親側で先に作成してから呼び出すこと。
  final String Function() memoIdResolver;
  final String initialContent;
  final ValueChanged<String> onContentChanged;
  final VoidCallback? onFocusChanged;
  /// 任意の TextBlock がタップされたとき（readOnly かどうかに関係なく呼ばれる）。
  /// 親が閲覧モード→編集モード切替に使う。
  final VoidCallback? onTap;
  final bool isMarkdown;
  final bool readOnly;

  const BlockEditor({
    super.key,
    required this.memoIdResolver,
    required this.initialContent,
    required this.onContentChanged,
    this.onFocusChanged,
    this.onTap,
    this.isMarkdown = false,
    this.readOnly = false,
  });

  @override
  ConsumerState<BlockEditor> createState() => BlockEditorState();
}

class BlockEditorState extends ConsumerState<BlockEditor> {
  static const _marker = '\uFFFC';
  static const _uuid = Uuid();

  final List<_Block> _blocks = [];
  // 最後にフォーカスされた TextBlock の ID（画像挿入位置の決定用）
  String? _lastFocusedTextBlockId;
  bool _initialized = false;

  // ========================================
  // 公開 API
  // ========================================

  /// 現在のシリアライズ済み本文を返す
  String get currentContent => _serialize();

  /// 任意の TextBlock にフォーカスがあるか
  bool get hasAnyFocus =>
      _blocks.whereType<_TextBlock>().any((b) => b.focusNode.hasFocus);

  /// 現在（または最後に）フォーカスされている TextBlock の controller。
  /// マークダウンツールバー等、外部から本文編集を差し込むときに使う。
  TextEditingController? get focusedController {
    for (final b in _blocks.whereType<_TextBlock>()) {
      if (b.focusNode.hasFocus) return b.controller;
    }
    if (_lastFocusedTextBlockId != null) {
      for (final b in _blocks.whereType<_TextBlock>()) {
        if (b.id == _lastFocusedTextBlockId) return b.controller;
      }
    }
    // 末尾 TextBlock フォールバック
    _TextBlock? last;
    for (final b in _blocks) {
      if (b is _TextBlock) last = b;
    }
    return last?.controller;
  }

  /// 先頭の TextBlock にフォーカス
  void focusFirst() {
    final first = _blocks.whereType<_TextBlock>().firstOrNull;
    first?.focusNode.requestFocus();
  }

  /// 画像ピッカー → 圧縮 → DB保存 → カーソル位置に挿入
  Future<void> insertImageFromPicker(ImageSource source) async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(source: source);
    } catch (_) {
      if (mounted) showToast(context, '画像の取り込みに失敗しました');
      return;
    }
    if (picked == null) return;
    final memoId = widget.memoIdResolver();
    if (memoId.isEmpty) {
      if (mounted) showToast(context, 'メモの作成に失敗しました');
      return;
    }
    final relPath = await ImageStorage.saveCompressed(picked.path);
    if (relPath == null) {
      if (mounted) showToast(context, '画像の保存に失敗しました');
      return;
    }
    final db = ref.read(databaseProvider);
    final img = await db.addMemoImage(
      memoId: memoId,
      filePath: relPath,
    );
    if (!mounted) return;
    _insertImageAtCursor(img);
  }

  /// 本文文字列の外部更新（親から置き換えたい場合）
  /// DB から画像を再ロードするので、別メモに切り替わるケースも正しく復元できる
  void replaceContent(String content) {
    _disposeBlocks();
    _blocks.clear();
    _initialized = false;
    if (mounted) setState(() {});
    _loadBlocksFromContent(content);
  }

  // ========================================
  // ライフサイクル
  // ========================================

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  @override
  void didUpdateWidget(covariant BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialContent != widget.initialContent &&
        _serialize() != widget.initialContent) {
      // 外部から content が書き変わったケース（別メモに切替 / Undo/Redo等）
      replaceContent(widget.initialContent);
    }
  }

  @override
  void dispose() {
    _disposeBlocks();
    super.dispose();
  }

  Future<void> _initAsync() => _loadBlocksFromContent(widget.initialContent);

  /// 指定 content から DB 画像を取得してブロック配列を再構築
  Future<void> _loadBlocksFromContent(String content) async {
    final db = ref.read(databaseProvider);
    final memoId = widget.memoIdResolver();
    final images =
        memoId.isEmpty ? <MemoImage>[] : await db.getMemoImages(memoId);
    if (!mounted) return;
    _blocks
      ..clear()
      ..addAll(_parse(content, images));
    // 本文に参照されていない DB 画像は末尾に追加
    final referenced =
        _blocks.whereType<_ImageBlock>().map((b) => b.image.id).toSet();
    for (final img in images) {
      if (!referenced.contains(img.id)) {
        _blocks.add(_ImageBlock(image: img, id: _uuid.v4()));
        _blocks.add(_TextBlock(text: '', id: _uuid.v4()));
      }
    }
    _attachListeners();
    _initialized = true;
    if (mounted) setState(() {});
  }

  // ========================================
  // 内部ロジック
  // ========================================

  List<MemoImage> _knownImagesSnapshot() =>
      _blocks.whereType<_ImageBlock>().map((b) => b.image).toList();

  List<_Block> _parse(String content, List<MemoImage> images) {
    final byId = {for (final img in images) img.id: img};
    final regex = RegExp('$_marker([^$_marker]+)$_marker');
    final out = <_Block>[];
    var cursor = 0;
    for (final match in regex.allMatches(content)) {
      final before = content.substring(cursor, match.start);
      out.add(_TextBlock(text: before, id: _uuid.v4()));
      final id = match.group(1)!;
      final img = byId[id];
      if (img != null) {
        out.add(_ImageBlock(image: img, id: _uuid.v4()));
      }
      cursor = match.end;
    }
    out.add(_TextBlock(text: content.substring(cursor), id: _uuid.v4()));
    // 必ず TextBlock で挟む
    if (out.whereType<_TextBlock>().isEmpty) {
      out.add(_TextBlock(text: '', id: _uuid.v4()));
    }
    return out;
  }

  String _serialize() {
    final buf = StringBuffer();
    for (final b in _blocks) {
      if (b is _TextBlock) {
        buf.write(b.controller.text);
      } else if (b is _ImageBlock) {
        buf.write('$_marker${b.image.id}$_marker');
      }
    }
    return buf.toString();
  }

  void _attachListeners() {
    for (final b in _blocks.whereType<_TextBlock>()) {
      b.controller.removeListener(_onTextChanged);
      b.controller.addListener(_onTextChanged);
      b.focusNode.removeListener(_onFocus);
      b.focusNode.addListener(_onFocus);
    }
  }

  void _disposeBlocks() {
    for (final b in _blocks.whereType<_TextBlock>()) {
      b.controller.dispose();
      b.focusNode.dispose();
    }
  }

  void _onTextChanged() {
    widget.onContentChanged(_serialize());
  }

  void _onFocus() {
    for (final b in _blocks.whereType<_TextBlock>()) {
      if (b.focusNode.hasFocus) {
        _lastFocusedTextBlockId = b.id;
        break;
      }
    }
    widget.onFocusChanged?.call();
  }

  /// カーソル位置の TextBlock を特定（フォーカス優先、なければ最後にフォーカスされたブロック、なければ末尾）
  int _activeTextBlockIndex() {
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (b is _TextBlock && b.focusNode.hasFocus) return i;
    }
    if (_lastFocusedTextBlockId != null) {
      for (var i = 0; i < _blocks.length; i++) {
        final b = _blocks[i];
        if (b is _TextBlock && b.id == _lastFocusedTextBlockId) return i;
      }
    }
    // 末尾の TextBlock
    for (var i = _blocks.length - 1; i >= 0; i--) {
      if (_blocks[i] is _TextBlock) return i;
    }
    return 0;
  }

  void _insertImageAtCursor(MemoImage img) {
    final idx = _activeTextBlockIndex();
    if (idx < 0 || idx >= _blocks.length || _blocks[idx] is! _TextBlock) {
      // フォールバック: 末尾に追加
      _blocks.add(_ImageBlock(image: img, id: _uuid.v4()));
      _blocks.add(_TextBlock(text: '', id: _uuid.v4()));
      _attachListeners();
      widget.onContentChanged(_serialize());
      if (mounted) setState(() {});
      return;
    }
    final target = _blocks[idx] as _TextBlock;
    final sel = target.controller.selection;
    final offset =
        sel.baseOffset >= 0 ? sel.baseOffset : target.controller.text.length;
    final text = target.controller.text;
    final clamped = offset.clamp(0, text.length);
    // ブロック分割 + 画像 Padding で自然に1行分の空きが生まれるため
    // ここで \n を追加すると視覚的に改行が2つに見える → 追加しない
    final before = text.substring(0, clamped);
    final after = text.substring(clamped);
    // 置換: [..., TextBlock(before), ImageBlock(img), TextBlock(after), ...]
    target.controller.removeListener(_onTextChanged);
    target.focusNode.removeListener(_onFocus);
    target.controller.dispose();
    target.focusNode.dispose();
    final beforeBlock = _TextBlock(text: before, id: _uuid.v4());
    final imageBlock = _ImageBlock(image: img, id: _uuid.v4());
    final afterBlock = _TextBlock(text: after, id: _uuid.v4());
    _blocks[idx] = beforeBlock;
    _blocks.insert(idx + 1, imageBlock);
    _blocks.insert(idx + 2, afterBlock);
    _attachListeners();
    widget.onContentChanged(_serialize());
    // 挿入後は画像の下の TextBlock にフォーカス移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      afterBlock.focusNode.requestFocus();
    });
    if (mounted) setState(() {});
  }

  Future<void> _confirmDeleteImage(_ImageBlock block) async {
    var ok = false;
    await showFrostedAlert(
      context: context,
      title: '画像を削除しますか？',
      actions: [
        FrostedAlertAction(label: 'キャンセル'),
        FrostedAlertAction(
          label: '削除',
          isDestructive: true,
          onPressed: () => ok = true,
        ),
      ],
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    await db.deleteMemoImage(block.image.id);
    if (!mounted) return;
    _removeImageBlock(block);
  }

  /// ImageBlock を削除し、前後の TextBlock を1つにマージ
  void _removeImageBlock(_ImageBlock block) {
    final idx = _blocks.indexOf(block);
    if (idx < 0) return;
    final before = (idx > 0 && _blocks[idx - 1] is _TextBlock)
        ? _blocks[idx - 1] as _TextBlock
        : null;
    final after = (idx < _blocks.length - 1 && _blocks[idx + 1] is _TextBlock)
        ? _blocks[idx + 1] as _TextBlock
        : null;
    _blocks.removeAt(idx);
    if (before != null && after != null) {
      // マージ: before + after
      final merged = _TextBlock(
        text: before.controller.text + after.controller.text,
        id: _uuid.v4(),
      );
      // 旧2つを dispose
      before.controller.removeListener(_onTextChanged);
      before.focusNode.removeListener(_onFocus);
      before.controller.dispose();
      before.focusNode.dispose();
      after.controller.removeListener(_onTextChanged);
      after.focusNode.removeListener(_onFocus);
      after.controller.dispose();
      after.focusNode.dispose();
      // idx-1 (before) を merged で置換、idx (元 after の位置) を削除
      _blocks[idx - 1] = merged;
      _blocks.removeAt(idx);
    }
    _attachListeners();
    widget.onContentChanged(_serialize());
    if (mounted) setState(() {});
  }

  // ========================================
  // 描画
  // ========================================

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in _blocks) _buildBlock(block),
      ],
    );
  }

  Widget _buildBlock(_Block block) {
    if (block is _TextBlock) return _buildTextField(block);
    if (block is _ImageBlock) return _buildImage(block);
    return const SizedBox.shrink();
  }

  Widget _buildTextField(_TextBlock block) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      child: TextField(
        controller: block.controller,
        focusNode: block.focusNode,
        readOnly: widget.readOnly,
        onTap: TextMenuDismisser.wrap(() {
          widget.onTap?.call();
        }),
        style: const TextStyle(
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w500,
          fontFamily: 'PingFang JP',
          color: Colors.black87,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        contextMenuBuilder: TextMenuDismisser.builder,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  Widget _buildImage(_ImageBlock block) {
    // 本文に挟まるサムネ。閲覧性重視で 120x120 固定、タップで全画面ビューアへ
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FutureBuilder<String>(
          future: ImageStorage.absolutePath(block.image.filePath),
          builder: (ctx, snap) {
            final path = snap.data;
            return GestureDetector(
              onTap: path == null ? null : () => _openViewer(block),
              onLongPress: () => _confirmDeleteImage(block),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey.shade200,
                      child: path == null
                          ? const SizedBox()
                          : Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              // インラインサムネは 120px 表示。retina 3x で 360px 相当
                              cacheWidth: 360,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _confirmDeleteImage(block),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openViewer(_ImageBlock block) {
    final images = _blocks.whereType<_ImageBlock>().map((b) => b.image).toList();
    final initialIndex = images.indexWhere((i) => i.id == block.image.id);
    ImageViewer.open(
      context,
      images: images,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }
}

// ========================================
// 内部データ型
// ========================================

sealed class _Block {
  String get id;
}

class _TextBlock extends _Block {
  @override
  final String id;
  final TextEditingController controller;
  final FocusNode focusNode;

  _TextBlock({required String text, required this.id})
      : controller = TextEditingController(text: text),
        focusNode = FocusNode();
}

class _ImageBlock extends _Block {
  @override
  final String id;
  final MemoImage image;

  _ImageBlock({required this.image, required this.id});
}
