import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import 'frosted_alert_dialog.dart';
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
  });

  @override
  ConsumerState<MemoInputArea> createState() => MemoInputAreaState();
}

class MemoInputAreaState extends ConsumerState<MemoInputArea> {
  /// 外部から本文の有無を確認するゲッター
  bool get hasContent => _contentController.text.isNotEmpty;
  /// 外部から本文フォーカス状態を確認するゲッター
  bool get isContentFocused => _contentFocusNode.hasFocus;
  /// タグ履歴が表示中か
  bool get showTagHistory => _showTagHistory;
  /// タグ履歴アイテム
  List<TagHistory> get tagHistoryItems => _tagHistoryItems;
  /// 履歴からタグを選択（外部から呼べる）
  Future<void> selectFromHistory(TagHistory item) => _selectFromHistory(item);
  /// 履歴パネルを閉じる
  void closeTagHistory() => setState(() => _showTagHistory = false);

  // コンテキストメニュー表示タイミング記録（長押し直後のタップで消さないため）
  DateTime? _lastContextMenuShown;

  // 本文の最大文字数（Swift版準拠）
  static const int _maxContentLength = 50000;
  // Undo/Redo履歴の最大段数
  static const int _maxUndoSnapshots = 50;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  bool get _isInputFocused =>
      _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;
  List<Tag> _attachedTags = [];
  bool _hasMemo = false;
  bool _rouletteOpen = false;
  // 閲覧モード: 既存メモをカードからタップして開いた直後はキーボードを出さず
  // テキストを表示するだけ。本文/タイトルをタップすると編集モードへ遷移 (本家準拠)
  bool _isViewMode = false;
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

  @override
  void initState() {
    super.initState();
    _resetUndoHistory();
    _titleFocusNode.addListener(_onFocusChange);
    _contentFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MemoInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMemoId != oldWidget.editingMemoId) {
      if (widget.editingMemoId != null) {
        // 自分で作成したメモなら再ロード不要（閲覧モードにしない）
        if (widget.editingMemoId == _selfCreatedMemoId) {
          _selfCreatedMemoId = null;
        } else {
          _loadMemo(widget.editingMemoId!);
        }
      } else {
        _clearInput();
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
      _suppressUndo = true;
      _titleController.text = memo.title;
      _contentController.text = memo.content;
      _attachedTags = await db.getTagsForMemo(id);
      _suppressUndo = false;
      _resetUndoHistory();
      setState(() {
        _hasMemo = true;
        _isViewMode = true; // カードから開いたら最初は閲覧モード
      });
    }
  }

  void _clearInput() {
    _suppressUndo = true;
    _titleController.clear();
    _contentController.clear();
    _attachedTags = [];
    _pendingParentTag = null;
    _pendingChildTag = null;
    _suppressUndo = false;
    _resetUndoHistory();
    setState(() {
      _hasMemo = false;
      _isViewMode = false;
    });
  }

  // 閲覧モードを抜けて編集モードへ。本文タップ等から呼ばれる
  void _enterEditMode({bool focusContent = true, bool focusTitle = false}) {
    setState(() => _isViewMode = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (focusTitle) _titleFocusNode.requestFocus();
      if (focusContent) _contentFocusNode.requestFocus();
    });
  }

  /// 入力内容を即座に保存
  void _onChanged() {
    _pushUndoIfChanged();
    if (widget.editingMemoId == null) {
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
    if (mounted) setState(() {}); // Undo/Redoボタンの状態更新用
  }

  // 自分で作成したメモのID（_loadMemoで閲覧モードにしないため）
  String? _selfCreatedMemoId;

  Future<void> _createAndSave() async {
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo(
      title: _titleController.text,
      content: _contentController.text,
    );
    // pending（ルーレットで先に選んだタグ）を優先、無ければwidgetから渡されたタブのタグを使う
    final parentId = _pendingParentTag?.id ?? widget.selectedParentTagId;
    final childId = _pendingChildTag?.id ?? widget.selectedChildTagId;
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
    setState(() => _hasMemo = true);
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
  void _closeMemo() {
    FocusScope.of(context).unfocus();
    _clearInput();
    widget.onClosed();
  }

  /// 本文だけを消す (消しゴムボタン): タイトル/タグはそのまま
  /// 公開: home_screen のフロート消しゴムから呼べるようにする
  Future<void> clearBody() async {
    if (_contentController.text.isEmpty) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('本文を全て消します'),
        content: const Text('本文をクリアします。タイトルとタグはそのままです。'),
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
    );
    if (ok != true || !mounted) return;
    _contentController.clear();
    _onChanged();
    setState(() {});
  }

  // 5万字到達トースト (連射防止: 直近の表示から3秒以内は無視)
  DateTime? _lastLimitToastAt;
  void _showLimitReached() {
    final now = DateTime.now();
    if (_lastLimitToastAt != null &&
        now.difference(_lastLimitToastAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastLimitToastAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 2000),
        content: Text('1メモあたり 50,000 文字までです'),
      ),
    );
  }

  void _copyContent() {
    if (_contentController.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _contentController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1200),
        content: Text('コピーしました'),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(CornerRadius.card),
              border: Border.all(
                color: _parentTag != null
                    ? TagColors.getColor(_parentTag!.colorIndex)
                        .withValues(alpha: 0.5)
                    : const Color.fromRGBO(142, 142, 147, 0.4),
                width: _parentTag != null ? 2.5 : 1.5,
              ),
              // \u30B7\u30E3\u30C9\u30A6\u306A\u3057\uFF08Swift\u7248\u6E96\u62E0\uFF09
            ),
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
                  height: 1,
                  color: const Color.fromRGBO(142, 142, 147, 0.35),
                ),
                _buildContent(),
                Container(
                  height: 1,
                  color: const Color.fromRGBO(142, 142, 147, 0.35),
                ),
                _buildToolbar(),
              ],
            ),
            ),
          ),
          // ルーレット（タグ欄の右端から出る。top: 0、bottom: フッター上端）
          Positioned(
            right: 0,
            top: 0,
            bottom: widget.isExpanded ? null : 35, // フッター34 + 仕切り線1
            height: widget.isExpanded ? (316 - 35) : null,
            child: allTagsAsync.when(
              data: (allTags) => _buildRoulette(allTags),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ),
          // 消しゴムボタン (本文左下、常に表示)
          Positioned(
            left: 6,
            bottom: 40,
            child: _buildEraserButton(),
          ),
          // 最大化/縮小ボタン (入力欄の右下角ぴったり、常に表示)
          if (!_rouletteOpen)
            Positioned(
              right: 14, // 入力欄の margin(10) + 4px 内側
              bottom: 40,
              child: _buildExpandButton(),
            ),
          // 台形タブ閉じ時のタップ受付（ルーレット内に開き時の受付がある）
          if (!_rouletteOpen)
            Positioned(
              right: 0,
              top: 0,
              width: 24,
              height: 40,
              child: GestureDetector(
                onTap: _openRoulette,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
        ],
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

  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: () {
        // 変換中のIMEをコミットしてからトグル（下線残りバグ防止）
        commitIME();
        widget.onToggleExpanded?.call();
      },
      child: Container(
        width: 21,
        height: 21,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withValues(alpha: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(-1, 1),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: 1.5708, // 90度回転
          child: Icon(
            widget.isExpanded
                ? Icons.close_fullscreen
                : Icons.open_in_full,
            size: 11,
            color: Colors.white,
          ),
        ),
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
    const double tabW = 19.0;
    const double trayTotalWidth = trayBodyWidth + tabW;
    // ルーレットはみ出し量: 開き時27pt, 閉じ時42pt（Swift版準拠）
    final double dialOverhang = _rouletteOpen ? 60.0 : 55.0;
    // チラ見せ量（閉じ時にボディ左辺が覗く）
    const double peekAmount = 5.0;
    // 閉じ時: タブだけ見える位置までスライド
    final slideOffset = _rouletteOpen ? 0.0 : (trayTotalWidth - tabW);

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
                              // 三角マーク（展開時: 22pt中央、閉じ時: 40pt中央）
                              Positioned(
                                left: 4,
                                top: 0,
                                bottom: _rouletteOpen ? 0 : 0,
                                child: Center(
                                  child: Text(
                                    _rouletteOpen ? '\u25B6' : '\u25C0',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ),
                              // 親タグ・子タグラベル（上22ptの範囲に中央寄せ）
                              if (_rouletteOpen) ...[
                                Positioned(
                                  right: 221,
                                  top: 0,
                                  height: 22,
                                  child: Center(
                                    child: Text(
                                      '\u89AAタグ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 104,
                                  top: 0,
                                  height: 22,
                                  child: Center(
                                    child: Text(
                                      '\u5B50タグ',
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
    if (id == null) return;
    final db = ref.read(databaseProvider);
    // タグの実体を取得（pending保持用）
    // まずキャッシュから探し、無ければDB直接（新規作成直後はストリーム未反映なため）
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
      for (final tag in _attachedTags.where((t) => t.parentTagId == null)) {
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
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    onChanged: (_) => _onChanged(),
                    readOnly: _isViewMode,
                    onTap: _isViewMode
                        ? () => _enterEditMode(
                            focusContent: false, focusTitle: true)
                        : null,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PingFang JP',
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: '\u30BF\u30A4\u30C8\u30EB\uFF08\u4EFB\u610F\uFF09',
                      hintStyle: TextStyle(
                          color: Colors.grey.withValues(alpha: 0.4)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 4),
                    ),
                    maxLines: 1,
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
                      child: Icon(Icons.close, size: 14,
                          color: Colors.grey.withValues(alpha: 0.4)),
                    ),
                  ),
              ],
            ),
          ),
          // 縦線セパレータ
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color.fromRGBO(142, 142, 147, 0.35),
          ),
          // タグ表示エリア
          if (_parentTag == null)
            // タグ未選択: アイコンのみ
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openRoulette,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const Icon(Icons.sell_outlined, size: 16,
                    color: Color.fromRGBO(142, 142, 147, 0.45)),
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
                        child: Icon(Icons.cancel,
                            size: 12,
                            color: Colors.grey.withValues(alpha: 0.5)),
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

    if (child != null) {
      final childColor = TagColors.getColor(child.colorIndex);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 親タグ
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
              decoration: BoxDecoration(
                color: parentColor,
                borderRadius: BorderRadius.circular(CornerRadius.parentTag),
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
          ),
          // 子タグ（4pt左にズラして親に重ねる / 白枠線）
          Flexible(
            child: Transform.translate(
              offset: const Offset(-4, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
            ),
          ),
        ],
      );
    }

    // 親タグのみ
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: parentColor,
        borderRadius: BorderRadius.circular(CornerRadius.parentTag),
      ),
      child: Text(
        parent.name,
        style: _parentTagTextStyle,
        strutStyle: _parentStrutStyle,
        textHeightBehavior: _tightHeightBehavior,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: TextField(
          controller: _contentController,
          focusNode: _contentFocusNode,
          onChanged: (_) => _onChanged(),
          readOnly: _isViewMode,
          onTap: () {
            if (_isViewMode) {
              _enterEditMode(focusContent: true);
            }
            // 長押しメニュー表示直後（300ms以内）は消さない
            // それ以降のタップでメニューを消す（編集は続行）
            if (_lastContextMenuShown != null &&
                DateTime.now().difference(_lastContextMenuShown!) >
                    const Duration(milliseconds: 300)) {
              ContextMenuController.removeAny();
              _lastContextMenuShown = null;
            }
            // ルーレットが開いていたら閉じる
            if (_rouletteOpen) _closeRoulette();
          },
          inputFormatters: [
            // 5万字超過は自動カット + トースト通知 (連射防止)
            _LimitWithToastFormatter(
              maxLength: _maxContentLength,
              onLimit: _showLimitReached,
            ),
          ],
          // 16pt、行間 1.25 (控えめ)、角張った PingFang JP
          style: const TextStyle(
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w500,
            fontFamily: 'PingFang JP',
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: '\u30E1\u30E2\u3092\u5165\u529B...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
          ),
          contextMenuBuilder: (context, editableTextState) {
            // メニュー表示タイミングを記録
            _lastContextMenuShown = DateTime.now();
            return AdaptiveTextSelectionToolbar.editableText(
              editableTextState: editableTextState,
            );
          },
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: _hasMemo ? _deleteMemo : null,
            child: Icon(CupertinoIcons.delete_simple,
                size: 18,
                color: _hasMemo
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.grey.shade300),
          ),
          const SizedBox(width: 12),
          Text('MD',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.grey[500],
              )),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.6,
            child: SizedBox(
              width: 34,
              height: 20,
              child: Switch(
                value: false,
                onChanged: (_) {},
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const Spacer(),
          // Undo (本家: arrow.uturn.backward, blue when enabled)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _canUndo ? _undo : null,
            child: Icon(
              CupertinoIcons.arrow_uturn_left,
              size: 16,
              color: _canUndo
                  ? const Color(0xFF007AFF)
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 12),
          // Redo (本家: arrow.uturn.forward)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _canRedo ? _redo : null,
            child: Icon(
              CupertinoIcons.arrow_uturn_right,
              size: 16,
              color: _canRedo
                  ? const Color(0xFF007AFF)
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 12),
          // コピー (本家: doc.on.doc + テキスト)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _contentController.text.isEmpty ? null : _copyContent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.doc_on_doc,
                  size: 14,
                  color: _contentController.text.isEmpty
                      ? Colors.grey.shade400
                      : const Color(0xFF007AFF),
                ),
                const SizedBox(width: 3),
                Text(
                  'コピー',
                  style: TextStyle(
                    fontSize: 14,
                    color: _contentController.text.isEmpty
                        ? Colors.grey.shade400
                        : const Color(0xFF007AFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // フォーカス中: 確定 (キーボード閉じるだけ)
          // 非フォーカス + メモ/タイトルあり: メモを閉じる (クリア)
          if (_isInputFocused)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _confirm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    CupertinoIcons.checkmark_circle,
                    size: 16,
                    color: Color(0xFF007AFF),
                  ),
                  SizedBox(width: 3),
                  Text(
                    '確定',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            )
          else if (_hasMemo || _titleController.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMemo,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    CupertinoIcons.xmark_circle,
                    size: 16,
                    color: Color(0xFF007AFF),
                  ),
                  SizedBox(width: 3),
                  Text(
                    'メモを閉じる',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF007AFF),
                    ),
                  ),
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

// 消しゴムグリフ: CustomPainterで斜めの長方形を描く
// (Material Icons に eraser がないため自前)
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
