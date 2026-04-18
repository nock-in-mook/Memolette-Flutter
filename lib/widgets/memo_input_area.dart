import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../constants/memo_bg_colors.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/safe_dialog.dart';
import '../utils/text_menu_dismisser.dart';
import '../utils/toast.dart';
import 'frosted_alert_dialog.dart';
import 'markdown_text_controller.dart';
import 'markdown_toolbar.dart';
import 'new_tag_sheet.dart';
import 'tag_dial_view.dart';

/// メモ入力エリア（ホーム画面上部に常駐）
/// Swift版の MemoInputView に対応
class MemoInputArea extends ConsumerStatefulWidget {
  final String? editingMemoId;
  final void Function(String id) onMemoCreated;
  final VoidCallback onClosed;
  final String? selectedParentTagId;
  final String? selectedChildTagId;
  /// インクリメントすると本文入力欄にフォーカスを要求する (新規作成ボタン用)
  final int focusRequest;
  /// 最大化中かどうか (親がレイアウトを変える)
  final bool isExpanded;
  /// 最大化トグル (親が状態を持つ)
  final VoidCallback? onToggleExpanded;
  /// タグ履歴表示状態が変わったときの通知（親のsetStateを呼ぶ用）
  final VoidCallback? onTagHistoryChanged;
  /// フォーカス状態が変わったときの通知（親のsetStateを呼ぶ用）
  final VoidCallback? onFocusChanged;
  /// ダイアログ開閉状態が変わったときの通知（true=開いた、false=閉じた）
  /// 編集中のダイアログ表示でキーボードが消えてフォルダビューが一瞬出るのを防ぐ用
  final ValueChanged<bool>? onDialogOpenChanged;
  /// 本文/タイトル変更時の通知（機能バー・フロート消しゴムボタンの有効化再評価用）
  final VoidCallback? onContentChanged;

  const MemoInputArea({
    super.key,
    this.editingMemoId,
    required this.onMemoCreated,
    required this.onClosed,
    this.selectedParentTagId,
    this.selectedChildTagId,
    this.focusRequest = 0,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.onTagHistoryChanged,
    this.onFocusChanged,
    this.onDialogOpenChanged,
    this.onContentChanged,
  });

  @override
  ConsumerState<MemoInputArea> createState() => MemoInputAreaState();
}

class MemoInputAreaState extends ConsumerState<MemoInputArea> {
  /// 外部から本文の有無を確認するゲッター（ゼロ幅スペースは無視）
  bool get hasContent => _contentController.text.isNotEmpty;
  /// 外部から本文フォーカス状態を確認するゲッター
  bool get isContentFocused => _contentFocusNode.hasFocus;
  /// タイトル欄がフォーカス中か
  bool get isTitleFocused => _titleFocusNode.hasFocus;
  /// 外部から入力欄全体のフォーカス状態を確認するゲッター（タイトル or 本文）
  bool get isInputFocused => _isInputFocused;
  /// 本文欄にフォーカスを強制要求（最大化タップでフォーカスが外れたときの復元用）
  void refocusContent() => _contentFocusNode.requestFocus();
  /// タイトル欄にフォーカスを強制要求
  void refocusTitle() => _titleFocusNode.requestFocus();
  /// 外部からメモを閉じる（入力欄クリア、MDモードは保持）
  void closeMemo() => _clearInput(keepMarkdown: _isMarkdown);
  /// 外部からタグ表示を再読み込み（保存ボタン等でタグ付与後に呼ぶ）
  Future<void> reloadTags() async {
    if (widget.editingMemoId == null) return;
    final db = ref.read(databaseProvider);
    _attachedTags = await db.getTagsForMemo(widget.editingMemoId!);
    if (mounted) setState(() {});
  }
  /// ルーレットが開いてるか
  bool get isRouletteOpen => _rouletteOpen;
  /// ルーレットを閉じる（外部から呼べる）
  void closeRoulette() => _closeRoulette();
  /// タグ履歴が表示中か
  bool get showTagHistory => _showTagHistory;
  /// タグ履歴アイテム
  List<TagHistory> get tagHistoryItems => _tagHistoryItems;
  /// 履歴からタグを選択（外部から呼べる）
  Future<void> selectFromHistory(TagHistory item) => _selectFromHistory(item);
  /// 履歴パネルを閉じる
  void closeTagHistory() {
    setState(() => _showTagHistory = false);
    widget.onTagHistoryChanged?.call();
  }

  // 本文の最大文字数（Swift版準拠）
  static const int _maxContentLength = 50000;
  // Undo/Redo履歴の最大段数
  static const int _maxUndoSnapshots = 50;

  final _titleController = TextEditingController();
  final _contentController = MarkdownTextController();
  final _titleFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _contentScrollController = ScrollController();
  bool get _isInputFocused =>
      _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;
  List<Tag> _attachedTags = [];
  bool _hasMemo = false;
  bool _rouletteOpen = false;
  // 閲覧モード: 既存メモをカードからタップして開いた直後はキーボードを出さず
  // テキストを表示するだけ。本文/タイトルをタップすると編集モードへ遷移 (本家準拠)
  bool _isViewMode = false;
  // マークダウンモード: ON時は記号ツールバー表示 + プレビュー切替可能
  bool _isMarkdown = false;
  /// メモ背景色インデックス（0=なし/白、1-71=タグカラーパレット）
  int _bgColorIndex = 0;
  // マークダウンプレビュー表示中か（エディタ↔プレビュー切替）
  bool _showMarkdownPreview = false;
  // メモ未作成時にルーレットで先に選んだタグの保持先（事前選択状態）
  Tag? _pendingParentTag;
  Tag? _pendingChildTag;

  // Undo/Redo: undoStack の top が常に「現在の状態」
  // Undo するには最低 2 要素必要(現在＋ひとつ前)
  final List<_InputSnapshot> _undoStack = [];
  final List<_InputSnapshot> _redoStack = [];
  bool _suppressUndo = false; // Undo/Redo 適用中は履歴を積まない

  bool get _canUndo => _undoStack.length > 1;
  bool get _canRedo => _redoStack.isNotEmpty;

  _InputSnapshot _currentSnapshot() => _InputSnapshot(
        title: _titleController.text,
        content: _contentController.text,
        parentTagId: _parentTag?.id,
        childTagId: _childTag?.id,
      );

  void _pushUndoIfChanged() {
    if (_suppressUndo) return;
    final cur = _currentSnapshot();
    if (_undoStack.isNotEmpty && _undoStack.last == cur) return;
    _undoStack.add(cur);
    if (_undoStack.length > _maxUndoSnapshots) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _resetUndoHistory() {
    _undoStack
      ..clear()
      ..add(_currentSnapshot());
    _redoStack.clear();
  }

  Future<void> _undo() async {
    if (!_canUndo) return;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final past = _undoStack.last;
    await _applySnapshot(past);
  }

  Future<void> _redo() async {
    if (!_canRedo) return;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    await _applySnapshot(next);
  }

  Future<void> _applySnapshot(_InputSnapshot s) async {
    _suppressUndo = true;
    try {
      _titleController.text = s.title;
      _contentController.text = s.content;
      // タグの復元: メモが既存ならDB操作、未作成ならpending
      final allTags =
          ref.read(allTagsProvider).value ?? const <Tag>[];
      Tag? findTag(String? id) {
        if (id == null) return null;
        for (final t in allTags) {
          if (t.id == id) return t;
        }
        return null;
      }

      final newParent = findTag(s.parentTagId);
      final newChild = findTag(s.childTagId);

      if (widget.editingMemoId != null) {
        final db = ref.read(databaseProvider);
        // 既存タグを全部外して付け直す
        for (final t in _attachedTags) {
          await db.removeTagFromMemo(widget.editingMemoId!, t.id);
        }
        if (newParent != null) {
          await db.addTagToMemo(widget.editingMemoId!, newParent.id);
        }
        if (newChild != null) {
          await db.addTagToMemo(widget.editingMemoId!, newChild.id);
        }
        _attachedTags = await db.getTagsForMemo(widget.editingMemoId!);
        await db.updateMemo(
          id: widget.editingMemoId!,
          title: s.title,
          content: s.content,
        );
      } else {
        _pendingParentTag = newParent;
        _pendingChildTag = newChild;
      }
      if (mounted) setState(() {});
    } finally {
      _suppressUndo = false;
    }
  }

  /// 表示用の親タグ（メモ作成済みなら添付タグ、未作成ならpending）
  Tag? get _parentTag {
    for (final t in _attachedTags) {
      if (t.parentTagId == null) return t;
    }
    return _pendingParentTag;
  }

  /// 表示用の子タグ（メモ作成済みなら添付タグ、未作成ならpending）
  Tag? get _childTag {
    for (final t in _attachedTags) {
      if (t.parentTagId != null) return t;
    }
    return _pendingChildTag;
  }

  /// 半角幅換算で文字列を切り詰める（全角=2、半角=1）
  String _truncateByWidth(String text, double maxWidth) {
    double width = 0;
    final buf = StringBuffer();
    for (final ch in text.characters) {
      final w = ch.runes.every((r) => r < 128) ? 1.0 : 2.0;
      if (width + w > maxWidth) {
        return '${buf.toString()}…';
      }
      width += w;
      buf.write(ch);
    }
    return buf.toString();
  }

  // マークダウンツールバーのOverlay管理
  OverlayEntry? _mdToolbarOverlay;

  void _updateMdToolbarOverlay() {
    final shouldShow = _isMarkdown && _contentFocusNode.hasFocus;
    if (shouldShow && _mdToolbarOverlay == null) {
      _mdToolbarOverlay = OverlayEntry(builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        if (bottom <= 0) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: Material(
            elevation: 0,
            child: MarkdownToolbar(
              controller: _contentController,
              onChanged: _onChanged,
            ),
          ),
        );
      });
      Overlay.of(context).insert(_mdToolbarOverlay!);
    } else if (!shouldShow && _mdToolbarOverlay != null) {
      _mdToolbarOverlay!.remove();
      _mdToolbarOverlay = null;
    } else if (shouldShow && _mdToolbarOverlay != null) {
      // キーボード高さ変化時にリビルド
      _mdToolbarOverlay!.markNeedsBuild();
    }
  }

  @override
  void initState() {
    super.initState();
    _resetUndoHistory();
    _titleFocusNode.addListener(_onFocusChange);
    _contentFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      // フォーカスを得た時点でメモ未作成なら空メモを先行作成
      if (_isInputFocused && widget.editingMemoId == null && !_hasMemo) {
        _preCreateEmptyMemo();
      }
      // フォーカスが外れたとき、空メモなら削除
      // 最大化中でも削除対象（空メモの残留を防ぐ）
      if (!_isInputFocused && widget.editingMemoId != null) {
        final t = _titleController.text;
        final c = _contentController.text;
        // 色が付いているメモは空扱いしない（色だけ入れたメモも保持）
        if (t.isEmpty && c.isEmpty && _bgColorIndex == 0) {
          final db = ref.read(databaseProvider);
          db.deleteMemo(widget.editingMemoId!);
          _clearInput(keepMarkdown: _isMarkdown);
          widget.onClosed();
          return;
        }
      }
      setState(() {});
      _updateMdToolbarOverlay();
      widget.onFocusChanged?.call();
    }
  }

  @override
  void didUpdateWidget(covariant MemoInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMemoId != oldWidget.editingMemoId) {
      if (widget.editingMemoId != null) {
        // 自分で作成したメモなら再ロード不要（閲覧モードにしない）
        // ただしタグは外部（home_screen）から付与された可能性があるので再取得する
        if (widget.editingMemoId == _selfCreatedMemoId) {
          _selfCreatedMemoId = null;
          final id = widget.editingMemoId!;
          final db = ref.read(databaseProvider);
          db.getTagsForMemo(id).then((tags) {
            if (mounted && widget.editingMemoId == id) {
              _attachedTags = tags;
              setState(() {});
            }
          });
        } else if (_directLoadApplied) {
          // loadMemoDirectlyで既にロード済み → スキップ
          _directLoadApplied = false;
        } else {
          _loadMemo(widget.editingMemoId!);
        }
      } else {
        // MDモードは保持（本文全削除→親がeditingMemoIdをnullにしてきた経路で
        // MDスイッチが勝手にオフになるのを防ぐ）
        _clearInput(keepMarkdown: _isMarkdown);
      }
    }
    // 新規作成ボタンからのフォーカス要求
    if (widget.focusRequest != oldWidget.focusRequest) {
      _isViewMode = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _contentFocusNode.requestFocus();
      });
    }
  }

  Future<void> _loadMemo(String id) async {
    final db = ref.read(databaseProvider);
    final memo = await db.getMemoById(id);
    if (memo != null && mounted) {
      _applyMemoData(memo);
      // タグはバックグラウンドで読み込み
      _attachedTags = await db.getTagsForMemo(id);
      if (mounted) setState(() {});
    }
  }

  /// メモデータを直接適用する（DBクエリ不要で高速）
  void loadMemoDirectly(Memo memo) {
    _directLoadApplied = true;
    _applyMemoData(memo);
    // タグは非同期で読み込み
    final db = ref.read(databaseProvider);
    db.getTagsForMemo(memo.id).then((tags) {
      if (mounted) {
        _attachedTags = tags;
        setState(() {});
      }
    });
  }

  /// メモデータを適用し、編集モードで本文にフォーカスを当てる
  /// （「このフォルダにメモ作成」ボタンから呼ばれる）
  void loadMemoAndEdit(Memo memo) {
    loadMemoDirectly(memo);
    setState(() => _isViewMode = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _contentFocusNode.requestFocus();
      });
    });
  }

  void _applyMemoData(Memo memo) {
    _suppressUndo = true;
    _titleController.text = memo.title;
    _contentController.text = memo.content;
    _suppressUndo = false;
    _resetUndoHistory();
    _contentController.enabled = memo.isMarkdown;
    // スクロール位置を先頭にリセット
    if (_contentScrollController.hasClients) {
      _contentScrollController.jumpTo(0);
    }
    setState(() {
      _hasMemo = true;
      _isViewMode = true;
      _isMarkdown = memo.isMarkdown;
      _bgColorIndex = memo.bgColorIndex;
      _showMarkdownPreview = false;
    });
  }

  void _clearInput({bool keepMarkdown = false}) {
    _suppressUndo = true;
    _titleController.clear();
    _contentController.clear();
    _attachedTags = [];
    _pendingParentTag = null;
    _pendingChildTag = null;
    _suppressUndo = false;
    _resetUndoHistory();
    if (!keepMarkdown) {
      _isMarkdown = false;
      _showMarkdownPreview = false;
      _contentController.enabled = false;
    }
    // 背景色は常にリセット（次のメモに持ち越さない）
    _bgColorIndex = 0;
    _updateMdToolbarOverlay();
    // スクロール位置を先頭にリセット
    if (_contentScrollController.hasClients) {
      _contentScrollController.jumpTo(0);
    }
    setState(() {
      _hasMemo = false;
      _isViewMode = false;
    });
  }

  // 閲覧モードを抜けて編集モードへ。本文タップ等から呼ばれる
  // readOnly解除後にフォーカスを当てるが、ScrollableのscrollPadding計算は
  // readOnly=false が反映された後のフレームで走るため、2フレーム待つ
  void _enterEditMode({bool focusContent = true, bool focusTitle = false}) {
    setState(() => _isViewMode = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (focusTitle) _titleFocusNode.requestFocus();
        if (focusContent) _contentFocusNode.requestFocus();
      });
    });
  }

  /// 入力内容を即座に保存
  void _onChanged() {
    _pushUndoIfChanged();
    widget.onContentChanged?.call();
    if (widget.editingMemoId == null) {
      // 通常はフォーカス時に先行作成済みだが、フォールバックとして
      // 次フレームで作成（rebuildとの干渉を避けるため遅延）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.editingMemoId != null) return;
        if (_titleController.text.isNotEmpty ||
            _contentController.text.isNotEmpty) {
          _preCreateEmptyMemo();
        }
      });
      return;
    }
    final db = ref.read(databaseProvider);
    // タイトルも本文も空になったらメモを削除
    // カスタムキーボードが確定時に一瞬テキストをクリアするケースがあるため
    // 即削除せず次フレームで再確認する
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.editingMemoId == null) return;
        if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
          db.deleteMemo(widget.editingMemoId!);
          _clearInput(keepMarkdown: _isMarkdown);
          widget.onClosed();
        }
      });
      return;
    }
    db.updateMemo(
      id: widget.editingMemoId!,
      title: _titleController.text,
      content: _contentController.text,
    );
    if (mounted) setState(() {}); // Undo/Redoボタンの状態更新用
  }

  // 自分で作成したメモのID（_loadMemoで閲覧モードにしないため）
  String? _selfCreatedMemoId;
  // loadMemoDirectlyで直接ロード済み → didUpdateWidgetでの_loadMemoをスキップ
  bool _directLoadApplied = false;

  /// フォーカス取得時に空メモを先行作成
  /// 以降の入力はすべてupdateMemoで処理されるため、rebuildが発生せず
  /// カスタムキーボードのテキスト消失を防ぐ
  Future<void> _preCreateEmptyMemo() async {
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo(
      isMarkdown: _isMarkdown,
      bgColorIndex: _bgColorIndex,
    );
    // ルーレットで先に選んだタグを付与
    final parentId = _pendingParentTag?.id;
    final childId = _pendingChildTag?.id;
    if (parentId != null) {
      await db.addTagToMemo(memo.id, parentId);
    }
    if (childId != null) {
      await db.addTagToMemo(memo.id, childId);
    }
    _attachedTags = await db.getTagsForMemo(memo.id);
    _pendingParentTag = null;
    _pendingChildTag = null;
    _selfCreatedMemoId = memo.id;
    widget.onMemoCreated(memo.id);
    if (mounted) setState(() => _hasMemo = true);
  }

  // 確定: キーボードを閉じるだけ。メモは残す（本家準拠）
  void _confirm() {
    FocusScope.of(context).unfocus();
  }

  /// iOSコンテキストメニュー(Select All等)を消す
  void _hideContextMenu() {
    ContextMenuController.removeAny();
  }

  /// テキスト選択を解除する（コンテキストメニューを消すため）
  void clearSelection() {
    // タイトル側
    if (_titleController.selection.baseOffset !=
        _titleController.selection.extentOffset) {
      _titleController.selection = TextSelection.collapsed(
          offset: _titleController.selection.extentOffset);
    }
    // 本文側
    if (_contentController.selection.baseOffset !=
        _contentController.selection.extentOffset) {
      _contentController.selection = TextSelection.collapsed(
          offset: _contentController.selection.extentOffset);
    }
  }

  /// IMEの変換中テキストを確定する（最大化/縮小前に呼ぶ）
  void commitIME() {
    // タイトル側のcomposing解除
    if (_titleController.value.composing != TextRange.empty) {
      _titleController.value = _titleController.value.copyWith(
        composing: TextRange.empty,
      );
    }
    // 本文側のcomposing解除
    if (_contentController.value.composing != TextRange.empty) {
      _contentController.value = _contentController.value.copyWith(
        composing: TextRange.empty,
      );
    }
  }

  // メモを閉じる: 入力欄をクリア + onClosed コールバック
  // MDモードはトグル操作以外で解除しない
  void _closeMemo() {
    FocusScope.of(context).unfocus();
    _clearInput(keepMarkdown: _isMarkdown);
    widget.onClosed();
  }

  // マークダウンモード切替
  void _toggleMarkdown(bool value) {
    _contentController.enabled = value;
    setState(() {
      _isMarkdown = value;
      _showMarkdownPreview = false;
    });
    _updateMdToolbarOverlay();
    // 既存メモならDBに反映
    if (widget.editingMemoId != null) {
      ref.read(databaseProvider).updateMemo(
            id: widget.editingMemoId!,
            isMarkdown: value,
          );
    }
    // トースト表示
    if (mounted) {
      showToast(context, value ? 'マークダウンモード オン' : 'マークダウンモード オフ',
          duration: const Duration(milliseconds: 1200));
    }
  }

  /// 本文だけを消す (消しゴムボタン): タイトル/タグはそのまま
  /// 公開: home_screen のフロート消しゴムから呼べるようにする
  Future<void> clearBody() async {
    if (_contentController.text.isEmpty) return;
    widget.onDialogOpenChanged?.call(true);
    try {
      final ok = await focusSafe(
        context,
        () => showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('本文をクリアします。よろしいですか？'),
            content: const Text('タイトルとタグはそのまま残ります。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('クリア'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || !mounted) return;
      _contentController.clear();
      _onChanged();
      setState(() {});
    } finally {
      if (mounted) widget.onDialogOpenChanged?.call(false);
    }
  }

  // 5万字到達ダイアログ (連射防止: 直近の表示から3秒以内は無視)
  DateTime? _lastLimitToastAt;
  void _showLimitReached() {
    final now = DateTime.now();
    if (_lastLimitToastAt != null &&
        now.difference(_lastLimitToastAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastLimitToastAt = now;
    if (!mounted) return;
    showFrostedAlert(
      context: context,
      title: '文字数の上限に達しました',
      message: '1メモあたり 50,000 文字までです',
    );
  }

  void _copyContent() {
    if (_contentController.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _contentController.text));
    showToast(context, '全文をコピーしました',
        duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    // 画面遷移やバックグラウンド化などで dispose される際、
    // タイトル・本文が空のメモは DB 上の痕跡を残さず削除する
    if (widget.editingMemoId != null &&
        _titleController.text.isEmpty &&
        _contentController.text.isEmpty) {
      final db = ref.read(databaseProvider);
      db.deleteMemo(widget.editingMemoId!); // fire-and-forget
    }
    _mdToolbarOverlay?.remove();
    _mdToolbarOverlay = null;
    _titleController.dispose();
    _contentController.dispose();
    _contentScrollController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 0, 2),
      // 通常は固定 316、最大化中は親のサイズに従う
      height: widget.isExpanded ? null : 316,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // メイン入力エリア（タグ選択時は親タグ色の枠に切り替わる）
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: _bgColorIndex == 0
                  ? Colors.white
                  : MemoBgColors.getColor(_bgColorIndex),
              borderRadius: BorderRadius.circular(CornerRadius.card),
              border: Border.all(
                color: const Color.fromRGBO(40, 40, 40, 0.55),
                width: 0.5,
              ),
              // \u30B7\u30E3\u30C9\u30A6\u306A\u3057\uFF08Swift\u7248\u6E96\u62E0\uFF09
            ),
            clipBehavior: Clip.hardEdge,
            child: GestureDetector(
              // ヘッダー/ツールバー等テキスト欄以外をタップしたらコンテキストメニューを消す + ルーレット閉じる
              onTap: () {
                _hideContextMenu();
                if (_rouletteOpen) _closeRoulette();
              },
              behavior: HitTestBehavior.translucent,
              child: Column(
              children: [
                _buildHeader(),
                Container(
                  height: 0.5,
                  color: const Color.fromRGBO(40, 40, 40, 0.5),
                ),
                _buildContent(),
                Container(
                  height: 0.5,
                  color: const Color.fromRGBO(40, 40, 40, 0.5),
                ),
                _buildToolbar(),
              ],
            ),
            ),
          ),
          // ルーレット（タグ欄の右端から出る。上端はタイトル欄下の仕切り線）
          // 下端は外側 AnimatedContainer の clip (y=316) で自然に収まる
          Positioned(
            right: 0,
            top: 40, // タイトル欄高さ 40
            bottom: widget.isExpanded ? null : 0,
            height: widget.isExpanded ? (316 - 35) : null,
            child: allTagsAsync.when(
              data: (allTags) => _buildRoulette(allTags),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ),
          // プレビューボタン（MD ON時のみ、入力エリア下端中央）
          if (_isMarkdown)
            Positioned(
              left: 0,
              right: 10, // AnimatedContainer の右margin と揃える
              bottom: 50, // フッター41 + 仕切り線1 + 余白8
              child: Center(child: _buildPreviewButton()),
            ),
          // ルーレット台形タブは非表示（タグ欄タップで開く）
        ],
      ),
    );
  }

  Widget _buildPreviewButton() {
    final isOn = _showMarkdownPreview;
    final color = isOn ? Colors.orange : Colors.grey.shade500;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_showMarkdownPreview) {
          FocusScope.of(context).unfocus();
        }
        setState(() => _showMarkdownPreview = !_showMarkdownPreview);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 1),
          color: Colors.white,
        ),
        child: Text(
          'プレビュー',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildEraserButton() {
    final hasContent = _contentController.text.isNotEmpty;
    final isFocusedOnContent = _contentFocusNode.hasFocus;
    return GestureDetector(
      onTap: hasContent ? clearBody : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (isFocusedOnContent && hasContent)
              ? Colors.orange.withValues(alpha: 0.6)
              : const Color.fromRGBO(142, 142, 147, 0.08),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 0.5,
              offset: const Offset(-0.5, 0.5),
            ),
          ],
        ),
        child: const EraserGlyph(),
      ),
    );
  }

  /// ルーレット構築
  Widget _buildRoulette(List<Tag> allTags) {
    final parentTags = allTags.where((t) => t.parentTagId == null).toList();
    final parentOptions = [
      const TagDialOption(id: null, name: 'タグなし', color: Colors.white),
      ...parentTags.map((t) => TagDialOption(
            id: t.id,
            name: t.name,
            color: TagColors.getColor(t.colorIndex),
          )),
    ];

    // 親タグID: 添付済み優先、未作成ならpending
    final parentId = _parentTag?.id;
    final childTags = parentId != null
        ? allTags.where((t) => t.parentTagId == parentId).toList()
        : <Tag>[];
    final childOptions = [
      const TagDialOption(id: null, name: '子タグなし', color: Colors.white),
      ...childTags.map((t) => TagDialOption(
            id: t.id,
            name: t.name,
            color: TagColors.getColor(t.colorIndex),
          )),
    ];

    // Swift版準拠: トレーは常に300pt幅、offset方式でスライド開閉
    const double trayBodyWidth = 300.0;
    const double tabW = 40.0; // 「タグ」テキストが収まる幅
    const double trayTotalWidth = trayBodyWidth + tabW;
    // ルーレットはみ出し量: 開き時27pt, 閉じ時42pt（Swift版準拠）
    final double dialOverhang = _rouletteOpen ? 60.0 : 55.0;
    // チラ見せ量（閉じ時にボディ左辺が覗く）
    const double peekAmount = 5.0;
    // 閉じ時: トレー全体を完全に隠す（タグ欄タップで開く）
    final slideOffset = _rouletteOpen ? 0.0 : trayTotalWidth + 60;

    return SizedBox(
      width: trayTotalWidth + 60, // 最大はみ出し分を確保
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(slideOffset, 0, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // トレー背景
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => _rouletteOpen ? _closeRoulette() : _openRoulette(),
                behavior: HitTestBehavior.opaque,
                child: CustomPaint(
                  painter: _rouletteOpen
                      ? _TrayWithTabPainter(
                          color: const Color.fromRGBO(142, 142, 147, 1),
                          tabWidth: tabW,
                          tabHeight: 22,
                          tabRadius: 6,
                          bodyRadius: 10,
                          innerRadius: 10,
                          bodyPeek: 0,
                        )
                      : _TrayClosedTabPainter(
                          color: const Color.fromRGBO(142, 142, 147, 1),
                          tabWidth: tabW + peekAmount,
                          tabHeight: 40,
                          tabNarrow: 28,
                          radius: 3,
                        ),
                  child: SizedBox(
                    width: trayTotalWidth,
                    child: Column(
                      children: [
                        // ラベル帯（展開時22pt、閉じ時は台形40pt）
                        SizedBox(
                          height: _rouletteOpen ? 22 : 40,
                          child: Stack(
                            children: [
                              // タブ上のラベル（閉じ時=◀ / 開き時=「タグ」）
                              if (!_rouletteOpen)
                                Positioned(
                                  left: 4,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Text(
                                      '\u25C0',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  width: tabW,
                                  height: 22,
                                  child: Center(
                                    child: Text(
                                      'Tag',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ),
                              // 親タグ・子タグラベル（上22ptの範囲に中央寄せ）
                              if (_rouletteOpen) ...[
                                Positioned(
                                  right: 231,
                                  top: 0,
                                  height: 22,
                                  child: Center(
                                    child: Text(
                                      '親',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 114,
                                  top: 0,
                                  height: 22,
                                  child: Center(
                                    child: Text(
                                      '子',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // 収納ボタン
                        Expanded(
                          child: _rouletteOpen
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _closeRoulette,
                                    child: Transform.translate(
                                      offset: const Offset(-8, 0),
                                      child: SizedBox(
                                        width: 36,
                                        child: Center(
                                          child: Text(
                                            '\u203A',
                                            style: TextStyle(
                                              fontSize: 60,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white.withValues(alpha: 0.5),
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(),
                        ),
                        // 下部ボタン（Swift版準拠: trailing揃え）
                        // 注: Stackの親サイズが小さいとヒットテストが効かないので
                        // ボタンが収まる高さを確保し、正のオフセットで配置する
                        SizedBox(
                          height: 36,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 親タグ追加
                              Positioned(
                                right: 191,
                                top: 0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _openAddParentTagSheet,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_circle, size: 14,
                                          color: Colors.white.withValues(alpha: 0.9)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '\u89AAタグ\u8FFD\u52A0',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // 子タグ追加
                              Positioned(
                                right: 78,
                                top: 0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _openAddChildTagSheet,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_circle_outline, size: 13,
                                          color: Colors.white.withValues(alpha: 0.8)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '\u5B50タグ\u8FFD\u52A0',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // 履歴ボタン（タグ追加より少し下）
                              Positioned(
                                right: 8,
                                top: 9,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _toggleTagHistory,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showTagHistory
                                            ? Icons.keyboard_arrow_down
                                            : Icons.chevron_right,
                                        size: 12,
                                        color: Colors.white.withValues(alpha: 0.8)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '\u5C65\u6B74',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ルーレット本体 + 影
            Positioned(
              right: 0,
              top: 22,
              bottom: 20,
              width: trayBodyWidth + 60,
              child: IgnorePointer(
                ignoring: !_rouletteOpen,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Transform.translate(
                    offset: Offset(-dialOverhang, _rouletteOpen ? 0 : -10),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _DialArcShadowPainter(dialHeight: 211),
                            ),
                          ),
                        ),
                        TagDialView(
                          height: 211,
                          parentOptions: parentOptions,
                          childOptions: childOptions,
                          selectedParentId: parentId,
                          selectedChildId: _childTag?.id,
                          isOpen: _rouletteOpen,
                          onParentSelected: (id) => _onTagSelected(id, false),
                          onChildSelected: (id) => _onTagSelected(id, true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTagSelected(String? id, bool isChild) async {
    final db = ref.read(databaseProvider);

    // 「タグなし」選択（id == null）→ タグを外す
    if (id == null) {
      if (widget.editingMemoId == null) {
        setState(() {
          if (!isChild) {
            _pendingParentTag = null;
            _pendingChildTag = null;
          } else {
            _pendingChildTag = null;
          }
        });
      } else {
        if (!isChild) {
          // 親タグを全て外す → 子タグも外す
          for (final tag in _attachedTags) {
            await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
          }
        } else {
          // 子タグだけ外す
          for (final tag in _attachedTags.where((t) => t.parentTagId != null)) {
            await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
          }
        }
        _attachedTags = await db.getTagsForMemo(widget.editingMemoId!);
      }
      _pushUndoIfChanged();
      if (mounted) setState(() {});
      return;
    }

    // タグの実体を取得（pending保持用）
    final allTags = ref.read(allTagsProvider).value ?? const <Tag>[];
    Tag? selectedTag;
    for (final t in allTags) {
      if (t.id == id) {
        selectedTag = t;
        break;
      }
    }
    selectedTag ??= await db.getTagById(id);
    if (selectedTag == null) return;

    // メモ未作成の場合は pending に保持するだけ
    if (widget.editingMemoId == null) {
      setState(() {
        if (!isChild) {
          _pendingParentTag = selectedTag;
          // 親を変えたら子はリセット
          _pendingChildTag = null;
        } else {
          _pendingChildTag = selectedTag;
        }
      });
      _pushUndoIfChanged();
      return;
    }

    // メモ作成済みの場合はDBに反映
    if (!isChild) {
      // 親タグ変更: 既存の親タグを外す
      for (final tag in _attachedTags.where((t) => t.parentTagId == null)) {
        await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
      }
      // 子タグもリセット（親が変わったので）
      for (final tag in _attachedTags.where((t) => t.parentTagId != null)) {
        await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
      }
      await db.addTagToMemo(widget.editingMemoId!, id);
    } else {
      for (final tag in _attachedTags.where((t) => t.parentTagId != null)) {
        await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
      }
      await db.addTagToMemo(widget.editingMemoId!, id);
    }
    _attachedTags = await db.getTagsForMemo(widget.editingMemoId!);
    _pushUndoIfChanged();
    setState(() {});
  }

  /// ルーレットを開く（収納時のみ）
  void _openRoulette() {
    if (_rouletteOpen) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _rouletteOpen = true;
      _showTagHistory = false;
    });
    widget.onTagHistoryChanged?.call();
  }

  /// ルーレットを閉じる（タグ履歴を記録）
  void _closeRoulette() {
    if (!_rouletteOpen) return;
    // タグが選択されていたら履歴に記録
    final parentId = _parentTag?.id;
    if (parentId != null) {
      final db = ref.read(databaseProvider);
      db.recordTagHistory(parentId, childTagId: _childTag?.id);
    }
    setState(() {
      _rouletteOpen = false;
      _showTagHistory = false;
    });
    widget.onTagHistoryChanged?.call();
  }

  // タグ履歴の表示フラグ
  bool _showTagHistory = false;
  List<TagHistory> _tagHistoryItems = [];

  /// 履歴表示トグル
  Future<void> _toggleTagHistory() async {
    if (_showTagHistory) {
      setState(() => _showTagHistory = false);
    } else {
      final db = ref.read(databaseProvider);
      final items = await db.getRecentTagHistory();
      setState(() {
        _tagHistoryItems = items;
        _showTagHistory = true;
      });
    }
    widget.onTagHistoryChanged?.call();
  }

  /// 履歴からタグを選択
  Future<void> _selectFromHistory(TagHistory item) async {
    final db = ref.read(databaseProvider);
    // 親タグを選択
    await _onTagSelected(item.parentTagId, false);
    // 子タグがあれば選択
    if (item.childTagId != null) {
      await _onTagSelected(item.childTagId!, true);
    }
    setState(() => _showTagHistory = false);
    widget.onTagHistoryChanged?.call();
  }

  /// 親タグ追加シートを開く
  Future<void> _openAddParentTagSheet() async {
    FocusScope.of(context).unfocus();
    final newTagId = await NewTagSheet.show(context: context);
    if (newTagId == null) return;
    // 作成直後にそのタグを選択状態にする
    await _onTagSelected(newTagId, false);
  }

  /// 子タグ追加シートを開く（親タグ未選択時は警告ダイアログ）
  Future<void> _openAddChildTagSheet() async {
    FocusScope.of(context).unfocus();
    final parentId = _parentTag?.id;
    if (parentId == null) {
      if (!mounted) return;
      await showFrostedAlert(
        context: context,
        title: '親タグを選んでください',
        message: '子タグを追加するには、先にルーレットで親タグを選択してください。',
      );
      return;
    }
    final newTagId = await NewTagSheet.show(
      context: context,
      parentTagId: parentId,
    );
    if (newTagId == null) return;
    await _onTagSelected(newTagId, true);
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxTagWidth = screenWidth * 0.40;

    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // タイトル欄（残りスペースを使う）
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Stack(
                    children: [
                      // 常にTextFieldを配置（フォーカス時に見える）
                      Opacity(
                        opacity: _titleFocusNode.hasFocus ? 1.0 : 0.0,
                        child: TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          onChanged: (_) => _onChanged(),
                          readOnly: _isViewMode,
                          contextMenuBuilder: TextMenuDismisser.builder,
                          onTap: TextMenuDismisser.wrap(_isViewMode
                              ? () => _enterEditMode(
                                  focusContent: false, focusTitle: true)
                              : null),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PingFang JP',
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            // プレースホルダーはフォーカス時に出さず、
                            // 非フォーカス時のTextオーバーレイのみで見せる
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                          maxLines: 1,
                        ),
                      ),
                      // 非フォーカス時: Textで省略表示（TextFieldと同じ位置に重ねる）
                      if (!_titleFocusNode.hasFocus)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              if (_isViewMode) {
                                _enterEditMode(
                                    focusContent: false, focusTitle: true);
                              } else {
                                _titleFocusNode.requestFocus();
                              }
                            },
                            child: Container(
                              color: Colors.transparent,
                              // TextField(isDense + contentPadding vertical:4)は
                              // 実際にはテキストを中央寄せで描画するため centerLeft
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _titleController.text.isEmpty
                                    ? '\u30BF\u30A4\u30C8\u30EB\uFF08\u4EFB\u610F\uFF09'
                                    : _titleController.text,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'PingFang JP',
                                  color: _titleController.text.isEmpty
                                      ? Colors.grey.withValues(alpha: 0.4)
                                      : Colors.black87,
                                ),
                                // TextFieldと同じ行高メトリクスに揃える
                                strutStyle: const StrutStyle(
                                  fontSize: 17,
                                  fontFamily: 'PingFang JP',
                                  forceStrutHeight: true,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // タイトル×ボタン
                if (_titleController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _titleController.clear();
                      _onChanged();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(CupertinoIcons.xmark_circle_fill, size: 16,
                          color: Colors.grey.withValues(alpha: 0.35)),
                    ),
                  ),
              ],
            ),
          ),
          // 縦線セパレータ
          Container(
            width: 0.5,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color.fromRGBO(40, 40, 40, 0.5),
          ),
          // タグ表示エリア
          if (_parentTag == null)
            // タグ未選択: アイコンのみ（大きく太く目立たせる）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openRoulette,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const Icon(Icons.sell, size: 20,
                    color: Color.fromRGBO(142, 142, 147, 0.6)),
              ),
            )
          else
            // タグ選択済: 中身に合わせて可変、最大幅40%で制限
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openRoulette,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTagWidth),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(child: _buildTagDisplay()),
                      const SizedBox(width: 2),
                      // タグ×ボタン
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          _pendingParentTag = null;
                          _pendingChildTag = null;
                          if (widget.editingMemoId != null) {
                            final db = ref.read(databaseProvider);
                            for (final tag in _attachedTags) {
                              await db.removeTagFromMemo(
                                  widget.editingMemoId!, tag.id);
                            }
                            _attachedTags = await db
                                .getTagsForMemo(widget.editingMemoId!);
                          }
                          if (mounted) setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.cancel,
                              size: 16,
                              color: Colors.grey.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 親タグ＋子タグの重ね合わせ表示（Swift版 tagDisplay 準拠）
  Widget _buildTagDisplay() {
    final parent = _parentTag!;
    final child = _childTag;
    final parentColor = TagColors.getColor(parent.colorIndex);
    final screenWidth = MediaQuery.of(context).size.width;
    // 親タグ・子タグそれぞれの最大幅（長いタグ名で片方が押し出されないように）
    final maxParentTagWidth = screenWidth * 0.18;
    final maxChildTagWidth = screenWidth * 0.14;

    if (child != null) {
      final childColor = TagColors.getColor(child.colorIndex);
      // 親タグと子タグを4ptめり込ませる（本家 HStack(spacing: -4) 準拠）
      final parentWidget = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxParentTagWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          decoration: BoxDecoration(
            color: parentColor,
            borderRadius: BorderRadius.circular(CornerRadius.badge),
          ),
          child: Text(
            parent.name,
            style: _parentTagTextStyle,
            strutStyle: _parentStrutStyle,
            textHeightBehavior: _tightHeightBehavior,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      final childWidget = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxChildTagWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: childColor,
            borderRadius: BorderRadius.circular(CornerRadius.badge),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            child.name,
            style: _childTagTextStyle,
            strutStyle: _childStrutStyle,
            textHeightBehavior: _tightHeightBehavior,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      // IntrinsicHeight + Row で bottom-align、子タグを -4pt マージンで重ねる
      return IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            parentWidget,
            Transform.translate(
              offset: const Offset(-4, 1.5),
              child: childWidget,
            ),
          ],
        ),
      );
    }

    // 親タグのみ（子タグなしなら少し広めに使える）
    final maxParentOnly = screenWidth * 0.35;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxParentOnly),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: parentColor,
          borderRadius: BorderRadius.circular(CornerRadius.badge),
        ),
        child: Text(
          parent.name,
          style: _parentTagTextStyle,
          strutStyle: _parentStrutStyle,
          textHeightBehavior: _tightHeightBehavior,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // タグバッジ用のテキストスタイル（SF Pro Rounded、行高1.0で中央寄せ）
  static const TextStyle _parentTagTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: '.SF Pro Rounded',
    fontFamilyFallback: ['SF Pro Rounded', 'Hiragino Sans'],
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
    color: Colors.black,
  );

  static const TextStyle _childTagTextStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    fontFamily: '.SF Pro Rounded',
    fontFamilyFallback: ['SF Pro Rounded', 'Hiragino Sans'],
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
    color: Colors.black,
  );

  static const StrutStyle _parentStrutStyle = StrutStyle(
    fontSize: 11,
    height: 1.0,
    forceStrutHeight: true,
    leading: 0,
  );

  static const StrutStyle _childStrutStyle = StrutStyle(
    fontSize: 10,
    height: 1.0,
    forceStrutHeight: true,
    leading: 0,
  );

  static const TextHeightBehavior _tightHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
    leadingDistribution: TextLeadingDistribution.even,
  );

  Widget _buildContent() {
    // プレビューモード: マークダウン描画を表示（タップでエディタに戻す）
    if (_isMarkdown && _showMarkdownPreview) {
      return Flexible(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _showMarkdownPreview = false);
            _enterEditMode(focusContent: true);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 20),
            child: MarkdownBody(
              data: _contentController.text.isEmpty
                  ? '*タップで編集に戻る*'
                  : _contentController.text,
              selectable: false,
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                h2: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                h3: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                p: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
                listBullet: const TextStyle(fontSize: 16),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                ),
                code: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: Colors.grey[700],
                  backgroundColor: Colors.grey[100],
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // エディタモード
    // ToDoリストと同じパターン: 外側にScrollable、TextFieldはexpandsなし
    // 最大化時のみ、キーボード分の余白を確保してカーソルがキーボード上に来るよう
    // スクロールさせる。縮小時(316固定)は枠が小さいので、キーボード対策が強すぎると
    // テキストが上に吹き飛ぶ → 縮小時は固定値のみ使う。
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final cursorBottomBuffer =
        widget.isExpanded && kb > 0 ? kb - 10 : 20;
    // viewInsetsの変化をコンテンツ領域に伝播させない
    // （キーボード開閉アニメ中の毎フレームrebuildによるガタつきを防止）
    // カーソル追従はscrollPaddingで十分対応できる
    return Flexible(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
        child: LayoutBuilder(builder: (context, constraints) {
        // Overlay更新（キーボード高さ変化に対応）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateMdToolbarOverlay();
        });
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isViewMode) {
              _enterEditMode(focusContent: true);
            } else {
              _contentFocusNode.requestFocus();
            }
            if (_rouletteOpen) _closeRoulette();
          },
          child: SingleChildScrollView(
            controller: _contentScrollController,
            padding: EdgeInsets.fromLTRB(9, 9, 9,
                widget.isExpanded && !_isViewMode ? 400 : 100),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 100)
                    .clamp(0.0, double.infinity),
              ),
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                onChanged: (_) => _onChanged(),
                readOnly: _isViewMode,
                onTap: TextMenuDismisser.wrap(() {
                  if (_isViewMode) {
                    _enterEditMode(focusContent: true);
                  }
                  if (_rouletteOpen) _closeRoulette();
                }),
                inputFormatters: [
                  _LimitWithToastFormatter(
                    maxLength: _maxContentLength,
                    onLimit: _showLimitReached,
                  ),
                ],
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'PingFang JP',
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  // フォーカス時はプレースホルダー非表示（空で抜けたら再表示）
                  hintText: _contentFocusNode.hasFocus
                      ? null
                      : _isMarkdown
                          ? 'タップでマークダウン編集...'
                          : 'メモを入力...',
                  border: InputBorder.none,
                  hintStyle:
                      TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                contextMenuBuilder: TextMenuDismisser.builder,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                scrollPadding:
                    EdgeInsets.only(bottom: cursorBottomBuffer.toDouble()),
              ),
            ),
          ),
        );
      }),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      constraints: const BoxConstraints(minHeight: 41),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          Builder(builder: (_) {
            final hasReal = _contentController.text.isNotEmpty ||
                _titleController.text.isNotEmpty;
            return GestureDetector(
              onTap: hasReal ? _confirmDeleteMemo : null,
              child: Icon(CupertinoIcons.delete_simple,
                  size: 20,
                  color: hasReal
                      ? Colors.red.withValues(alpha: 0.5)
                      : Colors.grey.shade300),
            );
          }),
          const SizedBox(width: 14),
          // MD (縦並び: 上ラベル + 下スイッチ)
          // Column全体をタップ領域にして、テキスト部分タップでもトグル動作
          GestureDetector(
            onTap: () => _toggleMarkdown(!_isMarkdown),
            behavior: HitTestBehavior.opaque,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('MD',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: _isMarkdown
                        ? const Color(0xFF007AFF)
                        : Colors.grey[600],
                  )),
              const SizedBox(height: 2),
              Transform.scale(
                scale: 0.55,
                child: SizedBox(
                  width: 34,
                  height: 20,
                  child: Switch.adaptive(
                    value: _isMarkdown,
                    onChanged: (v) => _toggleMarkdown(v),
                    activeColor: const Color(0xFF007AFF),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(width: 14),
          // 多機能メニュー（エクスポート/HTML化など、タップ動作は後で実装）
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // TODO: 多機能メニュー展開
            },
            child: Icon(CupertinoIcons.ellipsis_circle,
                size: 20, color: Colors.grey[600]),
          ),
          const SizedBox(width: 14),
          // 背景色変更
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showBgColorPicker,
            child: Icon(Icons.palette_outlined,
                size: 20, color: Colors.grey[600]),
          ),
          const SizedBox(width: 14),
          // コピー (アイコンのみ、パレットと同色)
          Builder(builder: (_) {
            final hasRealContent = _contentController.text.isNotEmpty;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasRealContent ? _copyContent : null,
              child: Icon(
                CupertinoIcons.doc_on_doc,
                size: 20,
                color: hasRealContent
                    ? Colors.grey[600]
                    : Colors.grey.shade400,
              ),
            );
          }),
          const Spacer(),
          // Undo (Material版: weight 指定で太く)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _canUndo ? _undo : null,
            child: Icon(
              Icons.undo,
              size: 22,
              weight: 700,
              color: _canUndo
                  ? const Color(0xFF007AFF)
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 24),
          // Redo (Material版: weight 指定で太く)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _canRedo ? _redo : null,
            child: Icon(
              Icons.redo,
              size: 22,
              weight: 700,
              color: _canRedo
                  ? const Color(0xFF007AFF)
                  : Colors.grey.shade400,
            ),
          ),
          const Spacer(),
          // フォーカス中: 確定 (キーボード閉じるだけ) — 実質文字がある場合のみ有効
          // 非フォーカス + メモ/タイトルあり: 閉じる (クリア)
          // 確定 or 閉じる (他のアイコン位置を安定させるため「閉じる」幅で固定)
          SizedBox(
            width: 72,
            child: _isInputFocused
                ? Builder(builder: (_) {
                    final hasReal = _contentController.text.isNotEmpty ||
                        _titleController.text.isNotEmpty;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: hasReal ? _confirm : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_circle,
                            size: 18,
                            color: hasReal
                                ? const Color(0xFF007AFF)
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '確定',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: hasReal
                                  ? const Color(0xFF007AFF)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                : (_hasMemo || _titleController.text.isNotEmpty)
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeMemo,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              CupertinoIcons.xmark_circle,
                              size: 18,
                              color: Color(0xFF007AFF),
                            ),
                            SizedBox(width: 3),
                            Text(
                              '閉じる',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          // 最大化/縮小トグル（右端）
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () {
              commitIME();
              widget.onToggleExpanded?.call();
            },
            behavior: HitTestBehavior.opaque,
            child: Icon(
              widget.isExpanded ? Icons.zoom_in_map : Icons.zoom_out_map,
              size: 24,
              color: Colors.black87,
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
    // MDモードはトグル操作以外で解除しない
    _clearInput(keepMarkdown: _isMarkdown);
    widget.onClosed();
  }

  /// 背景色選択ダイアログ
  /// 既存メモならDB更新、未作成なら _bgColorIndex に保持して次のメモ作成時に適用
  Future<void> _showBgColorPicker() async {
    final memoId = widget.editingMemoId;
    final wasEditing = _isInputFocused;
    if (wasEditing) widget.onDialogOpenChanged?.call(true);
    try {
      final selected = await focusSafe(
        context,
        () => showDialog<int>(
          context: context,
          builder: (ctx) => _BgColorPickerDialog(current: _bgColorIndex),
        ),
      );
      if (selected == null || !mounted) return;
      setState(() => _bgColorIndex = selected);
      if (memoId != null) {
        await ref
            .read(databaseProvider)
            .updateMemo(id: memoId, bgColorIndex: selected);
      }
    } finally {
      if (mounted && wasEditing) widget.onDialogOpenChanged?.call(false);
    }
  }

  /// 削除確認ダイアログ → 削除（本家準拠）
  /// 編集中のみフォルダビュー非表示フラグを立てる（閲覧時はフォルダを維持）
  Future<void> _confirmDeleteMemo() async {
    final wasEditing = _isInputFocused;
    if (wasEditing) widget.onDialogOpenChanged?.call(true);
    try {
      final confirmed = await focusSafe(
        context,
        () => showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('このメモを削除します。よろしいですか?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('削除'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      _deleteMemo();
    } finally {
      if (mounted && wasEditing) widget.onDialogOpenChanged?.call(false);
    }
  }
}

// 消しゴムグリフ: CustomPainterで斜めの長方形を描く
// (Material Icons に eraser がないため自前)
/// 背景色選択ダイアログ
/// 8×4 パレット（31色 + 色なし）/ 色名 / サンプルパネル / 決定・キャンセル
class _BgColorPickerDialog extends StatefulWidget {
  final int current;
  const _BgColorPickerDialog({required this.current});

  @override
  State<_BgColorPickerDialog> createState() => _BgColorPickerDialogState();
}

class _BgColorPickerDialogState extends State<_BgColorPickerDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final sampleBg =
        _selected == 0 ? Colors.white : MemoBgColors.getColor(_selected);
    final name = MemoBgColors.getName(_selected);

    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // タイトル（中央寄せ）
            const Center(
              child: Text('背景色',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            // パレット左上に色名
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 4),
            // パレット (8列 × 4行 = 32マス、末尾が「色なし」)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 32,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                mainAxisExtent: 30,
              ),
              itemBuilder: (_, i) {
                // 最後のマスは「色なし」（index 0）
                final isNone = i == MemoBgColors.count;
                final index = isNone ? 0 : i + 1;
                final isSelected = index == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isNone
                          ? Colors.white
                          : MemoBgColors.getColor(index),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : (isNone
                                ? Colors.grey.shade300
                                : Colors.transparent),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isNone
                        ? Icon(Icons.block,
                            size: 14, color: Colors.grey[500])
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // サンプルパネル（シンプルに「サンプル」だけ）
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: sampleBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.grey.shade300, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'サンプル',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 決定・キャンセル（横長均等）
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: Colors.grey.shade700,
                      backgroundColor: Colors.grey.shade100,
                    ),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF007AFF),
                    ),
                    child: const Text('決定',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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

class EraserGlyph extends StatelessWidget {
  const EraserGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: EraserPainter(),
    );
  }
}

class EraserPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(0.8); // 枠に対して一回り小さく
    canvas.rotate(0.785); // +45度

    final sleeve = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-5, -7, 10, 11),
      const Radius.circular(1.2),
    );
    final tip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-4.5, 4, 9, 4),
      const Radius.circular(0.8),
    );

    // 線画のみ (本家準拠: シンプルな白線)
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white;
    canvas.drawRRect(sleeve, line);
    canvas.drawRRect(tip, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 文字数上限フォーマッタ。超過時は LengthLimitingTextInputFormatter と同じく
// 末尾を切り捨て、合わせて onLimit を呼んでトーストなどで通知
class _LimitWithToastFormatter extends TextInputFormatter {
  final int maxLength;
  final VoidCallback onLimit;
  _LimitWithToastFormatter({required this.maxLength, required this.onLimit});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.characters.length > maxLength) {
      onLimit();
      // 末尾を切り捨て (グラフィムクラスタ単位)
      final truncated =
          newValue.text.characters.take(maxLength).toString();
      return TextEditingValue(
        text: truncated,
        selection: TextSelection.collapsed(offset: truncated.length),
      );
    }
    return newValue;
  }
}

// 入力欄のUndo/Redo履歴1スナップショット
class _InputSnapshot {
  final String title;
  final String content;
  final String? parentTagId;
  final String? childTagId;
  const _InputSnapshot({
    required this.title,
    required this.content,
    required this.parentTagId,
    required this.childTagId,
  });

  @override
  bool operator ==(Object other) =>
      other is _InputSnapshot &&
      other.title == title &&
      other.content == content &&
      other.parentTagId == parentTagId &&
      other.childTagId == childTagId;

  @override
  int get hashCode => Object.hash(title, content, parentTagId, childTagId);
}

/// 開き時: 台形タブがトレー本体の左上から左に飛び出す
///
///      ___
///     /   |
///    /    |──────────────┐
///   /     |  トレー本体    |
///   \     |              |
///    \    |──────────────┘
///     \___|
///
/// 台形の右上頂点 = トレー本体の左上頂点
class _TrayWithTrapezoidTabPainter extends CustomPainter {
  final Color color;
  final double tabWidth;    // 台形の横幅（左への飛び出し量）
  final double tabHeight;   // 台形の右辺（底辺）高さ = 40
  final double tabNarrow;   // 台形の左辺（先端）高さ = 28
  final double tabRadius;   // 台形の角丸
  final double bodyRadius;  // 本体の左下角丸

  _TrayWithTrapezoidTabPainter({
    required this.color,
    required this.tabWidth,
    required this.tabHeight,
    required this.tabNarrow,
    required this.tabRadius,
    required this.bodyRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = (tabHeight - tabNarrow) / 2;
    // 本体左辺X = tabWidth（台形の右辺位置）
    final bodyLeftX = tabWidth;
    // ベジェ曲線の制御点オフセット（先端の丸み具合）
    const r = 4.0;

    // 斜辺の傾き: inset / bodyLeftX
    final slope = inset / bodyLeftX;
    // ベジェ終点を斜辺の延長線上に置く
    final bx = r;
    final by = inset - bx * slope;

    final path = Path();

    // 台形先端の上: ベジェ曲線で滑らかに角を丸める
    path.moveTo(0, inset + r);
    path.quadraticBezierTo(0, inset, bx, by);

    // 台形上辺の斜辺 → 本体の左上頂点
    path.lineTo(bodyLeftX, 0);

    // 本体上辺 → 右上
    path.lineTo(size.width, 0);

    // 右辺（下まで）
    path.lineTo(size.width, size.height);

    // 本体下辺 → 左下角丸
    path.lineTo(bodyLeftX + bodyRadius, size.height);
    path.arcTo(
      Rect.fromLTWH(bodyLeftX, size.height - bodyRadius * 2,
          bodyRadius * 2, bodyRadius * 2),
      pi / 2, pi / 2, false,
    );

    // 本体左辺（台形下端まで）
    path.lineTo(bodyLeftX, tabHeight);

    // 台形下辺の斜辺 → 先端下: ベジェ曲線で滑らかに（対称）
    path.lineTo(bx, tabHeight - inset + bx * slope);
    path.quadraticBezierTo(0, tabHeight - inset, 0, tabHeight - inset - r);

    path.close();

    // シャドウ
    canvas.save();
    canvas.translate(-2, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrayWithTrapezoidTabPainter old) =>
      old.color != color;
}

class _TrayWithTabPainter extends CustomPainter {
  final Color color;
  final double tabWidth;
  final double tabHeight;
  final double tabRadius;
  final double bodyRadius;
  final double innerRadius;
  final double bodyPeek;

  _TrayWithTabPainter({
    required this.color,
    required this.tabWidth,
    required this.tabHeight,
    required this.tabRadius,
    required this.bodyRadius,
    required this.innerRadius,
    this.bodyPeek = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyTop = tabHeight;
    final bodyLeftX = tabWidth - bodyPeek;
    final ir = innerRadius.clamp(0.0, bodyTop);

    final path = Path();

    path.moveTo(0, tabRadius);
    path.arcTo(
      Rect.fromLTWH(0, 0, tabRadius * 2, tabRadius * 2),
      pi, pi / 2, false,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);

    path.lineTo(bodyLeftX + bodyRadius, size.height);
    path.arcTo(
      Rect.fromLTWH(bodyLeftX, size.height - bodyRadius * 2, bodyRadius * 2, bodyRadius * 2),
      pi / 2, pi / 2, false,
    );

    path.lineTo(bodyLeftX, bodyTop + ir);

    path.arcTo(
      Rect.fromLTWH(bodyLeftX - ir * 2, bodyTop, ir * 2, ir * 2),
      0, -pi / 2, false,
    );

    path.lineTo(tabRadius, bodyTop);

    path.arcTo(
      Rect.fromLTWH(0, bodyTop - tabRadius * 2, tabRadius * 2, tabRadius * 2),
      pi / 2, pi / 2, false,
    );

    path.close();

    canvas.save();
    canvas.translate(-2, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrayWithTabPainter old) =>
      old.color != color;
}

/// 閉じ時の台形タブ: 右辺=タグ欄高さ(40pt)、左辺=少し狭く(28pt)、角丸
/// 台形タブの形状でhit testを切り抜くClipper
class _TrapezoidClipper extends CustomClipper<Path> {
  final double tabWidth;
  final double tabHeight;
  final double tabNarrow;

  _TrapezoidClipper({
    required this.tabWidth,
    required this.tabHeight,
    required this.tabNarrow,
  });

  @override
  Path getClip(Size size) {
    final inset = (tabHeight - tabNarrow) / 2;
    return Path()
      ..moveTo(0, inset)
      ..lineTo(tabWidth, 0)
      ..lineTo(tabWidth, tabHeight)
      ..lineTo(0, tabHeight - inset)
      ..close();
  }

  @override
  bool shouldReclip(covariant _TrapezoidClipper oldClipper) => false;
}

class _TrayClosedTabPainter extends CustomPainter {
  final Color color;
  final double tabWidth;   // 台形の横幅
  final double tabHeight;  // 右辺（底辺）の高さ = タグ欄の高さ
  final double tabNarrow;  // 左辺（先端）の高さ
  final double radius;     // 角丸半径

  _TrayClosedTabPainter({
    required this.color,
    required this.tabWidth,
    required this.tabHeight,
    required this.tabNarrow,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = (tabHeight - tabNarrow) / 2;
    const r = 4.0;
    final slope = inset / tabWidth;
    final bx = r;
    final by = inset - bx * slope;

    final path = Path();
    // 左上（先端上）: ベジェ曲線で滑らかに
    path.moveTo(0, inset + r);
    path.quadraticBezierTo(0, inset, bx, by);
    // 右上
    path.lineTo(tabWidth, 0);
    // 右辺
    path.lineTo(tabWidth, tabHeight);
    // 左下（先端下）: ベジェ曲線で滑らかに（対称）
    path.lineTo(bx, tabHeight - inset + bx * slope);
    path.quadraticBezierTo(0, tabHeight - inset, 0, tabHeight - inset - r);
    path.close();

    // シャドウ
    canvas.save();
    canvas.translate(-2, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrayClosedTabPainter old) =>
      old.color != color || old.tabHeight != tabHeight;
}

class _DialArcShadowPainter extends CustomPainter {
  final double dialHeight;
  static const double radius = 350;

  _DialArcShadowPainter({required this.dialHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = radius + 2;
    final cy = dialHeight / 2;
    final maxSin = min(1.0, (cy + 4) / radius);
    final maxAngle = asin(maxSin);

    final arcPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        pi - maxAngle,
        maxAngle * 2,
      )
      ..close();

    canvas.save();
    canvas.translate(-2, 0);
    canvas.drawPath(
      arcPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DialArcShadowPainter old) => false;
}
