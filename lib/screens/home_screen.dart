import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../widgets/memo_card.dart';
import '../widgets/memo_input_area.dart';
import '../widgets/move_to_top_icon.dart';
import '../widgets/new_tag_sheet.dart';
import '../widgets/trapezoid_tab_shape.dart';
import 'quick_sort_screen.dart';
import 'settings_screen.dart';
import 'todo_lists_screen.dart';

/// グリッドサイズ選択肢（Swift版GridSizeOption準拠 / 旧「全文」を 1×可変 に置き換え）
enum GridSizeOption {
  grid3x6('3×6', 3),
  grid2x5('2×5', 2),
  grid2x3('2×3', 2),
  grid1x2('1×2', 1),
  // 旧「全文(無制限)」を廃止し、本文 max 15行の 1列可変高さに置き換え
  grid1flex('1×可変', 1),
  titleOnly('タイトルのみ', 2);

  final String label;
  final int columns;
  const GridSizeOption(this.label, this.columns);
}

/// 「よく見る」フォルダ専用グリッドオプション
enum FrequentGridOption {
  grid2x5('2×5', 5, GridSizeOption.grid2x5),
  grid2x3('2×3', 3, GridSizeOption.grid2x3),
  // 旧「2×1(全文)」を廃止し、2×可変 (本文 max 15行) に置き換え
  grid2flex('2×可変', 0, GridSizeOption.grid1flex),
  titleOnly('タイトルのみ', 0, GridSizeOption.titleOnly);

  final String label;
  /// 各列で表示する行数（高さ計算用）。0 = 高さ固定しない
  final int rows;
  /// カード描画に使う GridSizeOption（フォントやパディング決定用）
  final GridSizeOption cardGridSize;
  const FrequentGridOption(this.label, this.rows, this.cardGridSize);
}

/// ホーム画面（Swift版レイアウト準拠）
/// 上: メモ入力エリア常駐
/// 中: 機能バー + 親タグタブ + 子タグドロワー
/// 下: メモグリッド + ボトムバー
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// タブの特殊キー
const String kAllTabKey = '__all__';
const String kUntaggedTabKey = '__untagged__';
const String kFrequentTabKey = '__frequent__';

// メモ複数選択モード（本家準拠）
enum _SelectMode { none, delete, moveToTop }

// 特殊タブの種類（長押しメニュー・色変更で使う）
enum _SpecialKind { all, untagged, frequent }

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  // タブの順序（特殊タブも親タグもキーで統一管理）
  // null の場合はビルド時に初期化
  List<String>? _tabOrder;
  // 選択中のタブ（キー指定）
  String _selectedTabKey = kAllTabKey;
  // 子タグドロワー (0=閉, 1=開) — ドロワー本体と件数バー/メモグリッドのスライドを同期させる
  late final AnimationController _drawerCtrl;
  bool _childDrawerOpen = false;
  double _drawerAnimTarget = 0;
  String? _selectedChildTagId;

  // 子タグドロワー Spring パラメータ (本家 spring(response:0.35, dampingFraction:0.8) 相当)
  static const _drawerSpring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 28.7,
  );

  void _animateDrawer(bool open) {
    final target = open ? 1.0 : 0.0;
    if (target == _drawerAnimTarget) return;
    _drawerAnimTarget = target;
    final sim = SpringSimulation(_drawerSpring, _drawerCtrl.value, target, 0);
    _drawerCtrl.animateWith(sim);
  }
  // グリッドサイズ
  GridSizeOption _gridSize = GridSizeOption.grid2x3;
  // 「よく見る」フォルダ専用グリッドサイズ
  FrequentGridOption _frequentGridSize = FrequentGridOption.grid2x5;
  // フォルダ並び替えモード
  bool _isReorderMode = false;
  // メモ複数選択モード（削除 or トップに移動）
  _SelectMode _selectMode = _SelectMode.none;
  final Set<String> _selectedMemoIds = <String>{};
  bool get _isSelectMode => _selectMode != _SelectMode.none;
  bool get _isFrequentTab => _selectedTabKey == kFrequentTabKey;
  bool get _isAllTab => _selectedTabKey == kAllTabKey;

  void _enterSelectMode(_SelectMode mode) {
    setState(() {
      _selectMode = mode;
      _selectedMemoIds.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = _SelectMode.none;
      _selectedMemoIds.clear();
    });
  }

  void _toggleMemoSelection(Memo memo) {
    if (memo.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1500),
          content: Text('このメモはロック中です'),
        ),
      );
      return;
    }
    setState(() {
      if (_selectedMemoIds.contains(memo.id)) {
        _selectedMemoIds.remove(memo.id);
      } else {
        _selectedMemoIds.add(memo.id);
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedMemoIds.length;
    if (count == 0) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('$count件のメモを削除します。よろしいですか？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = ref.read(databaseProvider);
    await db.deleteMemos(_selectedMemoIds.toList());
    if (mounted) _exitSelectMode();
  }

  Future<void> _moveSelectedToTop() async {
    if (_selectedMemoIds.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.moveMemosToTop(_selectedMemoIds.toList());
    if (mounted) _exitSelectMode();
  }

  /// メモグリッドの左右スワイプで隣のタブへ切替
  /// 本家準拠: 両端でループ
  void _switchToAdjacentTab(int delta) {
    final order = _tabOrder;
    if (order == null || order.isEmpty) return;
    final cur = order.indexOf(_selectedTabKey);
    if (cur < 0) return;
    var next = cur + delta;
    if (next < 0) next = order.length - 1;
    if (next >= order.length) next = 0;
    setState(() {
      _selectedTabKey = order[next];
      _selectedChildTagId = null;
      _childDrawerOpen = false;
      _selectMode = _SelectMode.none;
      _selectedMemoIds.clear();
    });
    _animateDrawer(false);
  }

  // スワイプ・タブ切替時のスライドイン方向 (true: 右から、false: 左から)
  bool _slideFromRight = true;
  // タブ切替アニメ duration: フリック時のみ 280ms、タップ等は 0 (即時)
  int _tabAnimMs = 0;

  void _onSwipeEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    // 最低 300px/s のフリック速度
    if (v.abs() < 300) return;
    setState(() {
      _slideFromRight = v < 0;
      _tabAnimMs = 280;
    });
    if (v < 0) {
      _switchToAdjacentTab(1); // 左フリック → 次のタブ
    } else {
      _switchToAdjacentTab(-1); // 右フリック → 前のタブ
    }
    // アニメ完了後に 0 に戻す (次のタップ切替を即時化)
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted && _tabAnimMs != 0) {
        setState(() => _tabAnimMs = 0);
      }
    });
  }
  // タブバーのスクロール位置を並び替え前後で保持
  final ScrollController _tabBarScrollController = ScrollController();
  double _savedTabBarOffset = 0;
  // キャンセル時に戻すための並び替え前のタブ順スナップショット
  List<String>? _savedTabOrder;
  // 入力エリア用
  String? _editingMemoId;
  // 新規作成ボタンを押すたびに増えるカウンタ → MemoInputArea がフォーカスを取る
  int _focusInputTrigger = 0;
  // 入力エリアの最大化状態
  bool _isInputExpanded = false;
  // 入力エリアへの GlobalKey（フロート消しゴムから clearBody() を呼ぶ）
  final _inputAreaKey = GlobalKey<MemoInputAreaState>();
  // 検索 (ヘッダの全フォルダ横断検索)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool get _isSearchActive => _searchQuery.isNotEmpty;

  // 他の操作 (タブ切替/メモを開く/新規作成/etc) のときに自動でクリア
  void _clearSearchIfActive() {
    if (_searchQuery.isEmpty) return;
    _searchController.clear();
    _searchQuery = '';
    // setState は呼び出し側でする (余計な rebuild を避ける)
  }

  // フォルダ内検索 (虫眼鏡ボタンから入る、現在のフォルダのみが対象)
  bool _isInFolderSearch = false;
  String? _folderSearchTagId; // 検索対象の親タグID
  String _folderSearchTagName = '';
  final TextEditingController _folderSearchController =
      TextEditingController();
  String _folderSearchQuery = '';

  void _enterFolderSearch(List<Tag> parentTags) {
    final id = _currentParentTagId(parentTags);
    if (id == null) return;
    final tag = parentTags.where((t) => t.id == id).firstOrNull;
    setState(() {
      _isInFolderSearch = true;
      _folderSearchTagId = id;
      _folderSearchTagName = tag?.name ?? '';
      _folderSearchQuery = '';
      _folderSearchController.clear();
      _selectMode = _SelectMode.none;
      _selectedMemoIds.clear();
    });
  }

  void _exitFolderSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isInFolderSearch = false;
      _folderSearchTagId = null;
      _folderSearchTagName = '';
      _folderSearchQuery = '';
      _folderSearchController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _drawerCtrl = AnimationController.unbounded(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    _tabBarScrollController.dispose();
    _searchController.dispose();
    _folderSearchController.dispose();
    super.dispose();
  }

  /// 親タグリストと既存の_tabOrderを同期して新しいタブ順序を返す
  List<String> _syncTabOrder(List<Tag> parentTags) {
    final tagIds = parentTags.map((t) => t.id).toSet();
    final existing = _tabOrder ?? <String>[];
    // 既存リストから消えたタグを除く
    final result = existing
        .where((k) =>
            k == kAllTabKey ||
            k == kUntaggedTabKey ||
            k == kFrequentTabKey ||
            tagIds.contains(k))
        .toList();
    // 特殊タブが無ければ先頭に追加（よく見る → すべて → タグなし）
    if (!result.contains(kFrequentTabKey)) result.insert(0, kFrequentTabKey);
    if (!result.contains(kAllTabKey)) {
      final freqIdx = result.indexOf(kFrequentTabKey);
      result.insert(freqIdx + 1, kAllTabKey);
    }
    if (!result.contains(kUntaggedTabKey)) {
      final allIdx = result.indexOf(kAllTabKey);
      result.insert(allIdx + 1, kUntaggedTabKey);
    }
    // 新しいタグを末尾に追加
    for (final id in tagIds) {
      if (!result.contains(id)) result.add(id);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final parentTagsAsync = ref.watch(parentTagsProvider);
    final parentTags = parentTagsAsync.valueOrNull ?? const <Tag>[];
    _tabOrder = _syncTabOrder(parentTags);
    final currentColor = _currentTabColor(parentTags);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // キーボードでオーバーフローしないように
      // 入力欄以外の任意の場所をタップしたらキーボード+コンテキストメニューを閉じる
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          ContextMenuController.removeAny();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Stack(
          children: [
            _buildMainContent(parentTags, parentTagsAsync, currentColor),
            // キーボードの右上に丸いキーボード収納ボタン（キーボード表示中のみ）
            if (MediaQuery.of(context).viewInsets.bottom > 0)
              Positioned(
                right: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 6,
                child: _buildKeyboardAccessory(),
              ),
            // 最大化中 + キーボード表示中: 縮小ボタンを収納ボタンの左にフロート
            if (_isInputExpanded &&
                MediaQuery.of(context).viewInsets.bottom > 0)
              Positioned(
                right: 10 + 36 + 8, // 収納ボタン (36) の左に8px間隔
                bottom: MediaQuery.of(context).viewInsets.bottom + 6,
                child: _buildFloatingMinimizeButton(),
              ),
            // 最大化中 + キーボード表示中: 消しゴムボタンを左にフロート
            if (_isInputExpanded &&
                MediaQuery.of(context).viewInsets.bottom > 0)
              Positioned(
                left: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 6,
                child: _buildFloatingEraserButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardAccessory() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.keyboard_hide,
            size: 20, color: Colors.white),
      ),
    );
  }

  /// IMEコミット＋縮小
  void _minimizeWithCommit() {
    _inputAreaKey.currentState?.commitIME();
    setState(() => _isInputExpanded = false);
  }

  // 最大化中にキーボード収納ボタンの左に出るフロート縮小ボタン
  Widget _buildFloatingMinimizeButton() {
    return GestureDetector(
      onTap: _minimizeWithCommit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.close_fullscreen,
            size: 18, color: Colors.white),
      ),
    );
  }

  // 最大化中にキーボード左上にフロートする消しゴムボタン
  Widget _buildFloatingEraserButton() {
    final state = _inputAreaKey.currentState;
    final hasContent = state?.hasContent ?? false;
    final isFocused = state?.isContentFocused ?? false;
    return GestureDetector(
      onTap: hasContent ? () => state?.clearBody() : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (isFocused && hasContent)
              ? Colors.orange.withValues(alpha: 0.6)
              : const Color.fromRGBO(142, 142, 147, 0.15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: EraserGlyph(),
        ),
      ),
    );
  }

  /// タグ履歴リスト（フォルダタブ右上にオーバーレイ）
  Widget _buildTagHistoryList() {
    final state = _inputAreaKey.currentState;
    final items = state?.tagHistoryItems ?? [];
    final allTags = ref.watch(allTagsProvider).value ?? const <Tag>[];

    return Container(
      constraints: const BoxConstraints(maxWidth: 220, maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
            child: Row(
              children: [
                const Text('タグ履歴',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: '.SF Pro Rounded',
                    )),
                const Spacer(),
                GestureDetector(
                  onTap: () => state?.closeTagHistory(),
                  child: Icon(CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: Colors.grey.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          // リスト
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('まだ履歴がありません',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final parentTag = allTags
                      .where((t) => t.id == item.parentTagId)
                      .firstOrNull;
                  if (parentTag == null) return const SizedBox.shrink();
                  final childTag = item.childTagId != null
                      ? allTags
                          .where((t) => t.id == item.childTagId)
                          .firstOrNull
                      : null;

                  return GestureDetector(
                    onTap: () => state?.selectFromHistory(item),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 親タグバッジ
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: TagColors.getColor(parentTag.colorIndex),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              parentTag.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: '.SF Pro Rounded',
                              ),
                            ),
                          ),
                          // 子タグバッジ
                          if (childTag != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: TagColors.getColor(childTag.colorIndex),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                childTag.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: '.SF Pro Rounded',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<Tag> parentTags,
      AsyncValue<List<Tag>> parentTagsAsync, Color currentColor) {
    return Padding(
        // SafeAreaを使わず手動で上部パディング制御。
        // 下部はフォルダ色をホームインジケータ下まで延ばすため、ここではpaddingしない
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).viewPadding.top - 4,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
          children: [
            // 1. 検索バー / 最大化中はミニバー (戻る + 設定のみ)
            if (_isInputExpanded)
              _buildExpandedTopBar()
            else
              _buildSearchBar(),
            // 2. メモ入力エリア
            // 最大化中: トップバー分を引いた残りの85%（下に余白を残す）
            if (_isInputExpanded)
              SizedBox(
                height: (constraints.maxHeight - 44) * 0.95,
                child: MemoInputArea(
                  key: _inputAreaKey,
                  editingMemoId: _editingMemoId,
                  onMemoCreated: (id) {
                    _clearSearchIfActive();
                    setState(() => _editingMemoId = id);
                  },
                  onClosed: () => setState(() => _editingMemoId = null),
                  selectedParentTagId: _currentParentTagId(parentTags),
                  selectedChildTagId: _selectedChildTagId,
                  focusRequest: _focusInputTrigger,
                  isExpanded: true,
                  onToggleExpanded: () =>
                      setState(() => _isInputExpanded = false),
                ),
              )
            else ...[
              MemoInputArea(
                key: _inputAreaKey,
                editingMemoId: _editingMemoId,
                onMemoCreated: (id) {
                  _clearSearchIfActive();
                  setState(() => _editingMemoId = id);
                },
                onClosed: () => setState(() => _editingMemoId = null),
                selectedParentTagId: _currentParentTagId(parentTags),
                selectedChildTagId: _selectedChildTagId,
                focusRequest: _focusInputTrigger,
                isExpanded: false,
                onToggleExpanded: () =>
                    setState(() => _isInputExpanded = true),
              ),
              // 3. 機能バー（爆速・ToDo・ドロワーハンドル）
              _buildFunctionBar(),
              // 4. 親タグタブ（検索/フォルダ内検索中は専用タブに切替）
              if (_isSearchActive)
                _wrapWithCloseButton(_buildSearchResultTab(), () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  FocusScope.of(context).unfocus();
                })
              else if (_isInFolderSearch)
                _wrapWithCloseButton(
                    _buildFolderSearchTab(), _exitFolderSearch)
              else
                parentTagsAsync.when(
                  data: (tags) => _buildTabBar(tags),
                  loading: () => const SizedBox(height: 40),
                  error: (_, _) => const SizedBox(height: 40),
                ),
            ],
            // 5〜8. フォルダ本体（タブと一体化したカラー領域）
            // 下部ボタン類（ゴミ箱・上へ移動・メモ作成・グリッド数）はフォルダ内フロート
            // 最大化中は非表示
            if (!_isInputExpanded)
            Expanded(
              child: Container(
                color: (_isSearchActive || _isInFolderSearch)
                    ? const Color(0xFFE0E8F0) // 検索モード用の薄水色
                    : currentColor,
                child: Stack(
                  // 閉じるボタンを上方向にはみ出させるためクリップ無効
                  clipBehavior: Clip.none,
                  children: [
                    // 検索中: 検索結果ビュー
                    // 通常: 件数バー + メモグリッド（ドロワー展開時はその分下にスライド）
                    if (_isSearchActive)
                      _SearchResultsView(
                        query: _searchQuery,
                        onTapMemo: _openMemo,
                        onLongPressMemo: (m) => _showMemoActions(m),
                      )
                    else if (_isInFolderSearch)
                      _FolderSearchView(
                        parentTagId: _folderSearchTagId!,
                        controller: _folderSearchController,
                        query: _folderSearchQuery,
                        onQueryChanged: (v) =>
                            setState(() => _folderSearchQuery = v.trim()),
                        onTapMemo: _openMemo,
                        onLongPressMemo: (m) => _showMemoActions(m),
                      )
                    else
                      // 左右スワイプでタブ切替（選択モード/並び替え中は無効）
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragEnd:
                            (_isSelectMode || _isReorderMode)
                                ? null
                                : _onSwipeEnd,
                        child: AnimatedBuilder(
                          animation: _drawerCtrl,
                          builder: (context, child) {
                            final t = _drawerCtrl.value.clamp(0.0, 1.0);
                            return Padding(
                              padding: EdgeInsets.only(top: 43 * t),
                              child: child,
                            );
                          },
                          // タブ切替時にスライドイン (フリック時のみ。タップ時は即時)
                          child: ClipRect(
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: _tabAnimMs),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final isCurrent =
                                    (child.key as ValueKey?)?.value ==
                                        _selectedTabKey;
                                if (isCurrent) {
                                  return SlideTransition(
                                    position: animation.drive(Tween(
                                      begin: Offset(
                                          _slideFromRight ? 1 : -1, 0),
                                      end: Offset.zero,
                                    )),
                                    child: child,
                                  );
                                }
                                return FadeTransition(
                                    opacity: animation, child: child);
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_selectedTabKey),
                                child: Column(
                                  children: [
                                    _buildCountBar(parentTags),
                                    Expanded(
                                      child: parentTagsAsync.when(
                                        data: (tags) => _buildMemoGrid(tags),
                                        loading: () => const Center(
                                            child: CircularProgressIndicator()),
                                        error: (e, _) => Center(
                                            child: Text('エラー: $e')),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 子タグドロワー（フォルダ右上、検索中・フォルダ内検索中は非表示）
                    if (!_isSearchActive &&
                        !_isInFolderSearch &&
                        _currentParentTagId(parentTags) != null)
                      Positioned(
                        top: 7,
                        right: 0,
                        child: _ChildTagDrawer(
                          parentTagId: _currentParentTagId(parentTags)!,
                          controller: _drawerCtrl,
                          selectedChildId: _selectedChildTagId,
                          onToggle: () {
                            final next = !_childDrawerOpen;
                            setState(() => _childDrawerOpen = next);
                            _animateDrawer(next);
                          },
                          onSelectChild: (id) =>
                              setState(() => _selectedChildTagId = id),
                          onAddChild: () => _addChildTag(
                              _currentParentTagId(parentTags)!),
                        ),
                      ),
                    // タグ履歴オーバーレイ（ルーレット展開中のみ）
                    if (_inputAreaKey.currentState?.showTagHistory ?? false)
                      Positioned(
                        right: 8,
                        top: -10,
                        child: _buildTagHistoryList(),
                      ),
                    // 並び替え中: フォルダ本体に説明 + ボタン
                    if (_isReorderMode)
                      Positioned.fill(
                        child: _buildReorderOverlay(),
                      ),
                    // フロートする下部ボタン群（検索中・並び替え中・フォルダ内検索中は非表示）
                    if (!_isReorderMode &&
                        !_isSearchActive &&
                        !_isInFolderSearch)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom:
                            MediaQuery.of(context).viewPadding.bottom + 8,
                        child: _buildFloatingBottomBar(parentTags),
                      ),
                    // 親タグフォルダ表示中のみ虫眼鏡ボタン (グリッドボタンの上に浮かぶ)
                    if (!_isReorderMode &&
                        !_isSearchActive &&
                        !_isInFolderSearch &&
                        !_isSelectMode &&
                        _currentParentTagId(parentTags) != null)
                      Positioned(
                        right: 12,
                        bottom: MediaQuery.of(context).viewPadding.bottom +
                            8 +
                            48 +
                            6,
                        child: _buildFolderSearchButton(parentTags),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _currentParentTagId(List<Tag> parentTags) {
    if (_selectedTabKey == kAllTabKey ||
        _selectedTabKey == kUntaggedTabKey ||
        _selectedTabKey == kFrequentTabKey) {
      return null;
    }
    // 選択中キーが親タグID
    return parentTags.any((t) => t.id == _selectedTabKey)
        ? _selectedTabKey
        : null;
  }

  /// 現在選択中タブの色（フォルダ背景用）
  Color _currentTabColor(List<Tag> parentTags) {
    if (_selectedTabKey == kAllTabKey) {
      final idx = ref.read(allTabColorIndexProvider);
      return idx < 0 ? TagColors.allTabColor : TagColors.getColor(idx);
    }
    if (_selectedTabKey == kUntaggedTabKey) {
      return TagColors.getColor(ref.read(untaggedTabColorIndexProvider));
    }
    if (_selectedTabKey == kFrequentTabKey) {
      return TagColors.getColor(ref.read(frequentTabColorIndexProvider));
    }
    final tag = parentTags.where((t) => t.id == _selectedTabKey).firstOrNull;
    if (tag == null) return TagColors.palette[0];
    return TagColors.getColor(tag.colorIndex);
  }

  // ========================================
  // 1. 検索バー
  // ========================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
      child: Row(
        children: [
          // ＋ボタン（小さめ、線太め）
          GestureDetector(
            onTap: _createNewMemo,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1.5),
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.black87),
            ),
          ),
          const Spacer(),
          // 検索バー（中央配置、固定幅、入力可能）
          SizedBox(
            width: 220,
            height: 32,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.grey[200],
                hintText: 'メモを探す',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                prefixIcon:
                    Icon(Icons.search, size: 16, color: Colors.grey[500]),
                prefixIconConstraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
                suffixIcon: _isSearchActive
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                        child: Icon(Icons.cancel,
                            size: 16, color: Colors.grey[500]),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Spacer(),
          // 設定ギア（線画細め、サイズ統一）
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: const Icon(CupertinoIcons.gear_big,
                size: 26, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  /// 最大化中の上部バー（戻る矢印 + 確定ボタン）
  Widget _buildExpandedTopBar() {
    final isEditing = MediaQuery.of(context).viewInsets.bottom > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
      child: Row(
        children: [
          // 戻る（縮小）矢印
          GestureDetector(
            onTap: _minimizeWithCommit,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(CupertinoIcons.back,
                    size: 22, color: Color(0xFF007AFF)),
              ),
            ),
          ),
          const Spacer(),
          // 確定ボタン（入力中のみアクティブ、押すとキーボード閉じる）
          GestureDetector(
            onTap: isEditing
                ? () => FocusScope.of(context).unfocus()
                : null,
            behavior: HitTestBehavior.opaque,
            child: Text(
              '確定',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isEditing
                    ? const Color(0xFF007AFF)
                    : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // 3. 機能バー
  // ========================================
  Widget _buildFunctionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // 爆速モード
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuickSortScreen()),
            ),
            child: const Icon(Icons.bolt, size: 22, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          // ToDoリスト
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TodoListsScreen()),
            ),
            child: const Icon(Icons.checklist, size: 22, color: Colors.green),
          ),
          const Spacer(),
          // ドロワーハンドル（上下のシェブロン）
          const Icon(Icons.expand_less, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  // ========================================
  // 4. 親タグタブ
  // ========================================
  Widget _buildTabBar(List<Tag> parentTags) {
    // 並び替えモード: 専用UIに切り替え
    if (_isReorderMode) {
      return _buildReorderTabBar(parentTags);
    }

    final tabKeys = _tabOrder ?? const <String>[];
    // 選択中タブが消えてたら先頭にフォールバック
    if (!tabKeys.contains(_selectedTabKey) && tabKeys.isNotEmpty) {
      _selectedTabKey = tabKeys.first;
    }

    final tabs = <Widget>[
      for (int i = 0; i < tabKeys.length; i++)
        _buildTabFromKey(tabKeys[i], parentTags),
      _buildAddTab(),
    ];

    final selectedIdx = tabKeys.indexOf(_selectedTabKey);

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        controller: _tabBarScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        clipBehavior: Clip.none,
        child: _ZOrderedRow(
          selectedIndex: selectedIdx >= 0 ? selectedIdx : 0,
          overlap: 0, // 重ねず、隙間もゼロ
          children: tabs,
        ),
      ),
    );
  }

  /// キー（'__all__' / '__untagged__' / '__frequent__' / tag.id）からタブWidgetを作る
  Widget _buildTabFromKey(String key, List<Tag> parentTags) {
    // ScrollController による位置復元方式に変えたので GlobalKey は不要
    const Key? tabKey = null;
    if (key == kFrequentTabKey) {
      final colorIdx = ref.watch(frequentTabColorIndexProvider);
      return Builder(
        key: tabKey,
        builder: (ctx) => _buildTab(
          label: 'よく見る',
          color: TagColors.getColor(colorIdx),
          isSelected: _selectedTabKey == kFrequentTabKey,
          onTap: () {
            setState(() {
              _selectedTabKey = kFrequentTabKey;
              _childDrawerOpen = false;
              _selectedChildTagId = null;
              _selectMode = _SelectMode.none;
              _selectedMemoIds.clear();
            });
            _animateDrawer(false);
          },
          onLongPress: () {
            setState(() {
              _selectedTabKey = kFrequentTabKey;
              _childDrawerOpen = false;
              _selectedChildTagId = null;
              _selectMode = _SelectMode.none;
              _selectedMemoIds.clear();
            });
            _animateDrawer(false);
            _showSpecialTabActions(ctx, specialKind: _SpecialKind.frequent);
          },
        ),
      );
    }
    if (key == kAllTabKey) {
      final colorIdx = ref.watch(allTabColorIndexProvider);
      final color = colorIdx < 0
          ? TagColors.allTabColor
          : TagColors.getColor(colorIdx);
      return Builder(
        key: tabKey,
        builder: (ctx) => _buildTab(
          label: 'すべて',
          color: color,
          isSelected: _selectedTabKey == kAllTabKey,
          onTap: () {
            setState(() {
              _selectedTabKey = kAllTabKey;
              _childDrawerOpen = false;
              _selectedChildTagId = null;
              _selectMode = _SelectMode.none;
              _selectedMemoIds.clear();
            });
            _animateDrawer(false);
          },
          onLongPress: () {
            setState(() {
              _selectedTabKey = kAllTabKey;
              _childDrawerOpen = false;
              _selectedChildTagId = null;
            });
            _animateDrawer(false);
            _showSpecialTabActions(ctx, specialKind: _SpecialKind.all);
          },
        ),
      );
    }
    if (key == kUntaggedTabKey) {
      final colorIdx = ref.watch(untaggedTabColorIndexProvider);
      return Builder(
        key: tabKey,
        builder: (ctx) => _buildTab(
          label: 'タグなし',
          color: TagColors.getColor(colorIdx),
          isSelected: _selectedTabKey == kUntaggedTabKey,
          onTap: () {
            setState(() {
              _selectedTabKey = kUntaggedTabKey;
              _childDrawerOpen = false;
              _selectedChildTagId = null;
              _selectMode = _SelectMode.none;
              _selectedMemoIds.clear();
            });
            _animateDrawer(false);
          },
          onLongPress: () {
            setState(() {
              _selectedTabKey = kUntaggedTabKey;
              _childDrawerOpen = false;
              _selectedChildTagId = null;
            });
            _animateDrawer(false);
            _showSpecialTabActions(ctx, specialKind: _SpecialKind.untagged);
          },
        ),
      );
    }
    // 親タグ
    final tag = parentTags.where((t) => t.id == key).firstOrNull;
    if (tag == null) return const SizedBox.shrink();
    return Builder(
      key: tabKey,
      builder: (ctx) => _buildTab(
        label: tag.name,
        color: TagColors.getColor(tag.colorIndex),
        isSelected: _selectedTabKey == key,
        onTap: () {
          setState(() {
            _selectedTabKey = key;
            _selectedChildTagId = null;
            _childDrawerOpen = false;
            _selectMode = _SelectMode.none;
            _selectedMemoIds.clear();
          });
          _animateDrawer(false);
        },
        onLongPress: () {
          setState(() {
            _selectedTabKey = key;
            _selectedChildTagId = null;
            _childDrawerOpen = false;
            _selectMode = _SelectMode.none;
            _selectedMemoIds.clear();
          });
          _animateDrawer(false);
          _showTagActionsFromContext(ctx, tag);
        },
      ),
    );
  }

  /// 並び替えモード時のタブバー: 全タブ（特殊+親タグ）対応
  Widget _buildReorderTabBar(List<Tag> parentTags) {
    final keys = List<String>.from(_tabOrder ?? const <String>[]);

    return SizedBox(
      height: 40,
      child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              buildDefaultDragHandles: false,
              itemCount: keys.length,
              proxyDecorator: (child, index, animation) {
                return Transform.scale(
                  scale: 1.15,
                  child: Material(
                    color: Colors.transparent,
                    child: child,
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                final newOrder = List<String>.from(keys);
                final moved = newOrder.removeAt(oldIndex);
                newOrder.insert(newIndex, moved);
                setState(() => _tabOrder = newOrder);
                // 親タグだけDBに保存（特殊タブはメモリのみ）
                final parentIds = newOrder
                    .where((k) =>
                        k != kAllTabKey && k != kUntaggedTabKey)
                    .toList();
                await ref
                    .read(databaseProvider)
                    .reorderParentTags(parentIds);
              },
              itemBuilder: (ctx, i) {
                final key = keys[i];
                return _WigglingReorderTab(
                  key: ValueKey('reorder_$key'),
                  index: i,
                  tabKey: key,
                  parentTags: parentTags,
                  allTabColorIndex:
                      ref.watch(allTabColorIndexProvider),
                  untaggedColorIndex:
                      ref.watch(untaggedTabColorIndexProvider),
                  onTouch: () {
                    if (_selectedTabKey != key) {
                      setState(() {
                        _selectedTabKey = key;
                        _selectedChildTagId = null;
                        _childDrawerOpen = false;
                      });
                      _animateDrawer(false);
                    }
                  },
                );
              },
      ),
    );
  }

  /// 並び替えモード時のフォルダ本体オーバーレイ（背景グレーアウト + 上部に説明 + ボタン）
  Widget _buildReorderOverlay() {
    return Stack(
      children: [
        // 背景の半透明グレー（メモカードをグレーアウト）
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // メモへのタップ抑止
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
        // 上寄せの説明 + ボタン
        Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz,
                    size: 48, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'ドラッグで並び替え',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Hiragino Sans',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // キャンセル
                    GestureDetector(
                      onTap: _cancelReorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Text(
                          'キャンセル',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Hiragino Sans',
                            color: Color(0xCC000000),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 完了
                    GestureDetector(
                      onTap: _finishReorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Text(
                          '完了',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Hiragino Sans',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _finishReorder() {
    setState(() => _isReorderMode = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabBarScrollController.hasClients) {
        final max = _tabBarScrollController.position.maxScrollExtent;
        _tabBarScrollController
            .jumpTo(_savedTabBarOffset.clamp(0.0, max));
      }
    });
  }

  void _cancelReorder() {
    // 並び替え結果を破棄して元の順序に戻す
    if (_savedTabOrder != null) {
      setState(() {
        _tabOrder = List<String>.from(_savedTabOrder!);
        _isReorderMode = false;
      });
      // 親タグの順序もDBに保存（並び替え前の状態に戻す）
      final parentIds = _tabOrder!
          .where((k) => k != kAllTabKey && k != kUntaggedTabKey)
          .toList();
      ref.read(databaseProvider).reorderParentTags(parentIds);
    } else {
      setState(() => _isReorderMode = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabBarScrollController.hasClients) {
        final max = _tabBarScrollController.position.maxScrollExtent;
        _tabBarScrollController
            .jumpTo(_savedTabBarOffset.clamp(0.0, max));
      }
    });
  }

  /// 検索系タブの右端に閉じるボタンを重ねるラッパー
  Widget _wrapWithCloseButton(Widget tabWidget, VoidCallback onClose) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tabWidget,
        Positioned(
          top: 7,
          right: 22,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.grey.shade500,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.xmark,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// フォルダ内検索中のタブバー: 「"○○"フォルダ内の検索」のフォルダタブ
  Widget _buildFolderSearchTab() {
    return GestureDetector(
      // タブをタップで終了
      onTap: _exitFolderSearch,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CustomPaint(
            painter: TrapezoidTabPainter(
              color: const Color(0xFFD8E3EE),
              shadows: const [
                Shadow(
                  color: Color(0x4D000000),
                  offset: Offset(-3, 3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Text(
                  '"$_folderSearchTagName" フォルダ内の検索',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  strutStyle: const StrutStyle(
                    fontSize: 14,
                    height: 1.0,
                    forceStrutHeight: true,
                    leading: 0,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.0,
                    fontFamily: 'Hiragino Sans',
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 虫眼鏡フロートボタン (グリッドボタンの真上にフロート)
  Widget _buildFolderSearchButton(List<Tag> parentTags) {
    return GestureDetector(
      onTap: () => _enterFolderSearch(parentTags),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _capsuleFill,
          shape: BoxShape.circle,
          border: Border.all(color: _capsuleStroke, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(CupertinoIcons.search,
            size: 18, color: _secondary),
      ),
    );
  }

  /// 検索中のタブバー: 「"query" の検索結果」のフォルダタブ1個
  Widget _buildSearchResultTab() {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CustomPaint(
          painter: TrapezoidTabPainter(
            color: const Color(0xFFD8E3EE), // 薄水色
            shadows: const [
              Shadow(
                color: Color(0x4D000000),
                offset: Offset(-3, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(
                '"$_searchQuery" の検索結果',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                strutStyle: const StrutStyle(
                  fontSize: 14,
                  height: 1.0,
                  forceStrutHeight: true,
                  leading: 0,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.0,
                  fontFamily: 'Hiragino Sans',
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 末尾の「+」追加タブ（親タグ追加。挙動はルーレットの親タグ追加と同じ）
  Widget _buildAddTab() {
    final addTab = CustomPaint(
      painter: TrapezoidTabPainter(
        color: Colors.grey.shade300,
        shadows: const [],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Icon(Icons.add, size: 16, color: Colors.black54),
      ),
    );
    return GestureDetector(
      onTap: () => NewTagSheet.show(context: context),
      child: addTab,
    );
  }

  Widget _buildTab({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    // タグ名を最大5文字に
    final displayLabel =
        label.length > 5 ? '${label.substring(0, 5)}...' : label;

    // 本家準拠: 選択/非選択ともに色そのまま、違いはテキスト色・影・スケールのみ
    final bgColor = color;

    final tab = CustomPaint(
      painter: TrapezoidTabPainter(
        color: bgColor,
        shadows: isSelected
            ? [
                const Shadow(
                  color: Color(0x4D000000), // black 0.3
                  offset: Offset(-3, 3),
                  blurRadius: 4,
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          displayLabel,
          // 行高1.0で詰める＋strutで余分な leading を削除
          strutStyle: const StrutStyle(
            fontSize: 14,
            height: 1.0,
            forceStrutHeight: true,
            leading: 0,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          style: TextStyle(
            fontSize: 14,
            height: 1.0,
            fontFamily: 'Hiragino Sans',
            leadingDistribution: TextLeadingDistribution.even,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.black54,
          ),
        ),
      ),
    );

    // 重なり制御は親 _ZOrderedRow が overlap で行う
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      // 1.08倍スケール（下端基点）
      child: Transform.scale(
        scale: isSelected ? 1.08 : 1.0,
        alignment: Alignment.bottomCenter,
        child: tab,
      ),
    );
  }


  // ========================================
  // 6. 件数バー
  // ========================================
  Widget _buildCountBar(List<Tag> parentTags) {
    // 本家準拠: 高さ37px（drawerBandHeight）。テキストは縦中央に近い位置
    final parentId = _currentParentTagId(parentTags);
    final tabColor = _currentTabColor(parentTags);
    // 選択モード中はガイドテキストを中央表示
    if (_isSelectMode) {
      return Container(
        height: 37,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Text(
          _selectMode == _SelectMode.delete
              ? '削除するメモを選択してください'
              : 'トップに移動するメモを選択してください',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Hiragino Sans',
            color: _selectMode == _SelectMode.delete
                ? Colors.red
                : Colors.blue,
          ),
        ),
      );
    }
    // 「よく見る」タブは件数の代わりにガイドテキストを中央表示
    if (_isFrequentTab) {
      return Container(
        height: 37,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: const Text(
          'よく見るメモと最近見たメモ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: 'Hiragino Sans',
            color: Color(0x993C3C43),
          ),
        ),
      );
    }
    return Container(
      height: 37,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          _MemoCountText(
            tabKey: _selectedTabKey,
            childTagId: _selectedChildTagId,
          ),
          // 子タグフィルター中: 親-子 カプセルバッジ
          if (_selectedChildTagId != null && parentId != null) ...[
            const SizedBox(width: 6),
            _ParentChildBadge(
              parentTagId: parentId,
              childTagId: _selectedChildTagId!,
              tabColor: tabColor,
            ),
          ],
        ],
      ),
    );
  }

  // ========================================
  // 7. メモグリッド
  // ========================================
  Widget _buildMemoGrid(List<Tag> parentTags) {
    if (_selectedTabKey == kFrequentTabKey) {
      return _FrequentTabContent(
        gridOption: _frequentGridSize,
        tabColor: _currentTabColor(parentTags),
        onTap: _openMemo,
        wrapBuilder: (memo, card) => _wrapMemoInContextMenu(memo, card),
        selectMode: _isSelectMode,
        selectedIds: _selectedMemoIds,
        onToggleSelect: _toggleMemoSelection,
      );
    }
    if (_selectedTabKey == kAllTabKey) {
      return _MemoGridView(
        stream: ref.watch(allMemosProvider),
        gridSize: _gridSize,
        onTap: _openMemo,
        wrapBuilder: (memo, card) => _wrapMemoInContextMenu(memo, card),
        selectMode: _isSelectMode,
        selectedIds: _selectedMemoIds,
        onToggleSelect: _toggleMemoSelection,
      );
    } else if (_selectedTabKey == kUntaggedTabKey) {
      return _MemoGridView(
        stream: ref.watch(untaggedMemosProvider),
        gridSize: _gridSize,
        onTap: _openMemo,
        wrapBuilder: (memo, card) => _wrapMemoInContextMenu(memo, card),
        selectMode: _isSelectMode,
        selectedIds: _selectedMemoIds,
        onToggleSelect: _toggleMemoSelection,
      );
    } else {
      final parentId = _currentParentTagId(parentTags);
      if (parentId == null) return const SizedBox();
      final tagId = _selectedChildTagId ?? parentId;
      return _MemoGridView(
        stream: ref.watch(memosForTagProvider(tagId)),
        gridSize: _gridSize,
        onTap: _openMemo,
        // 親タグフォルダ表示時のみ子タグバッジ用にIDを渡す
        parentTagId: parentId,
        selectMode: _isSelectMode,
        selectedIds: _selectedMemoIds,
        onToggleSelect: _toggleMemoSelection,
        wrapBuilder: (memo, card) => _wrapMemoInContextMenu(memo, card),
      );
    }
  }

  // ========================================
  // 8. フォルダ内フロート ボトムバー
  // ========================================
  // 本家共通スタイル: Capsule + systemGray6 + gray0.4枠線 + 影(0.15, blur3, y1)
  static const Color _capsuleFill = Color(0xFFF2F2F7); // systemGray6
  static const Color _capsuleStroke = Color(0x66999999); // gray.opacity(0.4)
  static const Color _secondary = Color(0x993C3C43); // .secondary

  BoxDecoration _capsuleDeco() {
    return BoxDecoration(
      color: _capsuleFill,
      borderRadius: BorderRadius.circular(50),
      border: Border.all(color: _capsuleStroke, width: 1.0),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26000000), // black 0.15
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  // 選択モード中のボトムバー: 中央に大きな取消 + 実行ボタンを並べる
  Widget _buildSelectModeBottomBar() {
    final canExecute = _selectedMemoIds.isNotEmpty;
    final isDelete = _selectMode == _SelectMode.delete;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 取消（青カプセル + 白文字、大きめ）
          GestureDetector(
            onTap: _exitSelectMode,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '取消',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Hiragino Sans',
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 実行ボタン（削除 or トップに移動）テキストで大きく
          // 削除モードで選択ありの場合のみ「赤背景・白文字」に反転
          GestureDetector(
            onTap: canExecute
                ? (isDelete ? _confirmDeleteSelected : _moveSelectedToTop)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: (isDelete && canExecute)
                  ? BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : _capsuleDeco(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDelete) ...[
                    MoveToTopIcon(
                      size: 20,
                      color: canExecute ? Colors.black87 : _secondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    isDelete ? '削除' : 'トップに移動',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Hiragino Sans',
                      color: canExecute
                          ? (isDelete ? Colors.white : Colors.black87)
                          : _secondary,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomBar(List<Tag> parentTags) {
    if (_isSelectMode) return _buildSelectModeBottomBar();
    // 「よく見る」タブは特殊: トップに移動 / メモ作成 ボタンを出さない
    final hideMoveToTop = _isFrequentTab;
    final hideCreate = _isFrequentTab || _isAllTab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // ① ゴミ箱（円形カプセル, padding 10, アイコン17） → 削除選択モードへ
          GestureDetector(
            onTap: () => _enterSelectMode(_SelectMode.delete),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: _capsuleDeco(),
              child: const Icon(CupertinoIcons.delete_simple,
                  size: 17, color: _secondary),
            ),
          ),
          if (!hideMoveToTop) const SizedBox(width: 8),
          // ② トップに移動 → トップ移動選択モードへ
          if (!hideMoveToTop)
            GestureDetector(
              onTap: () => _enterSelectMode(_SelectMode.moveToTop),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: _capsuleDeco(),
                child: const MoveToTopIcon(size: 20, color: _secondary),
              ),
            ),
          const Spacer(),
          // ③ このフォルダにメモ作成（青文字、本家は2行）
          if (!hideCreate)
            GestureDetector(
              onTap: () => _createMemoInFolder(parentTags),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: _capsuleDeco(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.add_circled,
                            size: 15, color: Colors.blue),
                        SizedBox(width: 5),
                        Text('このフォルダに',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Hiragino Sans',
                              color: Colors.blue,
                              height: 1.0,
                            )),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('メモ作成',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Hiragino Sans',
                          color: Colors.blue,
                          height: 1.0,
                        )),
                  ],
                ),
              ),
            ),
          if (!hideCreate) const Spacer(),
          // ④ グリッドサイズ（よく見るタブは別オプション）
          Builder(
            builder: (btnContext) {
              final label = _isFrequentTab
                  ? _frequentGridSize.label
                  : _gridSize.label;
              return GestureDetector(
                onTap: () => _showGridSizeMenu(btnContext),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: _capsuleDeco(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.square_grid_2x2,
                          size: 15, color: _secondary),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Hiragino Sans',
                          color: _secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ========================================
  // グリッドサイズ メニュー（すりガラスポップオーバー）
  // ========================================
  Future<void> _showGridSizeMenu(BuildContext btnContext) async {
    final renderBox = btnContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay =
        Overlay.of(btnContext).context.findRenderObject() as RenderBox;
    final btnTopLeft =
        renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final btnSize = renderBox.size;
    final btnRect = Rect.fromLTWH(
      btnTopLeft.dx,
      btnTopLeft.dy,
      btnSize.width,
      btnSize.height,
    );

    // 「よく見る」タブ専用メニュー
    if (_isFrequentTab) {
      final selected = await showGeneralDialog<FrequentGridOption>(
        context: btnContext,
        barrierDismissible: true,
        barrierLabel: 'gridSizeMenu',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, _, _) {
          return _FrequentGridSizeMenuOverlay(
            current: _frequentGridSize,
            buttonRect: btnRect,
          );
        },
        transitionBuilder: (_, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      );
      if (selected != null) {
        setState(() => _frequentGridSize = selected);
      }
      return;
    }

    final selected = await showGeneralDialog<GridSizeOption>(
      context: btnContext,
      barrierDismissible: true,
      barrierLabel: 'gridSizeMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, _) {
        return _GridSizeMenuOverlay(
          current: _gridSize,
          buttonRect: btnRect,
        );
      },
      transitionBuilder: (_, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );

    if (selected != null) {
      setState(() => _gridSize = selected);
    }
  }

  // ========================================
  // アクション
  // ========================================

  // メモ全件数の上限（同期/クラウド保存時の安全マージン）
  static const int _maxMemoCount = 10000;

  /// 件数上限を超えてないかチェック。超えてたらアラート出して true を返す
  Future<bool> _checkMemoLimit() async {
    final db = ref.read(databaseProvider);
    final count = await db.countMemos();
    if (count >= _maxMemoCount) {
      if (!mounted) return true;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('メモ数の上限に達しました'),
          content: Text(
            '現在 $count 件のメモがあります。これ以上は作成できません（上限: $_maxMemoCount 件）。\n'
            '不要なメモを削除してください。',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return true;
    }
    return false;
  }

  // 新規作成: DB登録は入力時に MemoInputArea が行う。
  // ここでは入力欄をクリアして本文にフォーカスを与えるだけ
  Future<void> _createNewMemo() async {
    if (await _checkMemoLimit()) return;
    _clearSearchIfActive();
    setState(() {
      _editingMemoId = null;
      _focusInputTrigger++;
    });
  }

  Future<void> _createMemoInFolder(List<Tag> parentTags) async {
    if (await _checkMemoLimit()) return;
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo();
    // 現在のタブのタグを自動付与
    final parentId = _currentParentTagId(parentTags);
    if (parentId != null) {
      await db.addTagToMemo(memo.id, parentId);
    }
    if (_selectedChildTagId != null) {
      await db.addTagToMemo(memo.id, _selectedChildTagId!);
    }
    if (mounted) setState(() => _editingMemoId = memo.id);
  }

  // メモタップ: 全画面エディタへ遷移するのではなく、上部の入力エリアに読み込む
  // 入力エリアは閲覧モードで開き、本文タップで編集モードへ切替 (Swift 本家準拠)
  void _openMemo(Memo memo) {
    // 閲覧回数を増やす (よく見る/最近見たに反映)
    ref.read(databaseProvider).incrementViewCount(memo.id);
    _clearSearchIfActive();
    setState(() => _editingMemoId = memo.id);
  }

  /// 「すべて」「タグなし」「よく見る」タブ長押し: 並び替え + 色変更だけ
  Future<void> _showSpecialTabActions(BuildContext tabContext,
      {required _SpecialKind specialKind}) async {
    FocusScope.of(context).unfocus();
    final box = tabContext.findRenderObject() as RenderBox?;
    Rect? rect;
    if (box != null) {
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
      rect = Rect.fromLTWH(
          topLeft.dx, topLeft.dy, box.size.width, box.size.height);
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final r = rect ??
        Rect.fromLTWH(overlay.size.width / 2 - 60, 200, 120, 40);

    final label = switch (specialKind) {
      _SpecialKind.all => 'すべて',
      _SpecialKind.untagged => 'タグなし',
      _SpecialKind.frequent => 'よく見る',
    };

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'specialTabMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, _) {
        return _SpecialTabContextMenuOverlay(
          label: label,
          buttonRect: r,
        );
      },
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    switch (action) {
      case 'reorder':
        // 並び替え前のスクロール位置とタブ順を保存
        if (_tabBarScrollController.hasClients) {
          _savedTabBarOffset = _tabBarScrollController.offset;
        }
        _savedTabOrder = List<String>.from(_tabOrder ?? const <String>[]);
        setState(() => _isReorderMode = true);
        break;
      case 'color':
        await _changeSpecialTabColor(specialKind);
        break;
    }
  }

  Future<void> _changeSpecialTabColor(_SpecialKind kind) async {
    final current = switch (kind) {
      _SpecialKind.all => ref.read(allTabColorIndexProvider),
      _SpecialKind.untagged => ref.read(untaggedTabColorIndexProvider),
      _SpecialKind.frequent => ref.read(frequentTabColorIndexProvider),
    };
    // 0未満（デフォルト）の場合はパレット先頭を初期表示にする
    final initial = current < 0 ? 0 : current;
    final label = switch (kind) {
      _SpecialKind.all => 'すべて',
      _SpecialKind.untagged => 'タグなし',
      _SpecialKind.frequent => 'よく見る',
    };
    await NewTagSheet.show(
      context: context,
      specialLabel: label,
      specialInitialColorIndex: initial,
      onSpecialColorSaved: (picked) {
        switch (kind) {
          case _SpecialKind.all:
            ref.read(allTabColorIndexProvider.notifier).state = picked;
          case _SpecialKind.untagged:
            ref.read(untaggedTabColorIndexProvider.notifier).state = picked;
          case _SpecialKind.frequent:
            ref.read(frequentTabColorIndexProvider.notifier).state = picked;
        }
      },
    );
  }

  /// タブ長押し: タブの矩形を取得して、その上にメニューを開く
  void _showTagActionsFromContext(BuildContext tabContext, Tag tag) {
    // メニュー閉時にダイアログがフォーカスを直前のWidgetに戻して
    // 入力欄が再フォーカス→キーボード再表示するのを防ぐ
    FocusScope.of(context).unfocus();
    final box = tabContext.findRenderObject() as RenderBox?;
    Rect? rect;
    if (box != null) {
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
      rect = Rect.fromLTWH(
          topLeft.dx, topLeft.dy, box.size.width, box.size.height);
    }
    _showTagActions(tag, sourceRect: rect);
  }

  /// タブ長押しメニュー（本家contextMenu準拠: 並び替え / 編集 / 削除）
  Future<void> _showTagActions(Tag tag, {Rect? sourceRect}) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    // sourceRect が無ければ画面中央上に出す
    final rect = sourceRect ??
        Rect.fromLTWH(overlay.size.width / 2 - 60, 200, 120, 40);

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'tagMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, _) {
        return _TabContextMenuOverlay(
          tag: tag,
          buttonRect: rect,
        );
      },
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );

    if (!mounted) return;
    // ダイアログが直前のフォーカス（テキスト入力欄）を復元しないように
    FocusScope.of(context).unfocus();
    switch (action) {
      case 'reorder':
        // 並び替え前のスクロール位置とタブ順を保存
        if (_tabBarScrollController.hasClients) {
          _savedTabBarOffset = _tabBarScrollController.offset;
        }
        _savedTabOrder = List<String>.from(_tabOrder ?? const <String>[]);
        setState(() => _isReorderMode = true);
        break;
      case 'edit':
        await _editTag(tag);
        break;
      case 'delete':
        await _confirmDeleteTag(tag);
        break;
    }
  }

  Future<void> _editTag(Tag tag) async {
    // 編集も新規追加と同じ NewTagSheet を使う（保存はシート内部でDBへ）
    await NewTagSheet.show(context: context, editingTag: tag);
  }

  Future<void> _addChildTag(String parentId) async {
    // ルーレットの「子タグ追加」ボタンと同じ NewTagSheet を使う
    await NewTagSheet.show(context: context, parentTagId: parentId);
  }

  /// タグ削除（本家準拠: メモも削除 / メモは残す / キャンセル → 確認）
  Future<void> _confirmDeleteTag(Tag tag) async {
    // ステップ1: メモの扱いを選ぶ
    final mode = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('「${tag.name}」を削除します'),
        message: const Text('このタグに含まれるメモの扱いを選んでください'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'withMemos'),
            child: const Text('メモも一緒に削除'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'keepMemos'),
            child: const Text('メモは残す（タグなしに移動）'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('キャンセル'),
        ),
      ),
    );
    if (mode == null || !mounted) return;

    // ステップ2: 最終確認
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('本当に削除しますか？'),
        content: Text(
          mode == 'withMemos'
              ? '「${tag.name}」とそのメモが全て削除されます。この操作は取り消せません。'
              : 'タグ「${tag.name}」が削除されます。メモは全て「タグなし」に移動されます。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseProvider);
    if (mode == 'withMemos') {
      await db.deleteTagWithMemos(tag.id);
    } else {
      await db.deleteTag(tag.id);
    }
    if (mounted) {
      setState(() {
        _selectedTabKey = kAllTabKey;
        _childDrawerOpen = false;
        _selectedChildTagId = null;
      });
      _animateDrawer(false);
    }
  }

  // メモカードを長押し検知付きでラップする（ボトムシート方式）
  Widget _wrapMemoInContextMenu(Memo memo, Widget card) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showMemoActions(memo),
      child: card,
    );
  }

  // メモカード長押しメニュー: ボトムシートに対象カードのプレビュー + 項目リスト
  // 本家contextMenu準拠の項目: トップに移動 / 固定 / コピー / ロック / 削除
  // よく見るタブでは「トップに移動」「固定」非表示
  Future<void> _showMemoActions(Memo memo) async {
    FocusScope.of(context).unfocus();
    final showMoveAndPin = !_isFrequentTab;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 対象メモカードのプレビュー（薄水色の枠でメニューと差別化）
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8ECF7), // 薄水色
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IgnorePointer(
                      child: MemoCard(
                        memo: memo,
                        onTap: () {},
                        gridSize: GridSizeOption.grid2x3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 項目リスト（すりガラス調）
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showMoveAndPin)
                            _MenuActionRow(
                              icon: Icons.vertical_align_top,
                              label: 'トップに移動',
                              onTap: () =>
                                  Navigator.of(sheetCtx).pop('moveTop'),
                            ),
                          if (showMoveAndPin)
                            _MenuActionRow(
                              icon: memo.isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin,
                              label: memo.isPinned
                                  ? '固定を解除'
                                  : 'トップに常時固定',
                              onTap: () =>
                                  Navigator.of(sheetCtx).pop('pin'),
                            ),
                          _MenuActionRow(
                            icon: Icons.copy,
                            label: 'コピー',
                            onTap: () =>
                                Navigator.of(sheetCtx).pop('copy'),
                          ),
                          _MenuActionRow(
                            icon: memo.isLocked
                                ? Icons.lock_open
                                : Icons.lock_outline,
                            label: memo.isLocked ? 'ロックを解除' : '削除防止ロック',
                            onTap: () =>
                                Navigator.of(sheetCtx).pop('lock'),
                          ),
                          if (memo.isLocked)
                            _MenuActionRow(
                              icon: Icons.lock,
                              label: '削除ロック中',
                              destructive: true,
                              disabled: true,
                              onTap: () {},
                            )
                          else
                            _MenuActionRow(
                              icon: Icons.delete_outline,
                              label: '削除',
                              destructive: true,
                              onTap: () =>
                                  Navigator.of(sheetCtx).pop('delete'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // キャンセルボタン (iOS ActionSheet 風)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'キャンセル',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                            fontFamily: 'Hiragino Sans',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'moveTop':
        await db.moveMemoToTop(memo.id);
        break;
      case 'pin':
        await db.updateMemo(id: memo.id, isPinned: !memo.isPinned);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: memo.content));
        break;
      case 'lock':
        final wasLocked = memo.isLocked;
        await db.updateMemo(id: memo.id, isLocked: !memo.isLocked);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text(
                wasLocked ? 'ロックを解除しました' : 'メモをロックしました',
              ),
            ),
          );
        }
        break;
      case 'delete':
        await db.deleteMemo(memo.id);
        break;
    }
  }
}

// ========================================
// メモ件数テキスト
// ========================================
class _MemoCountText extends ConsumerWidget {
  final String tabKey;
  final String? childTagId;

  const _MemoCountText({
    required this.tabKey,
    this.childTagId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<Memo>> memosAsync;
    if (tabKey == kAllTabKey) {
      memosAsync = ref.watch(allMemosProvider);
    } else if (tabKey == kUntaggedTabKey) {
      memosAsync = ref.watch(untaggedMemosProvider);
    } else {
      final tagId = childTagId ?? tabKey;
      memosAsync = ref.watch(memosForTagProvider(tagId));
    }

    return memosAsync.when(
      data: (memos) => Text(
        '${memos.length}件',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      loading: () => const SizedBox(),
      error: (_, _) => const SizedBox(),
    );
  }
}

// 子タグフィルター中に件数の右に出る「親タグ-子タグ」カプセルバッジ
class _ParentChildBadge extends ConsumerWidget {
  final String parentTagId;
  final String childTagId;
  final Color tabColor;

  const _ParentChildBadge({
    required this.parentTagId,
    required this.childTagId,
    required this.tabColor,
  });

  // 本家 darkenedColor: HSB で saturation × 1.3 (cap 1.0), brightness × 0.55
  Color _darkened() {
    final hsv = HSVColor.fromColor(tabColor);
    return HSVColor.fromAHSV(
      1.0,
      hsv.hue,
      math.min(hsv.saturation * 1.3, 1.0),
      hsv.value * 0.55,
    ).toColor();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentTags =
        ref.watch(parentTagsProvider).valueOrNull ?? const <Tag>[];
    final childrenAsync = ref.watch(childTagsProvider(parentTagId));
    final children = childrenAsync.valueOrNull ?? const <Tag>[];
    final parentTag =
        parentTags.where((t) => t.id == parentTagId).firstOrNull;
    final childTag = children.where((t) => t.id == childTagId).firstOrNull;
    if (parentTag == null || childTag == null) return const SizedBox.shrink();

    final dark = _darkened();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20), // capsule
      ),
      child: Text(
        '${parentTag.name}-${childTag.name}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hiragino Sans',
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

// ========================================
// _FrequentTabContent: 「よく見る」フォルダ専用レイアウト（左右二列）
// 左 = よく見る（viewCount降順）、右 = 最近見た（lastViewedAt降順）
// ========================================
// ========================================
// _FolderSearchView: フォルダ内検索モード
// 上部に入力欄、その下に現在のフォルダ内のヒットメモを2列グリッドで表示
// ========================================
class _FolderSearchView extends ConsumerWidget {
  final String parentTagId;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final void Function(Memo) onTapMemo;
  final void Function(Memo) onLongPressMemo;

  const _FolderSearchView({
    required this.parentTagId,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.onTapMemo,
    required this.onLongPressMemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosForTagProvider(parentTagId));
    final normQ = normalizeForSearch(query);

    return Column(
      children: [
        // 入力欄
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onQueryChanged,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.85),
                hintText: 'このフォルダのメモを検索',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey[500]),
                prefixIcon:
                    Icon(Icons.search, size: 18, color: Colors.grey[500]),
                prefixIconConstraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                suffixIcon: query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                        child: Icon(Icons.cancel,
                            size: 16, color: Colors.grey[500]),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        // 検索結果
        Expanded(
          child: memosAsync.when(
            data: (memos) {
              if (normQ.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.search,
                          size: 28, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text(
                        'キーワードを入力',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
                    ],
                  ),
                );
              }
              final hits = memos.where((m) {
                final t = normalizeForSearch(m.title);
                final c = normalizeForSearch(m.content);
                return t.contains(normQ) || c.contains(normQ);
              }).toList();
              if (hits.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.search,
                          size: 28, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text(
                        '見つかりませんでした',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                      child: Text(
                        '${hits.length}件ヒット',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Hiragino Sans',
                          color: Color(0x993C3C43),
                        ),
                      ),
                    ),
                    for (var i = 0; i < hits.length; i += 2)
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: i + 2 < hits.length ? 8 : 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 110,
                                child: _SearchMemoCard(
                                  memo: hits[i],
                                  query: query,
                                  onTap: () => onTapMemo(hits[i]),
                                  onLongPress: () => onLongPressMemo(hits[i]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: i + 1 < hits.length
                                  ? SizedBox(
                                      height: 110,
                                      child: _SearchMemoCard(
                                        memo: hits[i + 1],
                                        query: query,
                                        onTap: () =>
                                            onTapMemo(hits[i + 1]),
                                        onLongPress: () =>
                                            onLongPressMemo(hits[i + 1]),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('検索エラー: $e')),
          ),
        ),
      ],
    );
  }
}

// ========================================
// _SearchResultsView: 検索結果モード
// 検索クエリにヒットしたメモをタグ別セクションにまとめて表示
// ========================================
class _SearchResultsView extends ConsumerWidget {
  final String query;
  final void Function(Memo) onTapMemo;
  final void Function(Memo) onLongPressMemo;

  const _SearchResultsView({
    required this.query,
    required this.onTapMemo,
    required this.onLongPressMemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(searchMemosProvider(query.toLowerCase()));
    final parentTags =
        ref.watch(parentTagsProvider).valueOrNull ?? const <Tag>[];

    return memosAsync.when(
      data: (memos) {
        if (memos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(CupertinoIcons.search,
                    size: 32, color: Color(0xB33C3C43)),
                SizedBox(height: 8),
                Text(
                  '見つかりませんでした',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Hiragino Sans',
                    color: Color(0xB33C3C43),
                  ),
                ),
              ],
            ),
          );
        }
        // メモごとのタグを取得して、親タグ別にグループ化
        return _SearchSections(
          query: query,
          memos: memos,
          parentTags: parentTags,
          onTapMemo: onTapMemo,
          onLongPressMemo: onLongPressMemo,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('検索エラー: $e')),
    );
  }
}

class _SearchSections extends ConsumerWidget {
  final String query;
  final List<Memo> memos;
  final List<Tag> parentTags;
  final void Function(Memo) onTapMemo;
  final void Function(Memo) onLongPressMemo;

  const _SearchSections({
    required this.query,
    required this.memos,
    required this.parentTags,
    required this.onTapMemo,
    required this.onLongPressMemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 各メモの親タグ集合を集める
    final memoParents = <String, Set<String>>{};
    for (final m in memos) {
      final tags =
          ref.watch(tagsForMemoStreamProvider(m.id)).valueOrNull ??
              const <Tag>[];
      final parents = <String>{};
      for (final t in tags) {
        parents.add(t.parentTagId ?? t.id);
      }
      memoParents[m.id] = parents;
    }

    // セクション組み立て
    final sections = <_SearchSection>[];
    // タグなし
    final noTag = memos
        .where((m) => (memoParents[m.id] ?? const {}).isEmpty)
        .toList();
    if (noTag.isNotEmpty) {
      sections.add(_SearchSection(
        name: 'タグなし',
        colorIndex: 0,
        memos: noTag,
      ));
    }
    // 親タグごと
    for (final pt in parentTags) {
      final matched = memos
          .where((m) => (memoParents[m.id] ?? const {}).contains(pt.id))
          .toList();
      if (matched.isNotEmpty) {
        sections.add(_SearchSection(
          name: pt.name,
          colorIndex: pt.colorIndex,
          memos: matched,
        ));
      }
    }

    final totalHits = memos.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Text(
              '$totalHits件ヒット',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
                color: Color(0x993C3C43),
              ),
            ),
          ),
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // セクションヘッダー (タグバッジ + 件数)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: TagColors.getColor(s.colorIndex),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Hiragino Sans',
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${s.memos.length}件',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Hiragino Sans',
                              color: Color(0x993C3C43),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 2列レイアウト (手動 Column-of-Rows で確実な余白制御)
                    for (var i = 0; i < s.memos.length; i += 2)
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: i + 2 < s.memos.length ? 8 : 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 110,
                                child: _SearchMemoCard(
                                  memo: s.memos[i],
                                  query: query,
                                  onTap: () => onTapMemo(s.memos[i]),
                                  onLongPress: () =>
                                      onLongPressMemo(s.memos[i]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: i + 1 < s.memos.length
                                  ? SizedBox(
                                      height: 110,
                                      child: _SearchMemoCard(
                                        memo: s.memos[i + 1],
                                        query: query,
                                        onTap: () =>
                                            onTapMemo(s.memos[i + 1]),
                                        onLongPress: () =>
                                            onLongPressMemo(s.memos[i + 1]),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchSection {
  final String name;
  final int colorIndex;
  final List<Memo> memos;
  _SearchSection({
    required this.name,
    required this.colorIndex,
    required this.memos,
  });
}

// ヒットしたクエリ箇所をハイライト表示するメモカード
class _SearchMemoCard extends StatelessWidget {
  final Memo memo;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SearchMemoCard({
    required this.memo,
    required this.query,
    required this.onTap,
    required this.onLongPress,
  });

  // 本文からマッチ行を中心としたスニペットを抽出（最大3行）
  String get _snippet {
    final lines = memo.content.split('\n');
    final normQ = normalizeForSearch(query);
    final idx = lines
        .indexWhere((l) => normalizeForSearch(l).contains(normQ));
    if (idx == -1) {
      // タイトルにのみマッチ → 先頭3行
      return lines.take(3).join('\n');
    }
    final start = (idx - 1).clamp(0, lines.length - 1);
    final end = (idx + 1).clamp(0, lines.length - 1);
    return lines.sublist(start, end + 1).join('\n');
  }

  // テキストを TextSpan に分解してマッチ箇所をハイライト
  // 正規化(全角→半角・小文字)でマッチ位置を探し、元テキストでハイライト
  // (正規化は 1文字 → 1文字 の 1:1 マップなので index は一致する)
  TextSpan _highlight(String text, TextStyle baseStyle) {
    final lower = normalizeForSearch(text);
    final lowerQ = normalizeForSearch(query);
    if (lowerQ.isEmpty) return TextSpan(text: text, style: baseStyle);
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        spans.add(
            TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + lowerQ.length),
          style: baseStyle.copyWith(
            backgroundColor: Colors.yellow.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      );
      start = idx + lowerQ.length;
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = memo.title.isNotEmpty;
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: hasTitle ? FontWeight.w600 : FontWeight.w400,
      color: hasTitle ? Colors.black : Colors.grey.withValues(alpha: 0.5),
      height: 1.3,
      fontFamily: 'Hiragino Sans',
    );
    final bodyStyle = TextStyle(
      fontSize: 12,
      color: Colors.grey[700],
      height: 1.35,
      fontFamily: 'Hiragino Sans',
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              _highlight(hasTitle ? memo.title : '(タイトルなし)', titleStyle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text.rich(
                _highlight(_snippet, bodyStyle),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequentTabContent extends ConsumerWidget {
  final FrequentGridOption gridOption;
  final Color tabColor;
  final void Function(Memo) onTap;
  final MemoCardWrapper? wrapBuilder;
  final bool selectMode;
  final Set<String> selectedIds;
  final void Function(Memo)? onToggleSelect;

  const _FrequentTabContent({
    required this.gridOption,
    required this.tabColor,
    required this.onTap,
    this.wrapBuilder,
    this.selectMode = false,
    this.selectedIds = const <String>{},
    this.onToggleSelect,
  });

  // 本家 frequentColumnColors: rgb をそれぞれ × 0.92 した少し暗い色
  Color get _columnColor {
    final r = (tabColor.r * 0.92).clamp(0.0, 1.0);
    final g = (tabColor.g * 0.92).clamp(0.0, 1.0);
    final b = (tabColor.b * 0.92).clamp(0.0, 1.0);
    return Color.from(alpha: 1.0, red: r, green: g, blue: b);
  }

  /// 本家 cardHeight 計算式準拠
  /// (availableHeight - spacing × (rows + peek)) / (rows + peek)
  /// - rows = 0 (full / titleOnly) のときは null
  double? _computeCardHeight(double availableHeight) {
    if (gridOption.rows == 0) return null; // full / titleOnly は固定しない
    const spacing = 8.0;
    const peek = 0.2;
    final rows = gridOption.rows.toDouble();
    final h = (availableHeight - spacing * (rows + peek)) / (rows + peek);
    return h < 36 ? 36 : h;
  }

  Widget _buildCardCell(Memo memo, double? cardHeight) {
    final card = MemoCard(
      key: ValueKey('freqmemo_${memo.id}'),
      memo: memo,
      onTap: () => onTap(memo),
      gridSize: gridOption.cardGridSize,
    );
    if (selectMode) {
      final isSelected = selectedIds.contains(memo.id);
      final isLocked = memo.isLocked;
      final inner = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(
              isLocked
                  ? CupertinoIcons.lock_fill
                  : isSelected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
              size: 16,
              color: isLocked
                  ? Colors.grey.withValues(alpha: 0.4)
                  : isSelected
                      ? Colors.blue
                      : Colors.grey.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: IgnorePointer(child: card),
            ),
          ),
        ],
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggleSelect?.call(memo),
        child: cardHeight != null ? SizedBox(height: cardHeight, child: inner) : inner,
      );
    }
    final wrapped = wrapBuilder != null ? wrapBuilder!(memo, card) : card;
    return cardHeight != null ? SizedBox(height: cardHeight, child: wrapped) : wrapped;
  }

  Widget _buildColumn(
      BuildContext context, String title, List<Memo> memos, double? cardHeight) {
    // 本家準拠: ラベルとカード群が同じ箱の中にまとまる
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _columnColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
                color: Color(0x993C3C43),
              ),
            ),
          ),
          for (var i = 0; i < memos.length; i++) ...[
            _buildCardCell(memos[i], cardHeight),
            if (i < memos.length - 1) const SizedBox(height: 8),
          ],
          if (memos.isEmpty)
            const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  '0件',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0x993C3C43),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freq = ref.watch(frequentMemosProvider).valueOrNull ?? const <Memo>[];
    final recent = ref.watch(recentMemosProvider).valueOrNull ?? const <Memo>[];

    if (freq.isEmpty && recent.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.doc_text,
                size: 32, color: Color(0xB33C3C43)),
            SizedBox(height: 8),
            Text(
              '使い始めると\n表示されるようになります',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Hiragino Sans',
                color: Color(0xB33C3C43),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 列ラベル(20pt) + 上下padding(16pt) を引いた領域でカード高を計算
        const frequentExtraOffset = 36.0;
        final available = constraints.maxHeight - frequentExtraOffset;
        final cardHeight = _computeCardHeight(available);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 120),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildColumn(context, 'よく見る', freq, cardHeight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildColumn(context, '最近見た', recent, cardHeight),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========================================
// メモグリッドビュー（共通）
// ========================================
// カードを CupertinoContextMenu などで包みたいときに使う
typedef MemoCardWrapper = Widget Function(Memo memo, Widget cardChild);

class _MemoGridView extends StatelessWidget {
  final AsyncValue<List<Memo>> stream;
  final GridSizeOption gridSize;
  final void Function(Memo) onTap;
  final MemoCardWrapper? wrapBuilder;
  // 子タグバッジ用: 現在のフォルダの親タグID（無ければバッジなし）
  final String? parentTagId;
  // 複数選択モード関連
  final bool selectMode;
  final Set<String> selectedIds;
  final void Function(Memo)? onToggleSelect;

  const _MemoGridView({
    required this.stream,
    required this.gridSize,
    required this.onTap,
    this.wrapBuilder,
    this.parentTagId,
    this.selectMode = false,
    this.selectedIds = const <String>{},
    this.onToggleSelect,
  });

  Widget _buildCard(Memo memo) {
    if (selectMode) {
      final isSelected = selectedIds.contains(memo.id);
      final isLocked = memo.isLocked;
      // 本家準拠: HStack(spacing: 4) { icon(16pt); MemoCard }
      // crossAxisAlignment: stretch でカードがセル高さを満たす（縮まない）
      // アイコンとカード両方が選択トグルのタップ対象
      final iconWidget = Icon(
        isLocked
            ? CupertinoIcons.lock_fill
            : isSelected
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
        size: 16,
        color: isLocked
            ? Colors.grey.withValues(alpha: 0.4)
            : isSelected
                ? Colors.blue
                : Colors.grey.withValues(alpha: 0.6),
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggleSelect?.call(memo),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // アイコンは中央寄せ（縦stretch内でCenterで中央配置）
            Center(child: iconWidget),
            const SizedBox(width: 4),
            Expanded(
              child: Opacity(
                opacity: isLocked ? 0.4 : 1.0,
                // IgnorePointer でカード内のGestureDetectorを無効化
                child: IgnorePointer(
                  child: MemoCard(
                    memo: memo,
                    onTap: () {},
                    parentTagId: parentTagId,
                    gridSize: gridSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // 全カードに ValueKey を付けて stream 更新時もウィジェット同一性を維持
    final card = MemoCard(
      key: ValueKey('memocard_${memo.id}'),
      memo: memo,
      onTap: () => onTap(memo),
      parentTagId: parentTagId,
      gridSize: gridSize,
    );
    final wrapped = wrapBuilder != null ? wrapBuilder!(memo, card) : card;
    return KeyedSubtree(key: ValueKey('cell_${memo.id}'), child: wrapped);
  }

  /// 1行の高さを availableHeight から計算（Swift版cardHeight準拠）
  /// rows行を完全表示 + 次の行を peek=0.2 だけチラ見せ
  double _computeMainAxisExtent(double availableHeight) {
    final rows = switch (gridSize) {
      GridSizeOption.grid3x6 => 6,
      GridSizeOption.grid2x5 => 5,
      GridSizeOption.grid2x3 => 3,
      GridSizeOption.grid1x2 => 2,
      _ => 0,
    };
    if (rows == 0) return 100; // fallback
    const spacing = 8.0;
    const peek = 0.2;
    final totalSpacing = spacing * (rows + peek);
    final h = (availableHeight - totalSpacing) / (rows + peek);
    return h < 36 ? 36 : h;
  }

  @override
  Widget build(BuildContext context) {
    return stream.when(
      data: (memos) {
        if (memos.isEmpty) {
          return Align(
            alignment: const Alignment(0, -0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.sticky_note_2_outlined,
                    size: 22, color: Color(0xB33C3C43)),
                SizedBox(height: 8),
                Text('メモがありません',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Hiragino Sans',
                      color: Color(0xB33C3C43),
                    )),
              ],
            ),
          );
        }

        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // フロート式ボトムバーに被らないよう下端にスクロール余白を確保
              const bottomPad = 120.0;
              // タイトルのみ: 1列リスト風（コンパクト）
              if (gridSize == GridSizeOption.titleOnly) {
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: bottomPad),
                  itemCount: memos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (_, i) => _buildCard(memos[i]),
                );
              }

              // 1×可変: 1列、カード高さは内容に追従、本文 max 15行
              // ListView.separated は lazy build なので 1万件あっても画面外は描画しない
              if (gridSize == GridSizeOption.grid1flex) {
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: bottomPad),
                  itemCount: memos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildCard(memos[i]),
                );
              }

              // 通常: rows×cols でフォルダ高さに合わせて自動計算
              final mainExtent =
                  _computeMainAxisExtent(constraints.maxHeight);
              return GridView.builder(
                padding: EdgeInsets.only(bottom: bottomPad),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize.columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: mainExtent,
                ),
                itemCount: memos.length,
                itemBuilder: (_, i) => _buildCard(memos[i]),
              );
            },
          ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
    );
  }
}

// ========================================
// グリッドサイズメニュー: すりガラスポップオーバー
// ボタンの上に出る、角丸大きめ、背景blur、本家準拠の見出し付き
// ========================================
class _GridSizeMenuOverlay extends StatelessWidget {
  final GridSizeOption current;
  final Rect buttonRect;

  const _GridSizeMenuOverlay({
    required this.current,
    required this.buttonRect,
  });

  @override
  Widget build(BuildContext context) {
    // 本家normalOptions: [3×6, 2×5, 2×3, 1×2, 1(全文), タイトルのみ]
    // 本家Menuはこの順で上から並べる
    const options = GridSizeOption.values;

    const menuWidth = 220.0;
    // 行数: 見出し + 6項目
    const rowHeight = 46.0;
    const headerHeight = 32.0;
    final menuHeight = headerHeight + rowHeight * options.length + 8;

    final screen = MediaQuery.of(context).size;
    // ボタンの上に開く（右端をボタンの右端と揃える）
    double left = buttonRect.right - menuWidth;
    if (left < 8) left = 8;
    if (left + menuWidth > screen.width - 8) {
      left = screen.width - 8 - menuWidth;
    }
    final top = buttonRect.top - menuHeight - 6;

    return Stack(
      children: [
        // 全画面の透明バリア（タップで閉じる）
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            // 長押しもバリアで吸収（下のタブのonLongPressに届かないように）
            onLongPress: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 見出し
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        'メモの表示数',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xB33C3C43),
                        ),
                      ),
                    ),
                    Container(
                      height: 0.5,
                      color: const Color(0x33000000),
                    ),
                    for (final opt in options)
                      _MenuRow(
                        label: opt.label,
                        isCurrent: opt == current,
                        onTap: () => Navigator.of(context).pop(opt),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String label;
  final bool isCurrent;
  final VoidCallback onTap;

  const _MenuRow({
    required this.label,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // チェックマーク（左側、選択中のみ）
              SizedBox(
                width: 26,
                child: isCurrent
                    ? const Icon(Icons.check,
                        size: 19, color: Colors.blue)
                    : null,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
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

// 「よく見る」フォルダ専用のグリッドサイズメニュー
class _FrequentGridSizeMenuOverlay extends StatelessWidget {
  final FrequentGridOption current;
  final Rect buttonRect;

  const _FrequentGridSizeMenuOverlay({
    required this.current,
    required this.buttonRect,
  });

  @override
  Widget build(BuildContext context) {
    const options = FrequentGridOption.values;
    const menuWidth = 220.0;
    const rowHeight = 46.0;
    const headerHeight = 32.0;
    final menuHeight = headerHeight + rowHeight * options.length + 8;

    final screen = MediaQuery.of(context).size;
    double left = buttonRect.right - menuWidth;
    if (left < 8) left = 8;
    if (left + menuWidth > screen.width - 8) {
      left = screen.width - 8 - menuWidth;
    }
    final top = buttonRect.top - menuHeight - 6;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            onLongPress: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(
                          '表示形式',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xB33C3C43),
                          ),
                        ),
                      ),
                      Container(
                        height: 0.5,
                        color: const Color(0x33000000),
                      ),
                      for (final opt in options)
                        _MenuRow(
                          label: opt.label,
                          isCurrent: opt == current,
                          onTap: () => Navigator.of(context).pop(opt),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ========================================
// _ZOrderedRow: 子をRowのように左→右に配置するが、
// paint順を「右ほど後ろ・左ほど前」+「選択中は最前面」にする
// ========================================
class _ZOrderedRow extends MultiChildRenderObjectWidget {
  final int selectedIndex;
  /// 隣り合う子をどれだけ重ねるか（正値=重なる）
  final double overlap;

  const _ZOrderedRow({
    required this.selectedIndex,
    this.overlap = 0,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ZOrderedRowRenderBox(
          selectedIndex: selectedIndex, overlap: overlap);

  @override
  void updateRenderObject(
      BuildContext context, _ZOrderedRowRenderBox renderObject) {
    renderObject.selectedIndex = selectedIndex;
    renderObject.overlap = overlap;
  }
}

class _ZOrderedRowParentData extends ContainerBoxParentData<RenderBox> {}

class _ZOrderedRowRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ZOrderedRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ZOrderedRowParentData> {
  _ZOrderedRowRenderBox({required int selectedIndex, double overlap = 0})
      : _selectedIndex = selectedIndex,
        _overlap = overlap;

  int _selectedIndex;
  int get selectedIndex => _selectedIndex;
  set selectedIndex(int value) {
    if (_selectedIndex != value) {
      _selectedIndex = value;
      markNeedsPaint();
    }
  }

  double _overlap;
  double get overlap => _overlap;
  set overlap(double value) {
    if (_overlap != value) {
      _overlap = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ZOrderedRowParentData) {
      child.parentData = _ZOrderedRowParentData();
    }
  }

  @override
  void performLayout() {
    double x = 0;
    double maxH = 0;
    final childConstraints =
        BoxConstraints(maxHeight: constraints.maxHeight);
    var child = firstChild;
    var first = true;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final pd = child.parentData! as _ZOrderedRowParentData;
      // 2番目以降は前の子と重ねる
      if (!first) x -= _overlap;
      pd.offset = Offset(x, 0);
      x += child.size.width;
      if (child.size.height > maxH) maxH = child.size.height;
      first = false;
      child = pd.nextSibling;
    }
    // コンテナ高さ: 親が固定高を指定していればそれを使う、なければ子の最大
    final containerH = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : maxH;
    // 全子供を下端揃え（フォルダ本体上端と接する）
    child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _ZOrderedRowParentData;
      pd.offset = Offset(pd.offset.dx, containerH - child.size.height);
      child = pd.nextSibling;
    }
    size = constraints.constrain(Size(x, containerH));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // 子をリスト化
    final children = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      children.add(c);
      c = (c.parentData! as _ZOrderedRowParentData).nextSibling;
    }
    // paint順: インデックス大→小（右が後ろ・左が前）
    // ただし選択中の子は最後にpaint（最前面）
    final order = <int>[];
    for (int i = children.length - 1; i >= 0; i--) {
      if (i != _selectedIndex) order.add(i);
    }
    if (_selectedIndex >= 0 && _selectedIndex < children.length) {
      order.add(_selectedIndex);
    }
    for (final i in order) {
      final child = children[i];
      final pd = child.parentData! as _ZOrderedRowParentData;
      context.paintChild(child, offset + pd.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // hit test も paint と同じ順（前面のものが優先）
    final children = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      children.add(c);
      c = (c.parentData! as _ZOrderedRowParentData).nextSibling;
    }
    final order = <int>[];
    if (_selectedIndex >= 0 && _selectedIndex < children.length) {
      order.add(_selectedIndex);
    }
    for (int i = 0; i < children.length; i++) {
      if (i != _selectedIndex) order.add(i);
    }
    for (final i in order) {
      final child = children[i];
      final pd = child.parentData! as _ZOrderedRowParentData;
      final hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (BoxHitTestResult r, Offset p) {
          return child.hitTest(r, position: p);
        },
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    double w = 0;
    var c = firstChild;
    while (c != null) {
      w += c.getMinIntrinsicWidth(height);
      c = (c.parentData! as _ZOrderedRowParentData).nextSibling;
    }
    return w;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double w = 0;
    var c = firstChild;
    while (c != null) {
      w += c.getMaxIntrinsicWidth(height);
      c = (c.parentData! as _ZOrderedRowParentData).nextSibling;
    }
    return w;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    double h = 0;
    var c = firstChild;
    while (c != null) {
      final ch = c.getMinIntrinsicHeight(double.infinity);
      if (ch > h) h = ch;
      c = (c.parentData! as _ZOrderedRowParentData).nextSibling;
    }
    return h;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    double h = 0;
    var c = firstChild;
    while (c != null) {
      final ch = c.getMaxIntrinsicHeight(double.infinity);
      if (ch > h) h = ch;
      c = (c.parentData! as _ZOrderedRowParentData).nextSibling;
    }
    return h;
  }
}

// ========================================
// _TabContextMenuOverlay: タブ長押しメニュー（並び替え/編集/削除）
// ========================================
class _TabContextMenuOverlay extends StatelessWidget {
  final Tag tag;
  final Rect buttonRect;

  const _TabContextMenuOverlay({
    required this.tag,
    required this.buttonRect,
  });

  @override
  Widget build(BuildContext context) {
    const menuWidth = 220.0;
    const rowHeight = 46.0;
    final menuHeight = rowHeight * 3 + 8;

    final screen = MediaQuery.of(context).size;
    double left = buttonRect.left;
    if (left + menuWidth > screen.width - 8) {
      left = screen.width - 8 - menuWidth;
    }
    if (left < 8) left = 8;
    // 下に出すと隠れる場合は上に
    double top = buttonRect.bottom + 6;
    if (top + menuHeight > screen.height - 80) {
      top = buttonRect.top - menuHeight - 6;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            // 長押しもバリアで吸収（下のタブのonLongPressに届かないように）
            onLongPress: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MenuActionRow(
                        icon: Icons.swap_horiz,
                        label: 'フォルダの並び替え',
                        onTap: () =>
                            Navigator.of(context).pop('reorder'),
                      ),
                      _MenuActionRow(
                        icon: Icons.edit_outlined,
                        label: 'このタグを編集',
                        onTap: () => Navigator.of(context).pop('edit'),
                      ),
                      _MenuActionRow(
                        icon: Icons.delete_outline,
                        label: 'このタグを削除',
                        destructive: true,
                        onTap: () => Navigator.of(context).pop('delete'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuActionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final bool disabled;
  final VoidCallback onTap;

  const _MenuActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.disabled = false,
  });

  @override
  State<_MenuActionRow> createState() => _MenuActionRowState();
}

class _MenuActionRowState extends State<_MenuActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.destructive ? Colors.red : Colors.black87;
    final color = widget.disabled ? base.withValues(alpha: 0.4) : base;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel:
          widget.disabled ? null : () => setState(() => _pressed = false),
      onTapUp:
          widget.disabled ? null : (_) => setState(() => _pressed = false),
      onTap: widget.disabled ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 46,
        color: _pressed
            ? Colors.black.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// _WigglingReorderTab: 並び替えモード時の振動するタブ
// 長押し→ドラッグでReorderableListViewが移動を扱う
// ========================================
class _WigglingReorderTab extends StatefulWidget {
  final int index;
  final String tabKey;
  final List<Tag> parentTags;
  final int allTabColorIndex;
  final int untaggedColorIndex;
  final VoidCallback onTouch;

  const _WigglingReorderTab({
    super.key,
    required this.index,
    required this.tabKey,
    required this.parentTags,
    required this.allTabColorIndex,
    required this.untaggedColorIndex,
    required this.onTouch,
  });

  @override
  State<_WigglingReorderTab> createState() => _WigglingReorderTabState();
}

class _WigglingReorderTabState extends State<_WigglingReorderTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    )..repeat(reverse: true);
    // 偶数/奇数で位相をずらしてバラつきを出す
    final offset = widget.index.isEven ? 0.0 : 0.5;
    _wiggleAnimation = Tween<double>(
      begin: -0.025 + offset * 0.05,
      end: 0.025 - offset * 0.05,
    ).animate(CurvedAnimation(
      parent: _wiggleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // キーから色とラベルを解決
    Color color;
    String label;
    if (widget.tabKey == kAllTabKey) {
      color = widget.allTabColorIndex < 0
          ? TagColors.allTabColor
          : TagColors.getColor(widget.allTabColorIndex);
      label = 'すべて';
    } else if (widget.tabKey == kUntaggedTabKey) {
      color = TagColors.getColor(widget.untaggedColorIndex);
      label = 'タグなし';
    } else {
      final tag = widget.parentTags
          .where((t) => t.id == widget.tabKey)
          .firstOrNull;
      if (tag == null) return const SizedBox.shrink();
      color = TagColors.getColor(tag.colorIndex);
      label = tag.name;
    }

    final tabContent = CustomPaint(
      painter: TrapezoidTabPainter(
        color: color,
        shadows: const [
          Shadow(
            color: Color(0x4D000000),
            offset: Offset(-3, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          label.length > 5 ? '${label.substring(0, 5)}...' : label,
          strutStyle: const StrutStyle(
            fontSize: 14,
            height: 1.0,
            forceStrutHeight: true,
          ),
          style: const TextStyle(
            fontSize: 14,
            height: 1.0,
            fontFamily: 'Hiragino Sans',
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );

    return Listener(
      // 触れた瞬間に選択を更新（フォルダ本体が連動）
      onPointerDown: (_) => widget.onTouch(),
      child: ReorderableDelayedDragStartListener(
        index: widget.index,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: _wiggleAnimation,
              builder: (_, child) => Transform.rotate(
                angle: _wiggleAnimation.value,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
              child: tabContent,
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// _SpecialTabContextMenuOverlay: 「すべて」「タグなし」用 (並び替え + 色変更のみ)
// ========================================
class _SpecialTabContextMenuOverlay extends StatelessWidget {
  final String label;
  final Rect buttonRect;

  const _SpecialTabContextMenuOverlay({
    required this.label,
    required this.buttonRect,
  });

  @override
  Widget build(BuildContext context) {
    const menuWidth = 220.0;
    const rowHeight = 46.0;
    final menuHeight = rowHeight * 2 + 8;

    final screen = MediaQuery.of(context).size;
    double left = buttonRect.left;
    if (left + menuWidth > screen.width - 8) {
      left = screen.width - 8 - menuWidth;
    }
    if (left < 8) left = 8;
    double top = buttonRect.bottom + 6;
    if (top + menuHeight > screen.height - 80) {
      top = buttonRect.top - menuHeight - 6;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            // 長押しもバリアで吸収（下のタブのonLongPressに届かないように）
            onLongPress: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MenuActionRow(
                        icon: Icons.swap_horiz,
                        label: 'フォルダの並び替え',
                        onTap: () =>
                            Navigator.of(context).pop('reorder'),
                      ),
                      _MenuActionRow(
                        icon: Icons.palette_outlined,
                        label: '色を変更',
                        onTap: () => Navigator.of(context).pop('color'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ========================================
// _ChildTagDrawer: 本家準拠の子タグドロワー
// 閉じているとき: 右端に「◀子タグ」グレー帯（幅52, 高さ23）
// 開いているとき: 30pt の▶ハンドル + 子タグチップ群（高さ37）
// アニメーション値は親(_HomeScreenState)が持つAnimationControllerを共有して、
// 件数バー/メモグリッドのスライドと完全に同期する。
// ========================================
class _ChildTagDrawer extends ConsumerWidget {
  final String parentTagId;
  final AnimationController controller;
  final String? selectedChildId;
  final VoidCallback onToggle;
  final void Function(String?) onSelectChild;
  final VoidCallback onAddChild;

  const _ChildTagDrawer({
    required this.parentTagId,
    required this.controller,
    required this.selectedChildId,
    required this.onToggle,
    required this.onSelectChild,
    required this.onAddChild,
  });

  static const double handleHeight = 23;
  static const double bandHeight = 37;
  static const double handleTextWidth = 52;
  static const double openHandleWidth = 30;

  // 子タグコンテンツの幅を概算（本家のロジックを移植）
  double _computeContentWidth(List<Tag> children, String parentName) {
    const chipHPad = 20.0; // chip 内 horizontal padding × 2
    const chipSpacing = 6.0;
    const plusButton = 32.0;
    const edgePadding = 16.0; // 左4 + 右8 + 余裕
    const charWidth = 13.0; // 半角換算ざっくり

    if (children.isEmpty) {
      final label = '"$parentName"の子タグなし';
      return plusButton + label.characters.length * 11.0 + edgePadding;
    }
    var total = plusButton + edgePadding;
    total += 'すべて'.characters.length * charWidth + chipHPad + chipSpacing;
    for (final c in children) {
      total += c.name.characters.length * charWidth + chipHPad + chipSpacing;
    }
    return total;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childTagsAsync = ref.watch(childTagsProvider(parentTagId));
    final children = childTagsAsync.valueOrNull ?? const <Tag>[];
    final parentTags =
        ref.watch(parentTagsProvider).valueOrNull ?? const <Tag>[];
    final parentTag =
        parentTags.where((t) => t.id == parentTagId).firstOrNull;
    final parentName = parentTag?.name ?? '';

    final screenW = MediaQuery.of(context).size.width;
    final contentW = _computeContentWidth(children, parentName);
    final maxReveal = math.min(contentW, screenW - 10 - openHandleWidth);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value.clamp(0.0, 1.0);
        final height = handleHeight + (bandHeight - handleHeight) * t;
        final hw = handleTextWidth + (openHandleWidth - handleTextWidth) * t;
        final chipsW = maxReveal * t;

        return Container(
          width: hw + chipsW,
          height: height,
          decoration: const BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: [
              // ハンドル: タップで開閉
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: SizedBox(
                  width: hw,
                  height: height,
                  child: Center(
                    child: t > 0.5
                        // 開いているとき: 大きい▶（テキストなし）
                        ? Text(
                            '\u25B6', // ▶ BLACK RIGHT-POINTING TRIANGLE
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.0,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\u25C0', // ◀ BLACK LEFT-POINTING TRIANGLE
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.0,
                                  color:
                                      Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text('子タグ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Hiragino Sans',
                                    color: Colors.white,
                                    height: 1.0,
                                  )),
                            ],
                          ),
                  ),
                ),
              ),
              // チップエリア: clip しつつ中身は最大幅で固定 (横スクロール可)
              if (chipsW > 0)
                ClipRect(
                  child: SizedBox(
                    width: chipsW,
                    height: bandHeight,
                    child: OverflowBox(
                      maxWidth: maxReveal,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: maxReveal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 4, right: 8),
                          child: Row(
                            children: [
                              if (children.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  child: Text(
                                    '"$parentName"の子タグなし',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Hiragino Sans',
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else ...[
                                _ChildTagChip(
                                  label: 'すべて',
                                  color: parentTag != null
                                      ? TagColors.getColor(parentTag.colorIndex)
                                      : Colors.grey,
                                  isSelected: selectedChildId == null,
                                  onTap: () => onSelectChild(null),
                                ),
                                const SizedBox(width: 6),
                                for (final c in children) ...[
                                  _ChildTagChip(
                                    label: c.name,
                                    color: TagColors.getColor(c.colorIndex),
                                    isSelected: selectedChildId == c.id,
                                    onTap: () => onSelectChild(c.id),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ],
                              // 追加ボタン
                              GestureDetector(
                                onTap: onAddChild,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add,
                                      size: 11, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChildTagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChildTagChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 1.0 : 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontFamily: 'Hiragino Sans',
            color: Colors.black87,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
