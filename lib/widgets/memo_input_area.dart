import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/design_constants.dart';
import '../constants/memo_bg_colors.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/image_storage.dart';
import '../utils/keyboard_done_bar.dart';
import '../utils/responsive.dart';
import '../utils/safe_dialog.dart';
import '../utils/text_menu_dismisser.dart';
import '../utils/toast.dart';
import 'bg_color_picker_dialog.dart';
import 'block_editor.dart';
import 'confirm_delete_dialog.dart';
import 'date_picker_sheet.dart';
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
  /// eventDate（カレンダー紐付け日）が変わったときの通知。
  /// 親（home_screen）が機能バー右半分の日付ラベル表示に使う。
  final ValueChanged<DateTime?>? onEventDateChanged;

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
    this.onEventDateChanged,
  });

  @override
  ConsumerState<MemoInputArea> createState() => MemoInputAreaState();
}

class MemoInputAreaState extends ConsumerState<MemoInputArea> {
  /// 外部から本文の有無を確認するゲッター（ゼロ幅スペースは無視）
  bool get hasContent => _contentController.text.isNotEmpty;
  /// 外部から本文フォーカス状態を確認するゲッター
  // BlockEditor 側が本文フォーカスを持つようになったので、それを優先して返す
  bool get isContentFocused =>
      (_blockEditorKey.currentState?.hasAnyFocus ?? false) ||
      _contentFocusNode.hasFocus;
  /// タイトル欄がフォーカス中か
  bool get isTitleFocused => _titleFocusNode.hasFocus;
  /// 外部から入力欄全体のフォーカス状態を確認するゲッター（タイトル or 本文）
  bool get isInputFocused => _isInputFocused;
  /// 外部から Undo を実行（⌘Z ショートカット用）
  Future<void> triggerUndo() => _undo();
  /// 外部から日付ピッカーを開く（機能バーの日付ラベルタップ時用）
  Future<void> openCalendarDatePicker() async {
    final memoId = widget.editingMemoId ?? _selfCreatedMemoId;
    if (memoId == null) return;
    await _showCalendarDatePicker(memoId);
  }
  /// 外部から Redo を実行（⇧⌘Z ショートカット用）
  Future<void> triggerRedo() => _redo();
  /// 外部からフォーカス中の選択範囲を wrapper でラップ（⌘B / ⌘I 用）。
  /// MD モード時のみ有効。選択なしのときはラッパーだけ挿入してカーソルを間に。
  void triggerWrapMarkdown(String wrapper) {
    if (!_isMarkdown) return;
    _blockEditorKey.currentState?.wrapFocusedSelection(wrapper);
  }
  /// 外部から Undo 可能か判定
  bool get canUndo => _canUndo;
  /// 外部から Redo 可能か判定
  bool get canRedo => _canRedo;
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
  // Phase 10++ ブロックエディタ実験: 本文を TextField+画像 Strip ではなく BlockEditor で描画
  final GlobalKey<BlockEditorState> _blockEditorKey =
      GlobalKey<BlockEditorState>();
  // 入力欄ルート。トースト位置計算用（下端を取得して直下に表示するため）
  final GlobalKey _inputAreaKey = GlobalKey();
  // 入力欄フッター（ツールバー）。トースト位置計算用（上端を取得して直上に表示）
  final GlobalKey _toolbarKey = GlobalKey();
  /// BlockEditor 内の任意の TextField が primaryFocus を持つか
  /// （hasFocus ベースではなく primaryFocus ベース。別 route のシート等に
  ///   入力が移った瞬間に false になる）。
  bool get _isBlockEditorFocused =>
      _blockEditorKey.currentState?.hasActivePrimaryFocus ?? false;
  /// この MemoInputArea の TextField 群のいずれかが実際に入力を受けているか。
  /// primaryFocus ベースの厳密判定。タグシート等を上に載せたとき、そちらの
  /// TextField にフォーカスが移ればこれは false になる（ツールバー残留防止）。
  bool get _isInputFocused {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    if (primary == _titleFocusNode) return true;
    if (primary == _contentFocusNode) return true;
    return _isBlockEditorFocused;
  }
  // ダイアログ表示中フラグ: ダイアログが出るとフォーカスが一旦外れて
  // フッターが閲覧モードに切り替わってしまうので、見た目を編集モードに固定するために使う
  bool _isDialogOpen = false;
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
  /// カレンダー紐付け日（null = 通常メモ、設定済み = カレンダーに載ってる）
  /// フッター右下に小さく表示し、タップで日付ピッカーを開く。
  DateTime? _eventDate;
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
  // 最大化 + キーボード表示中に、フッターツールバーをキーボード上に浮かせる Overlay
  OverlayEntry? _toolbarOverlay;

  // タグ欄フラッシュ (ルーレットでタグ設定した直後に一瞬ハイライト)
  bool _tagFlashActive = false;
  Timer? _tagFlashTimer;
  void _flashTag() {
    if (!mounted) return;
    setState(() => _tagFlashActive = true);
    _tagFlashTimer?.cancel();
    _tagFlashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _tagFlashActive = false);
    });
  }

  /// ビルド中に呼ばれた場合は次フレームに遅延。そうでなければ即実行。
  void _safeDefer(VoidCallback fn) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fn();
      });
    } else {
      fn();
    }
  }

  void _updateMdToolbarOverlay() => _safeDefer(_updateMdToolbarOverlayImpl);

  void _updateMdToolbarOverlayImpl() {
    final shouldShow = _isMarkdown && _isBlockEditorFocused;
    if (shouldShow && _mdToolbarOverlay == null) {
      _mdToolbarOverlay = OverlayEntry(builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        if (bottom <= 0) return const SizedBox.shrink();
        // フォーカス中の TextBlock の controller を取得。見つからないときは
        // ミラー側の _contentController にフォールバック（MD ボタンが無効化される）
        final focused =
            _blockEditorKey.currentState?.focusedController ?? _contentController;
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: Material(
            elevation: 0,
            child: MarkdownToolbar(
              controller: focused,
              onChanged: () {
                // TextBlock の変更は BlockEditor が _serialize → onContentChanged
                // で自動反映してくれるので、ここでは明示的な保存は不要
              },
            ),
          ),
        );
      });
      Overlay.of(context).insert(_mdToolbarOverlay!);
    } else if (!shouldShow && _mdToolbarOverlay != null) {
      _mdToolbarOverlay!.remove();
      _mdToolbarOverlay = null;
    } else if (shouldShow && _mdToolbarOverlay != null) {
      // キーボード高さ変化 / フォーカス移動 時にリビルド
      _mdToolbarOverlay!.markNeedsBuild();
    }
    _syncAccessoryHeight();
  }

  /// 完了ボタン（KeyboardDoneBar）がカスタムツールバー群の上に出るよう、
  /// 現在表示中のオーバーレイ合計高さを通知
  void _syncAccessoryHeight() {
    // 自分のTextFieldがフォーカスされていないときは accessoryHeight を触らない。
    // 他画面（爆速モードなど）が独自に accessoryHeight を制御している可能性があり、
    // FocusManager.instance.addListener 経由でグローバルフォーカス変更が走るたびに
    // 0 上書きすると他画面の Overlay と完了ボタンが重なってしまう。
    if (!_isInputFocused) return;
    final ourToolbar = (widget.isExpanded && _isInputFocused) ? 46.0 : 0.0;
    final mdToolbar = (_isMarkdown && _isInputFocused) ? 44.0 : 0.0;
    KeyboardDoneBar.accessoryHeight.value = ourToolbar + mdToolbar;
  }

  /// 最大化モード + 入力フォーカス中 は、フッターツールバーをキーボード上に
  /// 浮かせて常時操作可能にする（本来のインラインツールバーはキーボード裏に
  /// 回っているので、上に被せるイメージ）
  void _updateToolbarOverlay() => _safeDefer(_updateToolbarOverlayImpl);

  void _updateToolbarOverlayImpl() {
    final shouldShow = widget.isExpanded && _isInputFocused;
    if (shouldShow && _toolbarOverlay == null) {
      _toolbarOverlay = OverlayEntry(builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        if (bottom <= 0) return const SizedBox.shrink();
        // MDツールバー (高さ 44) が出てるなら更に上へずらす
        final mdOffset = (_isMarkdown && _isInputFocused) ? 44.0 : 0.0;
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottom + mdOffset,
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _buildToolbar(compact: true),
            ),
          ),
        );
      });
      Overlay.of(context).insert(_toolbarOverlay!);
    } else if (!shouldShow && _toolbarOverlay != null) {
      _toolbarOverlay!.remove();
      _toolbarOverlay = null;
    } else if (shouldShow && _toolbarOverlay != null) {
      _toolbarOverlay!.markNeedsBuild();
    }
    _syncAccessoryHeight();
  }

  @override
  void initState() {
    super.initState();
    _resetUndoHistory();
    _titleFocusNode.addListener(_onFocusChange);
    _contentFocusNode.addListener(_onFocusChange);
    // BlockEditor 内の動的 TextBlock や別 route の TextField への
    // primaryFocus 移動を検知するためのグローバルリスナー。
    // これがないと、タグシート等を上に開いたときにツールバー Overlay が
    // 残留したまま再評価されない。
    FocusManager.instance.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      // タイトル/本文にフォーカスが入ったらルーレットは引っ込める。
      // 共存させると入力中にルーレット側でタグが切り替わったりして混乱する。
      if (_isInputFocused && _rouletteOpen) {
        _closeRoulette();
      }
      // フォーカスを得た時点でメモ未作成なら空メモを先行作成
      if (_isInputFocused && widget.editingMemoId == null && !_hasMemo) {
        _preCreateEmptyMemo();
      }
      // フォーカスが外れたとき、空メモなら削除
      // 最大化中でも削除対象（空メモの残留を防ぐ）
      // editingMemoId(親管理) でも _selfCreatedMemoId(自作) でも対象にする
      final activeMemoId = widget.editingMemoId ?? _selfCreatedMemoId;
      if (!_isInputFocused && activeMemoId != null) {
        final t = _titleController.text;
        final c = _contentController.text;
        // 色が付いているメモは空扱いしない（色だけ入れたメモも保持）
        if (t.isEmpty && c.isEmpty && _bgColorIndex == 0) {
          final db = ref.read(databaseProvider);
          db.deleteMemo(activeMemoId);
          _clearInput(keepMarkdown: _isMarkdown);
          // 入力エリア最大化中の自動 onClosed は、ユーザーが意図せず
          // フォーカスを外したとき（最大化画面でフォルダ余白をタップ等）
          // にフォルダ最大化への自動復帰ループを起こすので呼ばない。
          // 最大化中は明示的に戻り矢印で抜けてもらう（_minimizeWithCommit）。
          if (!widget.isExpanded) {
            widget.onClosed();
          }
          return;
        }
      }
      setState(() {});
      _updateMdToolbarOverlay();
      _updateToolbarOverlay();
      widget.onFocusChanged?.call();
    }
  }

  @override
  void didUpdateWidget(covariant MemoInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 最大化トグル時にフッターツールバー Overlay を更新
    if (oldWidget.isExpanded != widget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateToolbarOverlay();
      });
    }
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
    // 新規作成ボタンからのフォーカス要求（外部から focusRequest カウンタが変わる）
    // 注: didUpdateWidget はビルドサイクル内なので、focus は次フレームに遅延させる
    if (widget.focusRequest != oldWidget.focusRequest) {
      _isViewMode = false;
      // 「タグだけ指定して本文未入力」の状態で新規作成ボタンを押したケースでは
      // editingMemoId が null → null（変化なし）になるため、上の editingMemoId
      // 変化検知では _clearInput が呼ばれない。pending タグや前回の入力が
      // 残ってしまうので、focusRequest 変化＋両方 null のときは明示的にクリアする。
      if (widget.editingMemoId == null && oldWidget.editingMemoId == null) {
        _clearInput(keepMarkdown: _isMarkdown);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _blockEditorKey.currentState?.focusFirst();
      });
    }
  }

  Future<void> _loadMemo(String id) async {
    final db = ref.read(databaseProvider);
    final memo = await db.getMemoById(id);
    // await 中にユーザーが新規作成ボタン等で別メモへ遷移すると
    // widget.editingMemoId が変わっている。古いメモのデータで上書きしないよう
    // ここでガード（さもないと _attachedTags が古いタグで残り続ける）。
    if (!mounted || widget.editingMemoId != id) return;
    if (memo != null) {
      _applyMemoData(memo);
      _attachedTags = await db.getTagsForMemo(id);
      if (!mounted || widget.editingMemoId != id) return;
      setState(() {});
    }
  }

  /// メモデータを直接適用する（DBクエリ不要で高速）
  void loadMemoDirectly(Memo memo) {
    _directLoadApplied = true;
    _applyMemoData(memo);
    // タグは非同期で読み込み。
    // .then() の発火時に既に別メモへ遷移していたら（widget.editingMemoId が
    // memo.id と違う）古いタグで上書きしないようガード。
    final db = ref.read(databaseProvider);
    db.getTagsForMemo(memo.id).then((tags) {
      if (mounted && widget.editingMemoId == memo.id) {
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
    // 呼び出し元のタップジェスチャーコンテキストが活きている間に requestFocus する
    // （postFrame に逃がすとキーボードが出ない）
    _blockEditorKey.currentState?.focusFirst();
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
      _eventDate = memo.eventDate;
    });
    widget.onEventDateChanged?.call(memo.eventDate);
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
    // 自作メモIDも同時にクリア（次の入力で確実に新メモを先行作成させる）
    _selfCreatedMemoId = null;
    _directLoadApplied = false;
    setState(() {
      _hasMemo = false;
      _isViewMode = false;
      _eventDate = null;
    });
    widget.onEventDateChanged?.call(null);
  }

  // 閲覧モードを抜けて編集モードへ。本文タップ等から呼ばれる
  // readOnly解除後にフォーカスを当てるが、ScrollableのscrollPadding計算は
  // readOnly=false が反映された後のフレームで走るため、2フレーム待つ
  void _enterEditMode({bool focusContent = true, bool focusTitle = false}) {
    setState(() => _isViewMode = false);
    // postFrame に逃がすと iOS のタップジェスチャーコンテキストが切れて
    // キーボードが出ない（1回目のタップ無反応）。即時 requestFocus する。
    if (focusTitle) _titleFocusNode.requestFocus();
    if (focusContent) {
      _blockEditorKey.currentState?.focusFirst();
    }
  }

  /// 入力内容を即座に保存
  void _onChanged() {
    _pushUndoIfChanged();
    widget.onContentChanged?.call();
    // 親 (HomeScreen) 管理の editingMemoId が未セットでも、
    // _selfCreatedMemoId があればそちらに更新する
    // （onMemoCreated 通知後に親が editingMemoId をセットするまでの
    //   1〜2フレームの間も入力をロストしないように）
    final memoId = widget.editingMemoId ?? _selfCreatedMemoId;
    if (memoId == null) {
      // メモ未作成: 通常はフォーカス時に先行作成済みだが、フォールバックとして
      // 次フレームで作成（rebuildとの干渉を避けるため遅延）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final cur = widget.editingMemoId ?? _selfCreatedMemoId;
        if (cur != null) return;
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
        if (!mounted) return;
        final cur = widget.editingMemoId ?? _selfCreatedMemoId;
        if (cur == null) return;
        if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
          db.deleteMemo(cur);
          if (cur == _selfCreatedMemoId) _selfCreatedMemoId = null;
          _clearInput(keepMarkdown: _isMarkdown);
          widget.onClosed();
        }
      });
      return;
    }
    db.updateMemo(
      id: memoId,
      title: _titleController.text,
      content: _contentController.text,
    );
    if (mounted) setState(() {}); // Undo/Redoボタンの状態更新用
  }

  // 自分で作成したメモのID（_loadMemoで閲覧モードにしないため）
  String? _selfCreatedMemoId;
  // loadMemoDirectlyで直接ロード済み → didUpdateWidgetでの_loadMemoをスキップ
  bool _directLoadApplied = false;

  /// 画像を紐付ける先のメモID。必要なら新規作成する。
  /// _preCreateEmptyMemo と同等の処理を行い、作成済みメモがあればそれを返す。
  Future<String?> _ensureMemoId() async {
    if (widget.editingMemoId != null) return widget.editingMemoId;
    if (_selfCreatedMemoId != null) return _selfCreatedMemoId;
    await _preCreateEmptyMemo();
    return _selfCreatedMemoId;
  }

  /// 画像ソースを選ぶすりガラスダイアログ → BlockEditor に挿入を委譲
  /// (Phase 10++ ブロックエディタ実験: 画像はカーソル位置にインライン挿入される)
  /// ライブラリ選択時は 5枚まで複数選択可
  Future<void> _attachImage() async {
    // キーボードは閉じない方針: 閉じると最後にフォーカスされたブロック情報が
    // 消えるかもしれないので、そのまま picker を起動する。picker側で一時的に閉じる。
    if (!mounted) return;
    ImageSource? source;
    await showFrostedAlert(
      context: context,
      title: '画像を追加',
      message: '取り込み元を選んでください',
      actions: [
        FrostedAlertAction(
          label: 'カメラ',
          onPressed: () => source = ImageSource.camera,
        ),
        FrostedAlertAction(
          label: 'ライブラリ',
          isDefault: true,
          onPressed: () => source = ImageSource.gallery,
        ),
      ],
    );
    if (source == null || !mounted) return;
    // メモがまだ無ければ先に作成（memoIdResolver が非空を返すように）
    final memoId = await _ensureMemoId();
    if (memoId == null || !mounted) return;
    if (source == ImageSource.gallery) {
      final picker = ImagePicker();
      List<XFile> picks;
      try {
        picks = await picker.pickMultiImage(limit: 5);
      } catch (_) {
        if (mounted) showToast(context, '画像の取り込みに失敗しました');
        return;
      }
      if (picks.isEmpty || !mounted) return;
      await _blockEditorKey.currentState?.insertImagesFromXFiles(picks);
    } else {
      await _blockEditorKey.currentState?.insertImageFromPicker(source!);
    }
  }

  /// フォーカス取得時に空メモを先行作成
  /// 以降の入力はすべてupdateMemoで処理されるため、rebuildが発生せず
  /// カスタムキーボードのテキスト消失を防ぐ
  Future<void> _preCreateEmptyMemo() async {
    // 二重呼び出しガード: title/content/FocusManager の3つのリスナーが
    // フォーカス取得時に同時発火するため、createMemo の await 中に
    // 2回目以降が走ると空メモが重複作成される（iOS 実機 / シミュで再現）。
    // 同期的にフラグを立ててから await に入ることでレースを防ぐ。
    if (_hasMemo) return;
    _hasMemo = true;

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
    if (mounted) setState(() {});
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
    // MDオン/オフで下にMDツールバーが追加/除去されるので、その上のフッター
    // ツールバー Overlay の位置も再計算
    _updateToolbarOverlay();
    // 既存メモならDBに反映
    if (widget.editingMemoId != null) {
      ref.read(databaseProvider).updateMemo(
            id: widget.editingMemoId!,
            isMarkdown: value,
          );
    }
    // トースト表示（フッター上端の 5px 上にトースト下端を合わせる。親指の下に来ないように）
    if (mounted) {
      final toastBottom = _toolbarTopPx() - 5;
      if (value) {
        showToast(
          context,
          'マークダウンモード オン\nボタンまたは左右フリックでプレビュー切替',
          duration: const Duration(milliseconds: 2400),
          bottomY: toastBottom,
        );
      } else {
        showToast(context, 'マークダウンモード オフ',
            duration: const Duration(milliseconds: 1200),
            bottomY: toastBottom);
      }
    }
  }

  /// 入力欄フッター（ツールバー）のグローバル上端 Y 座標。
  /// 取得失敗時は画面高の 0.4（フォールバック）
  double _toolbarTopPx() {
    final ctx = _toolbarKey.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        return box.localToGlobal(Offset.zero).dy;
      }
    }
    return MediaQuery.of(context).size.height * 0.4;
  }

  /// 本文だけを消す (消しゴムボタン): タイトル/タグはそのまま
  /// 画像も DB から削除する（BlockEditor は DB の画像を自動末尾追加するため）
  /// 公開: home_screen のフロート消しゴムから呼べるようにする
  Future<void> clearBody() async {
    if (_contentController.text.isEmpty) return;
    widget.onDialogOpenChanged?.call(true);
    setState(() => _isDialogOpen = true);
    try {
      // viewInsets を 0 に上書きして、キーボードが閉じるアニメーションに
      // 引きずられてダイアログが上から降ってくる挙動を回避。
      // focusSafe は使わない: キャンセル/クリア後に Navigator の自動フォーカス
      // 復元が効いて元の編集カーソル位置に戻れるようにするため。
      final ok = await showConfirmDeleteDialog(
        context: context,
        title: '本文をクリア',
        message: '本文と画像をクリアします。タイトルとタグはそのまま残ります。',
        confirmLabel: 'クリア',
      );
      if (!ok || !mounted) return;
      // DB の画像を削除（実ファイルもまとめて消す）
      final memoId = widget.editingMemoId ?? _selfCreatedMemoId;
      if (memoId != null) {
        await ref.read(databaseProvider).deleteAllMemoImages(memoId);
      }
      _contentController.clear();
      // BlockEditor 側のブロックも空に再構築（画像ブロックを除去）
      _blockEditorKey.currentState?.replaceContent('');
      _onChanged();
      setState(() {});
    } finally {
      if (mounted) {
        setState(() => _isDialogOpen = false);
        widget.onDialogOpenChanged?.call(false);
      }
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
    _toolbarOverlay?.remove();
    _toolbarOverlay = null;
    KeyboardDoneBar.accessoryHeight.value = 0;
    _tagFlashTimer?.cancel();
    FocusManager.instance.removeListener(_onFocusChange);
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
    return _buildMainArea(allTagsAsync);
  }

  Widget _buildMainArea(AsyncValue<List<Tag>> allTagsAsync) {
    return Container(
      key: _inputAreaKey,
      margin: const EdgeInsets.fromLTRB(10, 6, 0, 2),
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
          // ルーレット台形タブは非表示（タグ欄タップで開く）
          // プレビューボタンはツールバー側に移動（MDトグル直後）
          // 日付テキストオーバーレイは home_screen 側の `_buildInputAreaSection`
          // で AnimatedContainer の外側 Stack に重ねる（こちらの Stack だと
          // 親 AnimatedContainer の clipBehavior=hardEdge に切られてしまう）。
        ],
      ),
    );
  }

  Widget _buildPreviewButton() {
    final isOn = _showMarkdownPreview;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_showMarkdownPreview) {
          _exitPreview();
        } else {
          _enterPreview();
        }
      },
      // 枠なし・他のフッターアイコン（多機能/パレット/コピー）と同じ size/color に統一。
      // ON 時はオレンジでハイライト、OFF 時はグレー。
      child: Icon(
        CupertinoIcons.eye,
        size: 22,
        color: isOn ? Colors.orange : Colors.grey[600],
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
      _flashTag();
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
    if (mounted) setState(() {});
    _flashTag();
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
                child: const Icon(Icons.sell,
                    size: 20, color: Color.fromRGBO(142, 142, 147, 0.6)),
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

  /// テキスト 1 行の自然描画幅を測る（タグ表示の動的配分用）
  double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.size.width;
  }

  /// 親タグ＋子タグの重ね合わせ表示（Swift版 tagDisplay 準拠）
  Widget _buildTagDisplay() {
    final parent = _parentTag!;
    final child = _childTag;
    final parentColor = TagColors.getColor(parent.colorIndex);

    if (child != null) {
      final childColor = TagColors.getColor(child.colorIndex);
      // 親と子の合算予算で動的配分する。固定 maxWidth を個別に与えると、
      //  - 周囲の Flexible 制約より合算が大きくなった場合にオーバーフロー
      //  - 親が短くても子は固定値で打ち切られて余りを活かせない
      // という問題が起きる。LayoutBuilder で実利用可能幅を取り、TextPainter
      // で各タグの自然幅を測って配分する（短い側は自然幅、長い側に余りを譲る）。
      const overlap = 4.0; // 子タグの -4 マージン（描画上の重なり、layout 上は無視）
      // 装飾分の幅: padding + border + 計測誤差吸収マージン
      // Transform.translate は layout に影響しないため、Row の実 layout 幅は
      // 単純に pMax + cMax。これを available にぴったり合わせてオーバーフロー
      // を回避する。
      const parentDecoration = 16.0; // padding 4+4 + border 2*2 + 余裕 4
      const childDecoration = 13.0; // padding 3+3 + border 1.5*2 + 余裕 4
      return LayoutBuilder(
        builder: (ctx, constraints) {
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width * 0.32;
          // 自然幅（テキスト + 装飾）
          final pTextW = _measureTextWidth(parent.name, _parentTagTextStyle);
          final cTextW = _measureTextWidth(child.name, _childTagTextStyle);
          final pNat = pTextW + parentDecoration;
          final cNat = cTextW + childDecoration;
          double pMax, cMax;
          if (pNat + cNat <= available) {
            // 余裕あり: 自然幅
            pMax = pNat;
            cMax = cNat;
          } else {
            // 短い側は自然幅、長い側に残りを譲る。最低でも半々は確保。
            final half = available / 2;
            if (pNat <= half) {
              pMax = pNat;
              cMax = available - pMax;
            } else if (cNat <= half) {
              cMax = cNat;
              pMax = available - cMax;
            } else {
              pMax = half;
              cMax = half;
            }
          }
          final parentWidget = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: pMax),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              decoration: BoxDecoration(
                color: parentColor,
                borderRadius: BorderRadius.circular(CornerRadius.badge),
                border: Border.all(
                  color:
                      _tagFlashActive ? Colors.orange : Colors.transparent,
                  width: 2,
                ),
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
            constraints: BoxConstraints(maxWidth: cMax),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              decoration: BoxDecoration(
                color: childColor,
                borderRadius: BorderRadius.circular(CornerRadius.badge),
                border: Border.all(
                  color: _tagFlashActive ? Colors.orange : Colors.white,
                  width: _tagFlashActive ? 2 : 1.5,
                ),
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
          return IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                parentWidget,
                Transform.translate(
                  offset: const Offset(-overlap, 1.5),
                  child: childWidget,
                ),
              ],
            ),
          );
        },
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;

    // 親タグのみ（子タグなしなら少し広めに使える）
    final maxParentOnly = screenWidth * 0.35;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxParentOnly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: parentColor,
          borderRadius: BorderRadius.circular(CornerRadius.badge),
          border: Border.all(
            color: _tagFlashActive ? Colors.orange : Colors.transparent,
            width: 2,
          ),
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

  /// プレビュータップ時の Y 座標（ローカル）を記録しておき、編集戻り時に
  /// ソース文字オフセットへマッピングするのに使う
  double _lastPreviewTapY = 0;

  /// プレビューに入る直前のカーソル位置（シリアライズ本文の文字 offset）
  /// 編集→プレビュー→編集 と戻った際にカーソルを元の位置に復元する用途
  int? _savedSourceOffsetBeforePreview;

  /// プレビューに切り替え（カーソル位置を保存 + キーボード閉じ）
  void _enterPreview() {
    if (!_isMarkdown) return;
    _savedSourceOffsetBeforePreview =
        _blockEditorKey.currentState?.currentSourceOffset;
    FocusScope.of(context).unfocus();
    setState(() => _showMarkdownPreview = true);
  }

  /// プレビューを抜ける。カーソル復元のロジック:
  /// - fallbackOffset（プレビュー本文タップから渡される）が優先。明示的な
  ///   「ここを編集したい」意思とみなす
  /// - なければ保存済みカーソル（プレビュー入る前に編集中だった場合）
  /// - どちらもなければ閲覧モードのまま（フォーカスしない／キーボード出ない）
  void _exitPreview({int? fallbackOffset}) {
    final targetOffset = fallbackOffset ?? _savedSourceOffsetBeforePreview;
    _savedSourceOffsetBeforePreview = null;
    setState(() {
      _showMarkdownPreview = false;
      if (targetOffset != null) _isViewMode = false;
    });
    if (targetOffset != null) {
      _blockEditorKey.currentState?.focusAtSourceOffset(targetOffset);
    }
  }

  /// プレビュー Y 座標をおおまかな行 index に落とし、ソースの文字 offset を返す
  /// - 見出し・画像・ブロック間隔までは正確に扱わず、プレーンテキスト想定で概算
  int _sourceOffsetFromPreviewY(double tapY) {
    const lineHeight = 20.0;
    const topPadding = 11.0;
    final lineIndex = ((tapY - topPadding) / lineHeight).floor();
    if (lineIndex <= 0) return 0;
    final text = _contentController.text;
    final lines = text.split('\n');
    if (lineIndex >= lines.length) return text.length;
    var offset = 0;
    for (var i = 0; i < lineIndex; i++) {
      offset += lines[i].length + 1; // +1 for '\n'
    }
    return offset;
  }

  /// プレビュー中の N 番目のチェックボックス ([ ] / [x]) を本文側でトグル
  void _togglePreviewCheckbox(int index) {
    final text = _contentController.text;
    var count = 0;
    final buf = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (i + 3 <= text.length &&
          text[i] == '[' &&
          (text[i + 1] == ' ' || text[i + 1] == 'x' || text[i + 1] == 'X') &&
          text[i + 2] == ']') {
        if (count == index) {
          buf.write('[');
          buf.write(text[i + 1] == ' ' ? 'x' : ' ');
          buf.write(']');
        } else {
          buf.write(text.substring(i, i + 3));
        }
        count++;
        i += 3;
      } else {
        buf.write(text[i]);
        i++;
      }
    }
    final result = buf.toString();
    if (result == text) return;
    _contentController.text = result;
    _onChanged();
  }

  /// プレビュー描画部分（Stack で BlockEditor の上に重ねる）。
  /// BlockEditor は裏でマウント継続しているので、タップで即 focusFirst できる。
  Widget _buildPreviewOverlay() {
    final memoIdForImages = widget.editingMemoId ?? _selfCreatedMemoId;
    final imagesList = memoIdForImages == null
        ? const <MemoImage>[]
        : (ref.watch(memoImagesProvider(memoIdForImages)).valueOrNull ??
            const <MemoImage>[]);
    final imgPathById = {
      for (final img in imagesList) img.id: img.filePath,
    };
    final raw = _contentController.text;
    // 本文が空: MarkdownBody ではなく薄いプレースホルダーを直接出す
    final isEmpty = raw.isEmpty;
    final previewData = isEmpty
        ? ''
        : raw.replaceAllMapped(
            RegExp('\uFFFC([^\uFFFC]+)\uFFFC'),
            (m) => '\n\n![](memolette:${m.group(1)})\n\n',
          );
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          _lastPreviewTapY = details.localPosition.dy;
        },
        onTap: () {
          // 保存済みカーソルがあればそこに戻す、なければタップ位置から近似
          _exitPreview(
            fallbackOffset: _sourceOffsetFromPreviewY(_lastPreviewTapY),
          );
        },
        child: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            // BlockEditor 側は外側 9 + ブロック内 2 = 上 11px から始まるので揃える
            padding: const EdgeInsets.fromLTRB(9, 11, 9, 20),
            child: isEmpty
                ? Text(
                    'プレビュー中（タップで編集に戻る）',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontFamily: 'PingFang JP',
                      color: Colors.grey.withValues(alpha: 0.4),
                    ),
                  )
                : Builder(builder: (ctx) {
              // MarkdownBody 1回の build に対してチェックボックスの通し番号をカウントし、
              // タップしたら同じ順番の [ ] / [x] を _contentController 側でトグルする
              var checkboxIdx = 0;
              return MarkdownBody(
              data: previewData,
              fitContent: false,
              checkboxBuilder: (checked) {
                final idx = checkboxIdx++;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePreviewCheckbox(idx),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      checked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: checked
                          ? const Color(0xFF007AFF)
                          : Colors.grey[600],
                    ),
                  ),
                );
              },
              imageBuilder: (uri, _, __) {
                if (uri.scheme == 'memolette') {
                  final id = uri.path.isNotEmpty ? uri.path : uri.host;
                  final rel = imgPathById[id];
                  if (rel == null) return const SizedBox.shrink();
                  return FutureBuilder<String>(
                    future: ImageStorage.absolutePath(rel),
                    builder: (ctx, snap) {
                      final path = snap.data;
                      if (path == null) return const SizedBox(height: 120);
                      return ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 320),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.contain,
                            cacheWidth: 720,
                            gaplessPlayback: true,
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
              selectable: false,
              styleSheet: MarkdownStyleSheet(
                textAlign: WrapAlignment.start,
                h1Align: WrapAlignment.start,
                h2Align: WrapAlignment.start,
                h3Align: WrapAlignment.start,
                pPadding: const EdgeInsets.only(bottom: 4),
                h1: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PingFang JP',
                    color: Colors.black87),
                h2: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PingFang JP',
                    color: Colors.black87),
                h3: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PingFang JP',
                    color: Colors.black87),
                p: const TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'PingFang JP',
                    color: Colors.black87),
                listBullet: const TextStyle(
                    fontSize: 16, fontFamily: 'PingFang JP'),
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
            );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // BlockEditor は常時マウント。プレビューモードは Stack で上に重ねる
    // （こうすることでプレビュータップから1タップで編集に戻れて focus も立つ）
    // 左右フリックで preview ↔ edit を切り替える（MDモード時のみ）
    return Flexible(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onBodyHorizontalDragEnd,
        child: Stack(
          children: [
            _buildEditArea(),
            if (_isMarkdown && _showMarkdownPreview) _buildPreviewOverlay(),
          ],
        ),
      ),
    );
  }

  /// 本文欄の左右フリック: 一定以上の横速度で preview ↔ edit をトグル。
  /// 閾値は遅めのスワイプで text selection と競合しないよう高めに設定。
  /// 方向は問わない（どちらにフリックしてもトグル）
  void _onBodyHorizontalDragEnd(DragEndDetails details) {
    if (!_isMarkdown) return;
    final v = (details.primaryVelocity ?? 0).abs();
    if (v < 700) return;
    if (_showMarkdownPreview) {
      _exitPreview();
    } else {
      _enterPreview();
    }
  }

  Widget _buildEditArea() {
    // home_screen の Scaffold(resizeToAvoidBottomInset: false) で
    // Flutter の自動キーボード追従が効かないため、最大化時のみ
    // scrollPadding に viewInsets.bottom を手動加算する。
    // 縮小時はメモ入力エリア（316pt 固定）の中で SingleChildScrollView が
    // 閉じてるので、viewport 下端 ≒ フッター上端。viewInsets を加算すると
    // 「画面上半分しかない iPhone」扱いになりカーソルが上端まで飛ぶ。
    // 縮小時はキーボードとそもそも重ならないので加算不要（null = 標準）。
    final scrollPaddingBottom = widget.isExpanded
        ? MediaQuery.of(context).viewInsets.bottom + 20
        : null;
    return LayoutBuilder(builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateMdToolbarOverlay();
        });
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // 本文欄の下に広がる余白タップ: 末尾ブロックにフォーカス。
            // 閲覧モードなら編集モードに移行 + 即 focusLast でキーボード。
            if (_isViewMode) {
              setState(() => _isViewMode = false);
            }
            _blockEditorKey.currentState?.focusLast();
            if (_rouletteOpen) _closeRoulette();
          },
          child: SingleChildScrollView(
            controller: _contentScrollController,
            padding: EdgeInsets.fromLTRB(0, 9, 0,
                widget.isExpanded && !_isViewMode ? 400 : 100),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 100)
                    .clamp(0.0, double.infinity),
              ),
              child: BlockEditor(
                key: _blockEditorKey,
                memoIdResolver: () =>
                    widget.editingMemoId ?? _selfCreatedMemoId ?? '',
                initialContent: _contentController.text,
                readOnly: _isViewMode,
                isMarkdown: _isMarkdown,
                scrollPaddingBottom: scrollPaddingBottom,
                onTap: () {
                  // TextBlock タップ: 閲覧モードなら編集モード遷移するだけ。
                  // カーソル位置は TextField の native なタップ処理に任せる
                  // （タップした位置に素直にカーソルが立つ）
                  if (_isViewMode) {
                    setState(() => _isViewMode = false);
                  }
                  if (_rouletteOpen) _closeRoulette();
                },
                onFocusChanged: () {
                  // 既存の _onFocusChange に寄せる（空メモの先行作成/自動削除
                  // ロジックを BlockEditor 側のフォーカス変化でも発火させる）
                  _onFocusChange();
                },
                onContentChanged: (content) {
                  if (content == _contentController.text) return;
                  // TextEditingValue.value 経由で selection を潰さないように
                  _contentController.text = content;
                  _onChanged();
                },
              ),
            ),
          ),
        );
      });
  }

  Widget _buildToolbar({bool compact = false}) {
    // 「編集中」判定: 実際にフォーカスが入って入力している、compact (Overlay)、
    // またはダイアログ表示中（フォーカスが一時的に外れるので編集中扱いに固定）
    // これ以外 (起動直後・閲覧モード・編集を抜けた状態) は閲覧寄りツールバーを出す
    final isEditing = _isInputFocused || compact || _isDialogOpen;
    final inViewMode = !isEditing;
    final isTablet = Responsive.isTablet(context);
    // iPad は左右 2 グループに分けて配置、アイコン間隔も 1.5 倍に広げる。
    // iPhone は従来のまま左から詰めて並べる（本来の位置）。
    double sp(double base) => isTablet ? base * 1.5 : base;
    return Container(
      key: compact ? null : _toolbarKey,
      constraints: const BoxConstraints(minHeight: 36),
      // 右 padding は 5 に詰めて、閉じる/拡大を右に寄せる（プレビュー表示時の押し出し対策）
      padding: const EdgeInsets.fromLTRB(10, 3, 5, 3),
      child: Row(
        children: [
          // ========================================
          // 左グループ: ゴミ箱 / MD / プレビュー
          // ========================================
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
          // 消しゴム（本文クリア）はゴミ箱の右。編集時のみ表示。
          if (!inViewMode) ...[
            SizedBox(width: sp(14)),
            Builder(builder: (_) {
              final hasContent = _contentController.text.isNotEmpty;
              // 中くらいのオレンジで目立たせる。本文なしのときは薄く。
              final color = hasContent
                  ? const Color(0xFFFB8C00) // orange 600 相当
                  : const Color(0x66FB8C00);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasContent ? clearBody : () {},
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: EraserGlyph(color: color),
                ),
              );
            }),
          ],
          SizedBox(width: sp(14)),
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
          // MD ON のときだけプレビューボタンを MD スイッチの右隣に出す
          if (_isMarkdown) ...[
            SizedBox(width: sp(18)),
            _buildPreviewButton(),
          ],

          // ========================================
          // 左右分離: 閲覧時は等間隔で左詰め（プレビュー↔多機能を多機能↔パレットと揃える）、
          // 編集時は Spacer で右グループを右端寄せ
          // iPhone はプレビュー↔多機能だけ +6px して右グループをセットで少し右にずらす
          // ========================================
          if (inViewMode)
            SizedBox(width: isTablet ? sp(12) : 18)
          else
            const Spacer(),

          // ========================================
          // 右グループ: 閲覧時は 多機能/背景色/コピー、編集時は 画像追加 + Undo/Redo
          // ========================================
          // 多機能・背景色・コピーは閲覧時のみ
          if (inViewMode) ...[
            // 多機能メニュー
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showMultiActionSheet,
              child: Icon(CupertinoIcons.ellipsis_circle,
                  size: 20, color: Colors.grey[600]),
            ),
            SizedBox(width: sp(12)),
            // 背景色変更
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showBgColorPicker,
              child: Icon(Icons.palette_outlined,
                  size: 20, color: Colors.grey[600]),
            ),
            SizedBox(width: sp(12)),
            // コピー
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
            // 閉じる・拡大は常に右端寄せにしたいので、ここで Spacer を入れて
            // コピーまでの左グループと切り離す
            const Spacer(),
          ],
          // 画像追加は編集時のみ
          if (!inViewMode) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _attachImage,
              child: Icon(CupertinoIcons.photo,
                  size: 20, color: Colors.grey[600]),
            ),
          ],
          // Undo / Redo は編集時のみ。iPad は左右に大きめの余白で独立感を出す
          // 画像↔Undo は Undo↔Redo より少し広めにして、画像ボタンに独立感を持たせる
          if (!inViewMode) ...[
            SizedBox(width: isTablet ? 40 : 30),
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
            SizedBox(width: isTablet ? 36 : 24),
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
            // iPad は Undo/Redo の右にも余白を足して「独立した塊」感を出す
            if (isTablet) const SizedBox(width: 16),
          ],
          // 確定 (キーボード閉じる) は KeyboardDoneBar の「完了」と重複するため廃止
          // 閉じる (クリア) は 非フォーカス + メモ/タイトルあり + 非 compact のときだけ出す
          // ダイアログ表示中はフォーカスが一時的に外れるので、閉じる/拡大余白計算用にも
          // _isDialogOpen を考慮してフッターレイアウトをチラつかせない
          if (!compact &&
              !_isInputFocused &&
              !_isDialogOpen &&
              (_hasMemo || _titleController.text.isNotEmpty)) ...[
            SizedBox(width: isTablet ? 16 : 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMemo,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            ),
          ],
          // 最大化/縮小トグル（右端、少し雰囲気が違う機能なので左に余白を入れて独立感を出す）
          // アイコン周囲も含めて広めのタップ判定だが、見た目は右端寄せにする
          // onToggleExpanded が null（例: iPad 横画面）の場合はボタン自体を非表示
          // 閉じる↔拡大の間隔は 11。プレビュー + 閉じる同時表示でも拡大が画面外に押されないようにする
          if (widget.onToggleExpanded != null) ...[
            const SizedBox(width: 11),
            GestureDetector(
              onTap: () {
                commitIME();
                widget.onToggleExpanded?.call();
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 34,
                height: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    widget.isExpanded ? Icons.zoom_in_map : Icons.zoom_out_map,
                    size: 24,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
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
  /// 多機能メニュー（…ボタン）。
  /// メモ ID 必須。閲覧モード時のみツールバーに出るので、通常 ID は確定済み。
  Future<void> _showMultiActionSheet() async {
    final memoId = widget.editingMemoId ?? _selfCreatedMemoId;
    if (memoId == null) return;
    // 既存 eventDate を取得して、メニュー項目のラベルを動的に切替
    final db = ref.read(databaseProvider);
    final memo = await (db.select(db.memos)
          ..where((t) => t.id.equals(memoId)))
        .getSingleOrNull();
    if (!mounted) return;
    final hasEventDate = memo?.eventDate != null;
    final action = await focusSafe<String>(
      context,
      () => showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _MultiActionSheet(hasEventDate: hasEventDate),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'pinToCalendar':
        await _showCalendarDatePicker(memoId);
        break;
    }
  }

  /// メモを「カレンダーに載せる」ためのカスタム日付ピッカー。
  /// クリア = eventDate を null にして通常メモに戻す。
  Future<void> _showCalendarDatePicker(String memoId) async {
    final db = ref.read(databaseProvider);
    final memo = await (db.select(db.memos)
          ..where((t) => t.id.equals(memoId)))
        .getSingleOrNull();
    final initial = memo?.eventDate;
    final result = await focusSafe<DatePickerResult?>(
      context,
      () => showCustomDatePickerSheet(context, initial: initial),
    );
    if (result == null || !mounted) return;
    if (result.cleared) {
      await db.setMemoEventDate(memoId, null);
      if (mounted) {
        setState(() => _eventDate = null);
        widget.onEventDateChanged?.call(null);
      }
    } else if (result.date != null) {
      await db.setMemoEventDate(memoId, result.date!);
      if (mounted) {
        setState(() => _eventDate = result.date);
        widget.onEventDateChanged?.call(result.date);
      }
    }
  }

  Future<void> _showBgColorPicker() async {
    final memoId = widget.editingMemoId;
    final wasEditing = _isInputFocused;
    if (wasEditing) widget.onDialogOpenChanged?.call(true);
    try {
      final selected = await showBgColorPickerDialog(
        context: context,
        current: _bgColorIndex,
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
    if (wasEditing) {
      widget.onDialogOpenChanged?.call(true);
      setState(() => _isDialogOpen = true);
    }
    try {
      // viewInsets を 0 に上書きして、ダイアログが上から降ってくる挙動を回避。
      // focusSafe は使わない: キャンセル後に Navigator の自動フォーカス復元で
      // 元の編集カーソル位置に戻れるようにするため。
      final confirmed = await showConfirmDeleteDialog(
        context: context,
        title: 'メモを削除',
        message: 'このメモを削除します。よろしいですか？',
      );
      if (!confirmed || !mounted) return;
      _deleteMemo();
    } finally {
      if (mounted && wasEditing) {
        setState(() => _isDialogOpen = false);
        widget.onDialogOpenChanged?.call(false);
      }
    }
  }
}

// 消しゴムグリフ: CustomPainterで斜めの長方形を描く
// (Material Icons に eraser がないため自前)
class EraserGlyph extends StatelessWidget {
  /// 線の色。省略時は白（丸い色背景の上に置く前提）。
  /// フッター等で背景なしに置く場合は明示的にグレー系を渡すこと。
  final Color? color;
  const EraserGlyph({this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: EraserPainter(color: color ?? Colors.white),
    );
  }
}

class EraserPainter extends CustomPainter {
  final Color color;
  EraserPainter({this.color = Colors.white});

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

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color;
    canvas.drawRRect(sleeve, line);
    canvas.drawRRect(tip, line);
  }

  @override
  bool shouldRepaint(covariant EraserPainter oldDelegate) =>
      oldDelegate.color != color;
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

/// 多機能ボタン（…）タップ時に出るアクションシート。
/// 結果は文字列キー（e.g. 'pinToCalendar'）で pop される。null = キャンセル。
/// hasEventDate でカレンダー項目のラベルを切り替え：
/// - false（日付未付与）: 「カレンダーに載せる」
/// - true（既に日付付与済み）: 「日付を変える」
class _MultiActionSheet extends StatelessWidget {
  final bool hasEventDate;
  const _MultiActionSheet({required this.hasEventDate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 枠外タップで閉じる
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MultiActionItem(
                        icon: Icons.event_outlined,
                        iconColor: Colors.orange,
                        label:
                            hasEventDate ? '日付を変える' : 'カレンダーに載せる',
                        onTap: () =>
                            Navigator.of(context).pop('pinToCalendar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiActionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _MultiActionItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Hiragino Sans',
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
