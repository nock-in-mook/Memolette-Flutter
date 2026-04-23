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
import 'confirm_delete_dialog.dart';
import 'frosted_alert_dialog.dart';
import 'image_viewer.dart';
import 'markdown_text_controller.dart';

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

  /// 任意の TextBlock にフォーカスがあるか（hasFocus ベース）。
  /// フォーカスパス上に TextBlock があれば true になる（緩い判定）。
  bool get hasAnyFocus =>
      _blocks.whereType<_TextBlock>().any((b) => b.focusNode.hasFocus);

  /// 任意の TextBlock が primaryFocus を持つか（厳密判定）。
  /// 別 route の TextField に primaryFocus が移った時には false になる。
  /// キーボード上ツールバーの表示制御など、「実際に入力を受けているか」で
  /// 判断したい場面で使う。
  bool get hasActivePrimaryFocus {
    final primary = FocusManager.instance.primaryFocus;
    return _blocks
        .whereType<_TextBlock>()
        .any((b) => b.focusNode == primary);
  }

  /// 現在（または最後に）フォーカスされている TextBlock の controller。
  /// マークダウンツールバー等、外部から本文編集を差し込むときに使う。
  MarkdownTextController? get focusedController {
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

  /// フォーカス中（または最後にフォーカスがあった）TextBlock の
  /// 選択範囲を wrapper で囲む。MarkdownToolbar の同名ロジックと等価。
  /// ⌘B / ⌘I などキーボードショートカットから呼ぶ用途。
  void wrapFocusedSelection(String wrapper) {
    final controller = focusedController;
    if (controller == null) return;
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);

    if (start == end) {
      // 選択なし: ラッパーだけ挿入してカーソルを間に
      final insert = '$wrapper$wrapper';
      final newText =
          text.substring(0, start) + insert + text.substring(start);
      controller.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: start + wrapper.length),
      );
    } else {
      final selected = text.substring(start, end);
      final replacement = '$wrapper$selected$wrapper';
      final newText =
          text.substring(0, start) + replacement + text.substring(end);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + wrapper.length,
          extentOffset: end + wrapper.length,
        ),
      );
    }
  }

  /// 先頭の TextBlock にフォーカス。カーソルは末尾に寄せる。
  void focusFirst() {
    final first = _blocks.whereType<_TextBlock>().firstOrNull;
    if (first == null) return;
    final text = first.controller.text;
    first.controller.selection =
        TextSelection.collapsed(offset: text.length);
    first.focusNode.requestFocus();
  }

  /// 末尾の TextBlock にフォーカス。カーソルはその末尾に。
  /// 本文欄の下の広い余白をタップしたときに呼ぶ想定。
  void focusLast() {
    _TextBlock? last;
    for (final b in _blocks) {
      if (b is _TextBlock) last = b;
    }
    if (last == null) return;
    final text = last.controller.text;
    last.controller.selection =
        TextSelection.collapsed(offset: text.length);
    last.focusNode.requestFocus();
  }

  /// 現在フォーカス中の TextBlock から、シリアライズ本文における文字 offset を算出。
  /// プレビュー突入前に記録しておき、復帰時に focusAtSourceOffset で復元する用途。
  int? get currentSourceOffset {
    var cursor = 0;
    for (final b in _blocks) {
      if (b is _TextBlock) {
        if (b.focusNode.hasFocus) {
          final sel = b.controller.selection;
          final offset = sel.baseOffset < 0
              ? b.controller.text.length
              : sel.baseOffset;
          return cursor + offset;
        }
        cursor += b.controller.text.length;
      } else if (b is _ImageBlock) {
        cursor += '$_marker${b.image.id}$_marker'.length;
      }
    }
    return null;
  }

  /// シリアライズ後の本文における character offset にカーソルを合わせる。
  /// プレビューのタップ位置から逆引きして編集位置を合わせるときに使う。
  /// 画像マーカーに当たった場合はその直後の TextBlock の先頭に寄せる。
  void focusAtSourceOffset(int targetOffset) {
    var cursor = 0;
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (b is _TextBlock) {
        final len = b.controller.text.length;
        if (cursor + len >= targetOffset) {
          final within =
              (targetOffset - cursor).clamp(0, len).toInt();
          b.controller.selection =
              TextSelection.collapsed(offset: within);
          b.focusNode.requestFocus();
          return;
        }
        cursor += len;
      } else if (b is _ImageBlock) {
        final markerLen = '$_marker${b.image.id}$_marker'.length;
        if (cursor + markerLen >= targetOffset) {
          // マーカー内 → 直後の TextBlock の先頭に
          for (var j = i + 1; j < _blocks.length; j++) {
            final nb = _blocks[j];
            if (nb is _TextBlock) {
              nb.controller.selection =
                  const TextSelection.collapsed(offset: 0);
              nb.focusNode.requestFocus();
              return;
            }
          }
          focusLast();
          return;
        }
        cursor += markerLen;
      }
    }
    focusLast();
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
  /// - 画像マーカーの並びが現在と同じなら TextBlock.controller.text のみ更新
  ///   (フォーカス維持 = キーボードが閉じない)
  /// - 構造が違うなら全ブロック再生成（DB画像も再ロード）
  void replaceContent(String content) {
    final currentStructure = _extractMarkerSequence(_serialize());
    final newStructure = _extractMarkerSequence(content);
    if (_listEquals(currentStructure, newStructure)) {
      // 画像の並びが同じ: テキスト部分だけ更新してフォーカスを保つ
      _applyTextOnlyUpdate(content);
      return;
    }
    _disposeBlocks();
    _blocks.clear();
    _initialized = false;
    if (mounted) setState(() {});
    _loadBlocksFromContent(content);
  }

  static List<String> _extractMarkerSequence(String content) {
    final regex = RegExp('$_marker([^$_marker]+)$_marker');
    return regex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toList(growable: false);
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 画像マーカー位置で content を分割し、
  /// 現在の _blocks の各 TextBlock にテキストを上書き
  void _applyTextOnlyUpdate(String content) {
    final regex = RegExp('$_marker([^$_marker]+)$_marker');
    final texts = <String>[];
    var cursor = 0;
    for (final match in regex.allMatches(content)) {
      texts.add(content.substring(cursor, match.start));
      cursor = match.end;
    }
    texts.add(content.substring(cursor));
    // _blocks は TextBlock / ImageBlock が交互に並ぶ想定だが厳密ではないので
    // TextBlock だけを順に拾って上書きする
    var textIdx = 0;
    for (final b in _blocks) {
      if (b is _TextBlock && textIdx < texts.length) {
        final newText = texts[textIdx++];
        if (b.controller.text != newText) {
          // 変化位置にカーソルを寄せる: Undo/Redo で文字数が変わったとき、
          // カーソルが「ファイル先頭からの文字数固定」で残ると見かけ上ずれる。
          // 共通 prefix / suffix を取って変化領域を特定し、カーソルをそこに移す。
          final oldText = b.controller.text;
          final oldCursor = b.controller.selection.baseOffset;
          final newCursor = _adjustCursor(oldText, newText, oldCursor);
          b.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursor),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  /// Undo/Redo 時に、新テキストに対してカーソル位置を変化領域に追従させる
  /// - 旧カーソルが共通 prefix 内 → そのまま維持
  /// - 共通 suffix 内 → 長さ差分だけシフト
  /// - 変化領域の中 → 共通 prefix 末尾（= 変化の開始点）に寄せる
  static int _adjustCursor(String oldText, String newText, int oldCursor) {
    if (oldCursor < 0) return newText.length;
    // 共通 prefix
    var prefix = 0;
    final minLen =
        oldText.length < newText.length ? oldText.length : newText.length;
    while (prefix < minLen && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    // 共通 suffix
    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText[oldSuffix - 1] == newText[newSuffix - 1]) {
      oldSuffix--;
      newSuffix--;
    }
    if (oldCursor <= prefix) return oldCursor;
    if (oldCursor >= oldSuffix) {
      final shifted = oldCursor - (oldSuffix - newSuffix);
      return shifted.clamp(0, newText.length);
    }
    return prefix.clamp(0, newText.length);
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
    if (oldWidget.isMarkdown != widget.isMarkdown) {
      _applyMarkdownToControllers();
    }
  }

  /// 全 TextBlock の MarkdownTextController の enabled を現在の isMarkdown に同期
  void _applyMarkdownToControllers() {
    for (final b in _blocks.whereType<_TextBlock>()) {
      b.controller.enabled = widget.isMarkdown;
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
    _applyMarkdownToControllers();
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
    _applyMarkdownToControllers();
    widget.onContentChanged(_serialize());
    // 挿入後は画像の下の TextBlock にフォーカス移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      afterBlock.focusNode.requestFocus();
    });
    if (mounted) setState(() {});
  }

  Future<void> _confirmDeleteImage(_ImageBlock block) async {
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: '画像を削除',
      message: 'この画像を削除しますか？',
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
    _applyMarkdownToControllers();
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
    // 先頭 TextBlock にだけプレースホルダーを出す
    final children = <Widget>[];
    var firstTextSeen = false;
    for (final block in _blocks) {
      if (block is _TextBlock) {
        children.add(_buildTextField(block, isFirstText: !firstTextSeen));
        firstTextSeen = true;
      } else if (block is _ImageBlock) {
        children.add(_buildImage(block));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildTextField(_TextBlock block, {bool isFirstText = false}) {
    final hintText = isFirstText
        ? (widget.isMarkdown ? 'タップでマークダウン編集...' : 'メモを入力...')
        : null;
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
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
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
  final MarkdownTextController controller;
  final FocusNode focusNode;

  _TextBlock({required String text, required this.id})
      : controller = MarkdownTextController(text: text),
        focusNode = FocusNode();
}

class _ImageBlock extends _Block {
  @override
  final String id;
  final MemoImage image;

  _ImageBlock({required this.image, required this.id});
}
