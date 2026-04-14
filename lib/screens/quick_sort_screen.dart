import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/keyboard_done_bar.dart';
import '../utils/text_menu_dismisser.dart';
import '../widgets/trapezoid_tab_shape.dart';

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
  _Phase _phase = _Phase.intro;

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

  // カラーラボ（開発用）
  Color _labTabColor = const Color(0xFFFFCC80).withValues(alpha: 0.28);
  Color _labTagFooterColor = Colors.cyan.withValues(alpha: 0.04);

  // カードスライドアニメーション方向（true=右へ進む、false=左へ戻る）
  bool _slideForward = true;

  // カード最大化状態
  bool _isCardExpanded = false;

  // 弧ボタンからカードにフォーカス要求するためのコントローラー
  final _CardController _cardController = _CardController();

  int get _totalSets =>
      (_allFilteredMemos.length + _setSize - 1) ~/ _setSize;
  @override void initState(){super.initState();_dl();}
  Future<void> _dl()async{final db=ref.read(databaseProvider);final m=await db.select(db.memos).get();if(!mounted||m.isEmpty)return;setState((){_allFilteredMemos=m;_loadCurrentSet();_phase=_Phase.carousel;});}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      body: KeyboardDoneBar(child: switch (_phase) {
        _Phase.intro => _QuickSortIntro(
          onNext: () => setState(() => _phase = _Phase.filter),
          onCancel: () => Navigator.of(context).pop(),
        ),
        _Phase.filter => _QuickSortFilterPhase(
          onStart: (memos) {
            setState(() {
              _allFilteredMemos = memos;
              _currentSetIndex = 0;
              _loadCurrentSet();
              _phase = _Phase.loading;
            });
          },
          onBack: () => setState(() => _phase = _Phase.intro),
          onCancel: () => Navigator.of(context).pop(),
        ),
        _Phase.loading => _QuickSortLoading(
          memoCount: _allFilteredMemos.length,
          onComplete: () => setState(() => _phase = _Phase.carousel),
        ),
        _Phase.carousel => _buildCarouselPhase(),
        _Phase.result => _buildResultPhase(),
      }),
    );
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
    final current = _currentCardIndex + 1;
    final total = _activeMemos.length;
    final isLast = current == total;
    final canPrev = _currentCardIndex > 0;
    final canNext = _currentCardIndex < total - 1;

    return SafeArea(
      maintainBottomViewPadding: true,
      child: Column(
        children: [
          // ヘッダー（76pt）
          SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 左: ✕ボタン + ラボ
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _circleButton(
                          icon: Icons.close,
                          size: 32,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        _circleButton(
                          icon: Icons.science,
                          size: 32,
                          onTap: () => _showColorLab(context),
                        ),
                      ],
                    ),
                  ),
                  // 中央: 枚数カウンター
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // 現在の番号（最後は虹色）
                      ShaderMask(
                        shaderCallback: (bounds) {
                          if (isLast) {
                            return const LinearGradient(
                              colors: [
                                Colors.red, Colors.orange, Colors.yellow,
                                Colors.green, Colors.blue, Colors.purple,
                              ],
                            ).createShader(bounds);
                          }
                          return const LinearGradient(
                            colors: [Colors.blue, Colors.blue],
                          ).createShader(bounds);
                        },
                        child: Text(
                          '$current',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            fontFamily: '.AppleSystemUIFontRounded',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '/$total',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: '.AppleSystemUIFontRounded',
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '枚',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: '.AppleSystemUIFontRounded',
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  // 右: 整理を終了
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _finishCurrentSet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.orange, width: 1.5),
                        ),
                        child: const Text(
                          '整理を終了',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // カード+日付+下空白をExpandedで包み、上にSpacer、下は固定の弧+パネル
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              final collapsedCardH =
                  MediaQuery.of(context).size.height * 0.29;
              // 最大化時はカードが利用可能空間いっぱいまで広がる（日付はExpanded外で計算済み）
              final cardH = _isCardExpanded ? maxH : collapsedCardH;
              return Column(
                children: [
                  const Spacer(flex: 2),

                  // メモカード（スワイプ＋スライドアニメーション）+ ロックボタン
                  GestureDetector(
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -200 && canNext) {
                _nextCard();
              } else if (v > 200 && canPrev) {
                _prevCard();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                height: cardH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // カード
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        final isEntering = child.key == ValueKey(memo.id);
                        final offset = _slideForward
                            ? (isEntering ? const Offset(1, 0) : const Offset(-1, 0))
                            : (isEntering ? const Offset(-1, 0) : const Offset(1, 0));
                        return SlideTransition(
                          position: Tween(begin: offset, end: Offset.zero)
                              .animate(animation),
                          child: child,
                        );
                      },
                      child: _QuickSortCard(
                        key: ValueKey(memo.id),
                        memo: memo,
                        controller: _cardController,
                        isExpanded: _isCardExpanded,
                        onToggleExpanded: () =>
                            setState(() => _isCardExpanded = !_isCardExpanded),
                        onTagged: () => _taggedMemoIds.add(memo.id),
                        onTitled: () => _titledMemoIds.add(memo.id),
                        onEdited: () => _editedMemoIds.add(memo.id),
                        tabColor: _labTabColor,
                        tagFooterColor: _labTagFooterColor,
                      ),
                    ),
                    // ロック中マーク（カード右上の凹み部分に表示）
                    if (memo.isLocked)
                      Positioned(
                        right: 8,
                        top: 4,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

                  // 日付情報（AnimatedSizeで滑らかに出し入れ）
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _isCardExpanded
                        ? const SizedBox(width: double.infinity, height: 0)
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '更新日：${_formatDate(memo.updatedAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '作成日：${_formatDate(memo.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),

                  // カード下のスペース（Expanded内。最大化時に縮みカードが上下に伸びる）
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _isCardExpanded ? 0 : 90,
                  ),
                ],
              );
            }),
          ),

          // 弧型コントローラー（弧線 + 3編集ボタン、最大化中も常時表示・固定位置）
          Builder(builder: (context) {
            final sw = MediaQuery.of(context).size.width;
            const arcH = 70.0;   // 弧の高さ
            const arcOff = 53.0; // 弧のY offset
            const btnHalf = 16.0;
            // 弧のY座標（t=0で左端、t=1で右端）
            // bezier P0=(0,arcH) P1=(mid,0) P2=(W,arcH)
            // y(t) = arcH * ((1-t)² + t²)
            // Stack内での実Y = y(t) + arcOff - btnHalf
            double arcY(double t) =>
                arcH * ((1 - t) * (1 - t) + t * t) + arcOff - btnHalf;

            return SizedBox(
              height: arcH + arcOff - 30, // 弧全体（下端クリップ許容）
              width: sw,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 弧の仕切り線
                  Positioned(
                    top: arcOff,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: Size(sw, arcH),
                      painter: _ArcDividerPainter(),
                    ),
                  ),
                  // 本文（中央 t=0.5）
                  Positioned(
                    top: arcY(0.5),
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _ArcEditButton(
                        label: '本文',
                        color: Colors.grey.withValues(alpha: 0.15),
                        width: null,
                        onTap: () => _setEditMode(_EditMode.content),
                      ),
                    ),
                  ),
                  // タイトル（t=0.2、-15°回転）
                  Positioned(
                    top: arcY(0.2),
                    left: sw * 0.2 - 57,
                    child: Transform.rotate(
                      angle: -10 * pi / 180,
                      child: _ArcEditButton(
                        label: 'タイトル',
                        color: Colors.orange.withValues(alpha: 0.2),
                        width: null,
                        onTap: () => _setEditMode(_EditMode.title),
                      ),
                    ),
                  ),
                  // タグ（t=0.8、+15°回転）
                  Positioned(
                    top: arcY(0.8) - 1,
                    right: sw * 0.2 - 45,
                    child: Transform.rotate(
                      angle: 10 * pi / 180,
                      child: _ArcEditButton(
                        label: 'タグ',
                        color: Colors.cyan.withValues(alpha: 0.2),
                        width: 95,
                        onTap: () => _setEditMode(_EditMode.tag),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // 弧と操作パネルの間（固定。旧値48で弧位置を元に戻す）
          const SizedBox(height: 40),

          // 下部操作パネル（本家準拠: ZStack方式）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              height: 70,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 左端: 前へ（三角形）
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _TriangleNavButton(
                        onTap: canPrev ? _prevCard : null,
                        enabled: canPrev,
                        direction: _TriangleDirection.left,
                      ),
                    ),
                  ),
                  // 中央: 削除（白丸50x50 + ラベル）
                  Positioned.fill(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, 16),
                        child: _PressableButton(
                          onTap: memo.isLocked ? null : () => _deleteCurrent(memo),
                          shadowHeight: memo.isLocked ? 0 : 4,
                          color: memo.isLocked
                              ? const Color(0xFFEEEEEE)
                              : Colors.white,
                          isCircle: true,
                          size: 50,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.delete_simple,
                                  size: 22,
                                  color: memo.isLocked
                                      ? Colors.grey.shade400
                                      : Colors.red),
                              Text('削除',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: memo.isLocked
                                          ? Colors.grey.shade400
                                          : Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ロックボタン（削除の右上あたり）
                  Positioned(
                    left: MediaQuery.of(context).size.width / 2 - 20 + 64,
                    top: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLock(memo),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: memo.isLocked
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: memo.isLocked
                                    ? Colors.red.withValues(alpha: 0.4)
                                    : Colors.grey.withValues(alpha: 0.4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              memo.isLocked ? Icons.lock : Icons.no_encryption_outlined,
                              size: 13,
                              color: memo.isLocked
                                  ? Colors.red
                                  : Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          memo.isLocked ? 'ロック ON' : 'ロック OFF',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: memo.isLocked
                                ? Colors.red
                                : Colors.grey.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右端: 次へ or 完了
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: isLast
                          ? _PressableButton(
                              onTap: _finishCurrentSet,
                              shadowHeight: 3,
                              color: Colors.orange,
                              borderRadius: 20,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('完了',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  SizedBox(width: 4),
                                  Icon(Icons.chevron_right,
                                      size: 16, color: Colors.white),
                                ],
                              ),
                            )
                          : _TriangleNavButton(
                              onTap: canNext ? _nextCard : null,
                              enabled: canNext,
                              direction: _TriangleDirection.right,
                            ),
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

  // 編集モード切替（弧ボタンから呼ばれる）
  void _setEditMode(_EditMode mode) {
    switch (mode) {
      case _EditMode.title:
        _cardController.focusTitle?.call();
      case _EditMode.content:
        _cardController.focusContent?.call();
      case _EditMode.tag:
        _cardController.openTagPicker?.call();
      case _EditMode.none:
        _cardController.unfocus?.call();
    }
  }

  // ✕ボタン等の丸いボタン
  Widget _circleButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.5, color: Colors.grey[600]),
      ),
    );
  }

  // ナビの三角ボタン
  Widget _navTriangle({
    required IconData icon,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled
              ? [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )]
              : null,
        ),
        child: Icon(icon,
            size: 28,
            color: enabled ? Colors.white : Colors.grey[400]),
      ),
    );
  }

  // ナビの丸ボタン（削除・ロック）
  Widget _navCircleButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 50,
    double iconSize = 20,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  void _toggleLock(Memo memo) async {
    final db = ref.read(databaseProvider);
    final newLocked = !memo.isLocked;
    await db.updateMemo(id: memo.id, isLocked: newLocked);
    if (!mounted) return;
    // DBから最新のメモを再取得してローカルリストを更新
    final updated = await (db.select(db.memos)
      ..where((t) => t.id.equals(memo.id)))
        .getSingleOrNull();
    if (!mounted || updated == null) return;
    final idx = _activeMemos.indexWhere((m) => m.id == memo.id);
    if (idx >= 0) {
      _activeMemos[idx] = updated;
    }
    // allFilteredMemosも更新
    final allIdx = _allFilteredMemos.indexWhere((m) => m.id == memo.id);
    if (allIdx >= 0) {
      _allFilteredMemos[allIdx] = updated;
    }
    setState(() {});
  }

  void _prevCard() => setState(() {
    _slideForward = false;
    _currentCardIndex--;
  });

  void _nextCard() => setState(() {
    _slideForward = true;
    _currentCardIndex++;
  });

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

  // ========================================
  // カラーラボ（開発用）
  // ========================================
  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  void _showColorLab(BuildContext context) {
    // タブ用カラーパレット: ベース色 × alpha
    final tabSamples = <_ColorSample>[];
    final baseCols = {
      // オレンジ系
      'FF9800': Colors.orange,
      'FF9500': const Color(0xFFFF9500),  // SwiftのColor.orange
      'FFB74D': const Color(0xFFFFB74D),  // orange[300]
      'FFCC80': const Color(0xFFFFCC80),  // orange[200]
      'FFE0B2': const Color(0xFFFFE0B2),  // orange[100]
      'FFF3E0': const Color(0xFFFFF3E0),  // orange[50]
      // ピンク〜オレンジ間（サーモン〜ピーチ〜コーラル）
      'FF8A65': const Color(0xFFFF8A65),  // deepOrange[300]
      'FFAB91': const Color(0xFFFFAB91),  // deepOrange[200]
      'FFCCBC': const Color(0xFFFFCCBC),  // deepOrange[100]
      'FBE9E7': const Color(0xFFFBE9E7),  // deepOrange[50]
      'FF7043': const Color(0xFFFF7043),  // deepOrange[400]
      'E08060': const Color(0xFFE08060),  // サーモン
      'F4A460': const Color(0xFFF4A460),  // サンディブラウン
      'FFBEA0': const Color(0xFFFFBEA0),  // ライトサーモン
      'FFD0B0': const Color(0xFFFFD0B0),  // ピーチ
      'FFDAB9': const Color(0xFFFFDAB9),  // ピーチパフ
      'FFE4C4': const Color(0xFFFFE4C4),  // ビスク
      'FF6F61': const Color(0xFFFF6F61),  // コーラル（パントン）
      'FF8C69': const Color(0xFFFF8C69),  // サーモン2
      'FFA07A': const Color(0xFFFFA07A),  // ライトサーモン
      'FFB088': const Color(0xFFFFB088),  // ピーチ系
      'FFC0A0': const Color(0xFFFFC0A0),  // ヌード系
      // ピンク系
      'FF80AB': const Color(0xFFFF80AB),  // pink accent[100]
      'F48FB1': const Color(0xFFF48FB1),  // pink[200]
      'F8BBD0': const Color(0xFFF8BBD0),  // pink[100]
      'FCE4EC': const Color(0xFFFCE4EC),  // pink[50]
      // アンバー系
      'FFC107': Colors.amber,
      'FFD54F': const Color(0xFFFFD54F),  // amber[300]
      'FFE082': const Color(0xFFFFE082),  // amber[200]
    };
    for (final e in baseCols.entries) {
      for (final a in [0.04, 0.06, 0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.22, 0.28]) {
        tabSamples.add(_ColorSample(
          '${e.key} @${(a * 100).toInt()}%',
          e.value.withValues(alpha: a),
        ));
      }
    }

    // タグフッター用カラーパレット
    final footerSamples = <_ColorSample>[];
    final footerCols = {
      'cyan': Colors.cyan,
      '00BCD4': const Color(0xFF00BCD4),
      'B2EBF2': const Color(0xFFB2EBF2),  // cyan[100]
      '80DEEA': const Color(0xFF80DEEA),  // cyan[200]
      '4DD0E1': const Color(0xFF4DD0E1),  // cyan[300]
      'E0F7FA': const Color(0xFFE0F7FA),  // cyan[50]
    };
    for (final e in footerCols.entries) {
      for (final a in [0.02, 0.04, 0.06, 0.08, 0.10, 0.14]) {
        footerSamples.add(_ColorSample(
          '${e.key} @${(a * 100).toInt()}%',
          e.value.withValues(alpha: a),
        ));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Color Lab',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const Text('タイトルタブ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tabSamples.map((s) => GestureDetector(
                      onTap: () {
                        setState(() => _labTabColor = s.color);
                        Navigator.pop(ctx);
                      },
                      child: Tooltip(
                        message: s.label,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _labTabColor == s.color
                                  ? Colors.blue : Colors.grey[300]!,
                              width: _labTabColor == s.color ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('タグフッター',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: footerSamples.map((s) => GestureDetector(
                      onTap: () {
                        setState(() => _labTagFooterColor = s.color);
                        Navigator.pop(ctx);
                      },
                      child: Tooltip(
                        message: s.label,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _labTagFooterColor == s.color
                                  ? Colors.blue : Colors.grey[300]!,
                              width: _labTagFooterColor == s.color ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  // 現在の値を表示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tab: ${_labTabColor.toString()}\n'
                      'Footer: ${_labTagFooterColor.toString()}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
  final _CardController? controller;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback onTagged;
  final VoidCallback onTitled;
  final VoidCallback onEdited;
  final Color tabColor;
  final Color tagFooterColor;

  const _QuickSortCard({
    super.key,
    required this.memo,
    this.controller,
    this.isExpanded = false,
    this.onToggleExpanded,
    required this.onTagged,
    required this.onTitled,
    required this.onEdited,
    required this.tabColor,
    required this.tagFooterColor,
  });

  @override
  ConsumerState<_QuickSortCard> createState() => _QuickSortCardState();
}

class _QuickSortCardState extends ConsumerState<_QuickSortCard> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();
  List<Tag> _memoTags = [];
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo.title);
    _contentController = TextEditingController(text: widget.memo.content);
    _titleFocus.addListener(_onTitleFocusChanged);
    _contentFocus.addListener(_onContentFocusChanged);
    _bindController(widget.controller);
    _loadTags();
  }

  void _bindController(_CardController? c) {
    if (c == null) return;
    c.focusTitle = () => _titleFocus.requestFocus();
    c.focusContent = () => _contentFocus.requestFocus();
    c.openTagPicker = () => _showTagPicker(context);
    c.unfocus = () {
      _titleFocus.unfocus();
      _contentFocus.unfocus();
    };
  }

  void _onTitleFocusChanged() {
    if (_titleFocus.hasFocus) {
      _contentFocus.unfocus();
    } else {
      // フォーカスが外れたら保存
      _saveTitle();
    }
    if (mounted) setState(() => _isEditingTitle = _titleFocus.hasFocus);
  }

  void _onContentFocusChanged() {
    if (_contentFocus.hasFocus) {
      _titleFocus.unfocus();
    }
  }

  @override
  void didUpdateWidget(covariant _QuickSortCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _bindController(widget.controller);
    }
    if (oldWidget.memo.id != widget.memo.id) {
      _titleController.text = widget.memo.title;
      _contentController.text = widget.memo.content;
      _titleFocus.unfocus();
      _contentFocus.unfocus();
      _isEditingTitle = false;
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
  }

  void _saveContent() {
    final db = ref.read(databaseProvider);
    db.updateMemo(id: widget.memo.id, content: _contentController.text);
    widget.onEdited();
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _contentFocus.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 親タグの色（ボーダーに使用）
  Color? get _parentTagColor {
    final parent = _memoTags.where((t) => t.parentTagId == null).firstOrNull;
    return parent != null ? TagColors.getColor(parent.colorIndex) : null;
  }

  // 全角換算8文字に丸め（本家 truncatedTagName 準拠）
  String _truncated(String name) {
    var width = 0.0;
    var result = '';
    for (final ch in name.characters) {
      final w = ch.codeUnitAt(0) < 128 ? 0.5 : 1.0;
      if (width + w > 8) return '$result…';
      width += w;
      result += ch;
    }
    return result;
  }

  // 親+子タグの重ねめり込みバッジ一覧を構築
  List<Widget> _buildTagBadges() {
    final parents = _memoTags.where((t) => t.parentTagId == null).toList();
    final children = _memoTags.where((t) => t.parentTagId != null).toList();
    final widgets = <Widget>[];

    for (final parent in parents) {
      // この親に属する子タグを探す
      final child = children
          .where((c) => c.parentTagId == parent.id)
          .firstOrNull;
      if (child != null) {
        children.remove(child);
      }
      widgets.add(_tagBadgePair(parent, child));
    }

    // 親がないまま残った子タグ（単独表示）
    for (final orphan in children) {
      widgets.add(_tagBadgeSingle(orphan, isChild: true));
    }

    return widgets;
  }

  Widget _tagBadgePair(Tag parent, Tag? child) {
    final parentColor = TagColors.getColor(parent.colorIndex);
    final parentWidget = Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: parentColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _truncated(parent.name),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          height: 1.0,
        ),
      ),
    );

    if (child == null) return parentWidget;

    final childColor = TagColors.getColor(child.colorIndex);
    final childWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: childColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        _truncated(child.name),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black,
          height: 1.0,
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: parentWidget),
          Flexible(
            child: Transform.translate(
              offset: const Offset(-4, 1.5),
              child: childWidget,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagBadgeSingle(Tag tag, {bool isChild = false}) {
    return Container(
      padding: isChild
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
          : const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: TagColors.getColor(tag.colorIndex),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _truncated(tag.name),
        style: TextStyle(
          fontSize: isChild ? 12 : 13,
          fontWeight: isChild ? FontWeight.w500 : FontWeight.w600,
          color: Colors.black,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tabHeight = 34.0;
    const tabRatio = 0.68;

    return LayoutBuilder(builder: (context, constraints) {
      final tabWidth = constraints.maxWidth * tabRatio;
      final borderColor = _parentTagColor;

      // カード全体の外形パスを描画するCustomPaint + 内部レイアウト
      return CustomPaint(
        painter: _CardWithTabPainter(
          tabWidth: tabWidth,
          tabHeight: tabHeight,
          tabColor: _isEditingTitle
              ? const Color(0xFFFFE0B2)
              : const Color(0xFFFFF0DB),
          bodyColor: Colors.white,
          borderColor: borderColor?.withValues(alpha: 0.4) ??
              Colors.grey.withValues(alpha: 0.2),
          borderWidth: 2.5,
          cornerRadius: 14,
          tabTopRadius: 7,
          tabRootRadius: 9,
          tabRightInset: 10,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shadowBlur: 8,
          shadowOffsetY: 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトルタブ領域
            SizedBox(
              width: tabWidth,
              height: tabHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    onTap: TextMenuDismisser.wrap(null),
                    contextMenuBuilder: TextMenuDismisser.builder,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'タイトルなし',
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 1,
                    onChanged: (_) => _saveTitle(),
                    onSubmitted: (_) => _titleFocus.unfocus(),
                  ),
                ),
              ),
            ),

            // 本文 + タグフッター
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 本文
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: TextField(
                            controller: _contentController,
                            focusNode: _contentFocus,
                            onTap: TextMenuDismisser.wrap(null),
                            contextMenuBuilder: TextMenuDismisser.builder,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                color: Colors.black87),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'メモを入力...',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => _saveContent(),
                          ),
                        ),
                      ),

                      // タグフッター（本文との仕切り線付き）
                      GestureDetector(
                        onTap: () => _showTagPicker(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: widget.tagFooterColor,
                            border: Border(
                              top: BorderSide(
                                color: _parentTagColor?.withValues(alpha: 0.4) ??
                                    Colors.grey.withValues(alpha: 0.2),
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text('タグ:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[500])),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _memoTags.isEmpty
                                    ? Align(
                                        alignment: Alignment.centerRight,
                                        child: Text('なし',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[400])),
                                      )
                                    : Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.end,
                                        children: _buildTagBadges(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 右上ステータスアイコン
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.memo.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin,
                                size: 12,
                                color: Colors.orange.withValues(alpha: 0.6)),
                          ),
                        if (widget.memo.isMarkdown)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('MD',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 最大化/縮小ボタン（タグフッター上・右下）
                  if (widget.onToggleExpanded != null)
                    Positioned(
                      right: 8,
                      bottom: 48,
                      child: GestureDetector(
                        onTap: widget.onToggleExpanded,
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
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
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

// ========================================
// フィルター選択画面（Swift版準拠）
// 複数条件OR選択、件数表示、タグ展開
// ========================================
class _QuickSortFilterPhase extends ConsumerStatefulWidget {
  final void Function(List<Memo> memos) onStart;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  const _QuickSortFilterPhase({
    required this.onStart,
    required this.onBack,
    required this.onCancel,
  });

  @override
  ConsumerState<_QuickSortFilterPhase> createState() =>
      _QuickSortFilterPhaseState();
}

class _QuickSortFilterPhaseState
    extends ConsumerState<_QuickSortFilterPhase> {
  // フィルタ条件（複数選択可）
  bool _filterNoTag = false;
  bool _filterNoTitle = false;
  bool _filterOld = false;
  bool _filterAll = false;
  bool _filterByTag = false;
  final Set<String> _selectedTagIds = {};

  // メモ・タグキャッシュ
  List<Memo> _allMemos = [];
  List<Tag> _parentTags = [];
  Set<String> _taggedMemoIds = {};
  // タグID → メモIDの逆引きマップ
  Map<String, Set<String>> _tagToMemoIds = {};
  bool _loaded = false;

  DateTime get _threeMonthsAgo =>
      DateTime.now().subtract(const Duration(days: 90));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final memos = await db.select(db.memos).get();
    final tags = await db.select(db.tags).get();
    final memoTags = await db.select(db.memoTags).get();
    // タグ→メモの逆引きマップを構築
    final tagMap = <String, Set<String>>{};
    for (final mt in memoTags) {
      tagMap.putIfAbsent(mt.tagId, () => {}).add(mt.memoId);
    }
    if (!mounted) return;
    setState(() {
      _allMemos = memos;
      _parentTags = tags.where((t) => t.parentTagId == null).toList();
      _taggedMemoIds = memoTags.map((mt) => mt.memoId).toSet();
      _tagToMemoIds = tagMap;
      _loaded = true;
    });
  }

  // フィルタ適用後のメモリスト
  List<Memo> get _filteredMemos {
    if (!_loaded) return [];
    if (_filterAll) {
      return _sortedMemos(_allMemos);
    }
    final result = <String>{};
    for (final memo in _allMemos) {
      if (_filterNoTag && !_taggedMemoIds.contains(memo.id)) {
        result.add(memo.id);
      }
      if (_filterNoTitle && memo.title.trim().isEmpty) {
        result.add(memo.id);
      }
      if (_filterOld) {
        final lastAccess = memo.lastViewedAt ?? memo.updatedAt;
        if (lastAccess.isBefore(_threeMonthsAgo)) {
          result.add(memo.id);
        }
      }
      if (_filterByTag && _selectedTagIds.isNotEmpty) {
        // キャッシュ済みの逆引きマップで判定
        for (final tagId in _selectedTagIds) {
          final memoIds = _tagToMemoIds[tagId];
          if (memoIds != null && memoIds.contains(memo.id)) {
            result.add(memo.id);
            break;
          }
        }
      }
    }
    return _sortedMemos(
        _allMemos.where((m) => result.contains(m.id)).toList());
  }

  List<Memo> _sortedMemos(List<Memo> memos) {
    final sorted = List<Memo>.from(memos);
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.manualSortOrder != b.manualSortOrder) {
        return b.manualSortOrder.compareTo(a.manualSortOrder);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int get _filteredCount => _filteredMemos.length;

  // 各フィルタ条件の件数
  int get _noTagCount =>
      _allMemos.where((m) => !_taggedMemoIds.contains(m.id)).length;
  int get _noTitleCount =>
      _allMemos.where((m) => m.title.trim().isEmpty).length;
  int get _tagFilteredCount {
    final memoIds = <String>{};
    for (final tagId in _selectedTagIds) {
      final ids = _tagToMemoIds[tagId];
      if (ids != null) memoIds.addAll(ids);
    }
    return memoIds.length;
  }

  int get _oldCount => _allMemos.where((m) {
        final lastAccess = m.lastViewedAt ?? m.updatedAt;
        return lastAccess.isBefore(_threeMonthsAgo);
      }).length;

  // 排他制御: 「すべて」を選ぶと他OFF
  void _toggleFilter(String key) {
    setState(() {
      switch (key) {
        case 'noTag':
          _filterNoTag = !_filterNoTag;
          if (_filterNoTag) _filterAll = false;
        case 'noTitle':
          _filterNoTitle = !_filterNoTitle;
          if (_filterNoTitle) _filterAll = false;
        case 'old':
          _filterOld = !_filterOld;
          if (_filterOld) _filterAll = false;
        case 'byTag':
          _filterByTag = !_filterByTag;
          if (_filterByTag) {
            _filterAll = false;
          } else {
            _selectedTagIds.clear();
          }
        case 'all':
          _filterAll = !_filterAll;
          if (_filterAll) {
            _filterNoTag = false;
            _filterNoTitle = false;
            _filterOld = false;
            _filterByTag = false;
            _selectedTagIds.clear();
          }
      }
    });
  }

  bool get _anyFilterSelected =>
      _filterNoTag ||
      _filterNoTitle ||
      _filterOld ||
      _filterAll ||
      (_filterByTag && _selectedTagIds.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          // ナビバー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  label: const Text('戻る', style: TextStyle(fontSize: 16)),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('閉じる',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              ],
            ),
          ),

          // フィルタ案内ヘッダー
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('対象のメモを選んでください',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Text('複数選択可',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue)),
          const SizedBox(height: 16),

          // スクロール領域
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // フィルタ条件リスト
                  _buildFilterList(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 開始ボタン（固定フッター）
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildFilterList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // タグなし
            _buildFilterRow(
              icon: Icons.label_off,
              iconColor: Colors.orange,
              title: 'タグなしのメモ',
              count: _noTagCount,
              isOn: _filterNoTag,
              onTap: () => _toggleFilter('noTag'),
            ),
            _filterDivider(),

            // タイトルなし
            _buildFilterRow(
              icon: Icons.title,
              iconColor: Colors.blue,
              title: 'タイトルなしのメモ',
              count: _noTitleCount,
              isOn: _filterNoTitle,
              onTap: () => _toggleFilter('noTitle'),
            ),
            _filterDivider(),

            // 3ヶ月以上
            _buildFilterRow(
              icon: Icons.access_time,
              iconColor: Colors.purple,
              title: '3ヶ月以上開いていない',
              count: _oldCount,
              isOn: _filterOld,
              onTap: () => _toggleFilter('old'),
            ),
            _filterDivider(),

            // 特定のタグ
            _buildFilterRow(
              icon: Icons.label,
              iconColor: Colors.green,
              title: '特定のタグのメモ',
              count: (_filterByTag && _selectedTagIds.isNotEmpty)
                  ? _tagFilteredCount
                  : null,
              isOn: _filterByTag && _selectedTagIds.isNotEmpty,
              trailing: Icon(
                _filterByTag
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: _filterByTag ? Colors.orange : Colors.grey[400],
              ),
              onTap: () => _toggleFilter('byTag'),
            ),

            // タグ選択リスト（展開時のみ）
            if (_filterByTag) _buildTagSelection(),

            _filterDivider(),

            // すべて
            _buildFilterRow(
              icon: Icons.all_inbox,
              iconColor: Colors.grey,
              title: 'すべてのメモ',
              count: _allMemos.length,
              isOn: _filterAll,
              onTap: () => _toggleFilter('all'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int? count,
    required bool isOn,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            if (count != null) ...[
              Text('$count件',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(width: 10),
            ],
            // チェックマーク円
            Icon(
              isOn ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: isOn ? Colors.orange : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSelection() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: _parentTags.map((tag) {
          final isSelected = _selectedTagIds.contains(tag.id);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedTagIds.remove(tag.id);
                } else {
                  _selectedTagIds.add(tag.id);
                }
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 50, right: 16, top: 10, bottom: 10),
              child: Row(
                children: [
                  // タグ色丸
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: TagColors.getColor(tag.colorIndex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tag.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    '${_tagToMemoIds[tag.id]?.length ?? 0}件',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 18,
                    color: isSelected ? Colors.green : Colors.grey[300],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _filterDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }

  Widget _buildStartButton() {
    final count = _filteredCount;
    final enabled = _anyFilterSelected && count > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: enabled ? () => widget.onStart(_filteredMemos) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? Colors.orange : Colors.grey[400],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: enabled ? 2 : 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 20),
              const SizedBox(width: 8),
              Text(
                '開始（$count件）',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================
// ローディング画面（純粋な演出）
// ========================================
class _QuickSortLoading extends StatefulWidget {
  final int memoCount;
  final VoidCallback onComplete;

  const _QuickSortLoading({
    required this.memoCount,
    required this.onComplete,
  });

  @override
  State<_QuickSortLoading> createState() => _QuickSortLoadingState();
}

class _QuickSortLoadingState extends State<_QuickSortLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    // 10件以下: 1.5秒、11件以上: 3秒（Swift版準拠）
    final duration = widget.memoCount <= 10
        ? const Duration(milliseconds: 1500)
        : const Duration(milliseconds: 3000);

    _controller = AnimationController(vsync: this, duration: duration);
    // イーズアウト風カーブ（最初速く、最後ゆっくり）
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.0, 0.0, 0.2, 1.0),
    );
    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final value = _progress.value;
          final percent = (value * 100).toInt();

          return Column(
            children: [
              const Spacer(),

              // ドキュメントアイコン
              Transform.rotate(
                angle: -0.52, // -30度
                child: Icon(Icons.file_copy,
                    size: 50, color: Colors.green[400]),
              ),
              const SizedBox(height: 20),

              // テキスト
              Text(
                '${widget.memoCount}件のメモを準備中…',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 24),

              // プログレスバー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 12,
                        child: Stack(
                          children: [
                            // 背景
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF858585).withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            // プログレス
                            FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.yellow, Colors.orange],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Menlo',
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          );
        },
      ),
    );
  }
}

// ========================================
// イントロ画面（説明）
// ========================================
class _QuickSortIntro extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onCancel;

  const _QuickSortIntro({
    required this.onNext,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ナビバー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('閉じる',
                      style: TextStyle(fontSize: 16, color: Colors.blue)),
                ),
                const Spacer(),
              ],
            ),
          ),

          const Spacer(flex: 2),

          // メインコンテンツ
          const Text(
            '爆速メモ整理モード',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Icon(Icons.bolt, size: 48, color: Colors.orange),
          const SizedBox(height: 20),

          // 説明文（全行の左端を揃えて中央配置）
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'お好みの条件で抽出したメモを連続で表示し、一気に',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                // チェックリスト
                ...[
                  'タイトル編集',
                  'タグ付け',
                  '本文編集',
                  'ロック（削除防止）',
                  '削除',
                ].map((text) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_box,
                              size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(text,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                const SizedBox(height: 6),
                Text(
                  'ができるモードです。',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '未整理のメモが溜まってきたら、ぜひ活用してください。',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),

          // 次へボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '次へ',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Phase { intro, filter, loading, carousel, result }
enum _EditMode { none, title, content, tag }

/// カード内フォーカスを弧ボタンから操作するためのコントローラー
class _CardController {
  VoidCallback? focusTitle;
  VoidCallback? focusContent;
  VoidCallback? openTagPicker;
  VoidCallback? unfocus;
}

// ========================================
// 押下エフェクト付きボタン（本家 TapPressableView 準拠）
// ========================================
class _PressableButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final double shadowHeight;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool isCircle;
  final double? size;

  const _PressableButton({
    required this.child,
    required this.color,
    this.onTap,
    this.shadowHeight = 4,
    this.borderRadius = 12,
    this.padding,
    this.isCircle = false,
    this.size,
  });

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final sh = widget.shadowHeight;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      } : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isPressed ? 35 : 50),
        curve: _isPressed ? Curves.easeIn : Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? sh : 0, 0),
        padding: widget.padding ??
            (widget.isCircle ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
        decoration: widget.isCircle
            ? BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1),
                boxShadow: _isPressed
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 1,
                          offset: Offset(0, sh),
                        ),
                      ],
              )
            : BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3), width: 1),
                boxShadow: _isPressed
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 1,
                          offset: Offset(0, sh),
                        ),
                      ],
              ),
        child: widget.isCircle && widget.size != null
            ? SizedBox(
                width: widget.size! - 2,
                height: widget.size! - 2,
                child: Center(child: widget.child),
              )
            : widget.child,
      ),
    );
  }
}

// ========================================
// 弧型編集ボタン（ArcCapsule + マット塗り）
// ========================================
class _ArcEditButton extends StatefulWidget {
  final String label;
  final Color color;
  final double? width;
  final VoidCallback onTap;

  const _ArcEditButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.width,
  });

  @override
  State<_ArcEditButton> createState() => _ArcEditButtonState();
}

class _ArcEditButtonState extends State<_ArcEditButton> {
  bool _isPressed = false;
  static const double _shadowHeight = 4;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isPressed ? 35 : 50),
        curve: _isPressed ? Curves.easeIn : Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? _shadowHeight : 0, 0),
        child: CustomPaint(
          painter: _ArcCapsulePainter(
            fillColor: Color.alphaBlend(widget.color, Colors.white),
            borderColor: Colors.grey.withValues(alpha: 0.3),
            shadowColor: _isPressed
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.15),
            shadowHeight: _isPressed ? 0 : _shadowHeight,
          ),
          child: SizedBox(
            width: widget.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_square, size: 17, color: Colors.black87),
                  const SizedBox(width: 4),
                  Text(widget.label, style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: '.AppleSystemUIFontRounded',
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 本家 ArcCapsule 準拠: 上下辺が外側に緩やかに膨らむカプセル
class _ArcCapsulePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final double shadowHeight;

  const _ArcCapsulePainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.shadowHeight,
  });

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = h / 2;
    // 本家: bulge = width² / 4800（弧の曲率に合わせた膨らみ）
    final bulge = w * w / 4800;

    final path = Path();
    // 左端の丸み（半円、上から下へ）
    path.moveTo(r, 0);
    path.arcToPoint(Offset(r, h),
        radius: Radius.circular(r), clockwise: false);
    // 下辺（上方向にへこむ弧 = バナナの内側）
    path.quadraticBezierTo(w / 2, h - bulge, w - r, h);
    // 右端の丸み（半円、下から上へ）
    path.arcToPoint(Offset(w - r, 0),
        radius: Radius.circular(r), clockwise: false);
    // 上辺（上方向に膨らむ弧 = バナナの外側）
    path.quadraticBezierTo(w / 2, -bulge, r, 0);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // 影（ぼかし1pt固定・真下）
    if (shadowColor != Colors.transparent && shadowHeight > 0) {
      canvas.save();
      canvas.translate(0, shadowHeight);
      canvas.drawPath(path, Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
      canvas.restore();
    }

    // 塗り
    canvas.drawPath(path, Paint()..color = fillColor);

    // 枠線
    canvas.drawPath(path, Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _ArcCapsulePainter old) =>
      old.fillColor != fillColor ||
      old.shadowColor != shadowColor ||
      old.shadowHeight != shadowHeight;
}

// ========================================
// 弧の仕切り線
// ========================================
// ========================================
// 三角形ナビボタン（本家 Triangle 準拠）
// ========================================
enum _TriangleDirection { left, right }

class _TriangleNavButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool enabled;
  final _TriangleDirection direction;

  const _TriangleNavButton({
    required this.onTap,
    required this.enabled,
    required this.direction,
  });

  @override
  State<_TriangleNavButton> createState() => _TriangleNavButtonState();
}

class _TriangleNavButtonState extends State<_TriangleNavButton> {
  bool _isPressed = false;
  static const double _sh = 4;

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? Colors.blue : Colors.blue.withValues(alpha: 0.15);

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.enabled ? (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      } : null,
      onTapCancel: widget.enabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isPressed ? 35 : 50),
        curve: _isPressed ? Curves.easeIn : Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? _sh : 0, 0),
        width: 40,
        height: 40,
        child: CustomPaint(
          size: const Size(40, 40),
          painter: _TrianglePainter(
            color: color,
            shadowColor: (_isPressed || !widget.enabled)
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.15),
            shadowHeight: (_isPressed || !widget.enabled) ? 0 : _sh,
            direction: widget.direction,
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color shadowColor;
  final double shadowHeight;
  final _TriangleDirection direction;

  const _TrianglePainter({
    required this.color,
    required this.shadowColor,
    required this.shadowHeight,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 横向き三角形を直接描く（回転なし→影が真下を保てる）
    final w = size.width;
    final h = size.height;
    final path = Path();
    if (direction == _TriangleDirection.left) {
      // 左向き: 頂点左中央 → 右上 → 右下
      path.moveTo(0, h / 2);
      path.lineTo(w, 0);
      path.lineTo(w, h);
    } else {
      // 右向き: 頂点右中央 → 左上 → 左下
      path.moveTo(w, h / 2);
      path.lineTo(0, 0);
      path.lineTo(0, h);
    }
    path.close();

    // 影（真下、ぼかし1pt固定）
    if (shadowColor != Colors.transparent && shadowHeight > 0) {
      canvas.save();
      canvas.translate(0, shadowHeight);
      canvas.drawPath(path, Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
      canvas.restore();
    }

    // 塗り
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) =>
      old.color != color ||
      old.shadowColor != shadowColor ||
      old.direction != direction;
}

class _ArcDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    // 本家準拠: 左下→右下、制御点は中央上（height:70のframeでminY=0）
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width / 2, 0,
      size.width, size.height,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// カラーラボ用
class _ColorSample {
  final String label;
  final Color color;
  const _ColorSample(this.label, this.color);
}

/// タブ付きカード全体を1つの形状で描画（ボーダー+影がタブまで包む）
class _CardWithTabPainter extends CustomPainter {
  final double tabWidth;
  final double tabHeight;
  final Color tabColor;
  final Color bodyColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  final double tabTopRadius;
  final double tabRootRadius;
  final double tabRightInset;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowOffsetY;

  const _CardWithTabPainter({
    required this.tabWidth,
    required this.tabHeight,
    required this.tabColor,
    required this.bodyColor,
    required this.borderColor,
    required this.borderWidth,
    required this.cornerRadius,
    required this.tabTopRadius,
    required this.tabRootRadius,
    required this.tabRightInset,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowOffsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cr = cornerRadius;
    final tr = tabTopRadius;
    final rr = tabRootRadius;

    // タブ+本体を合わせた外形パス（時計回り）
    final path = _buildOuterPath(w, h, cr, tr, rr);

    // 影
    canvas.save();
    canvas.translate(0, shadowOffsetY);
    canvas.drawPath(
      path,
      Paint()
        ..color = shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur),
    );
    canvas.restore();

    // 本体（白）を全体に塗る
    canvas.drawPath(path, Paint()..color = bodyColor);

    // タブ部分だけ上書き塗り
    // タブ塗り用パス（外形パスのタブ部分と一致）
    final ri = tabRightInset;
    final th = tabHeight;
    final tw = tabWidth;
    final tabPath = Path();
    tabPath.moveTo(0, th);
    var tc = Offset(0, th);
    // 左辺を上へ → 左上角丸
    tc = _arc(tabPath, tc, const Offset(0, 0), Offset(tr, 0), tr);
    // 上辺 → 右上角丸
    tc = _arc(tabPath, tc, Offset(tw - ri, 0), Offset(tw, th), tr);
    // 右斜辺を下へ
    tabPath.lineTo(tw, th);
    tabPath.close();
    canvas.drawPath(tabPath, Paint()..color = tabColor);

    // ボーダー（外形全体）
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  Path _buildOuterPath(double w, double h, double cr, double tr, double rr) {
    final ri = tabRightInset;
    final th = tabHeight;
    final tw = tabWidth;
    final path = Path();

    // スタート: 左下角の少し上
    var cur = Offset(0, h - cr);
    path.moveTo(cur.dx, cur.dy);

    // 左下角丸
    cur = _arc(path, cur, Offset(0, h), Offset(cr, h), cr);
    // 下辺 → 右下角丸
    cur = _arc(path, cur, Offset(w, h), Offset(w, h - cr), cr);
    // 右辺 → 右上角丸（本体部分）
    cur = _arc(path, cur, Offset(w, th), Offset(w - cr, th), cr);
    // 本体上辺 → タブ付け根の逆カーブ
    cur = _arc(path, cur, Offset(tw, th), Offset(tw - ri, 0), rr);
    // タブ右上角丸
    cur = _arc(path, cur, Offset(tw - ri, 0), Offset(tw - ri - tr, 0), tr);
    // タブ上辺 → 左上角丸
    cur = _arc(path, cur, Offset(0, 0), Offset(0, tr), tr);
    // 左辺を下へ
    path.lineTo(0, h - cr);

    path.close();
    return path;
  }

  /// SwiftのaddArc(tangent1:tangent2:radius:)と同等
  Offset _arc(Path path, Offset current, Offset p1, Offset p2, double radius) {
    final v1 = current - p1;
    final v2 = p2 - p1;
    final l1 = v1.distance;
    final l2 = v2.distance;
    if (l1 == 0 || l2 == 0) {
      path.lineTo(p1.dx, p1.dy);
      return p1;
    }
    final u1 = v1 / l1;
    final u2 = v2 / l2;
    final dot = u1.dx * u2.dx + u1.dy * u2.dy;
    if (dot.abs() >= 0.9999) {
      path.lineTo(p1.dx, p1.dy);
      return p1;
    }
    final theta = acos(dot.clamp(-1.0, 1.0));
    final dist = radius / tan(theta / 2);
    final t1 = p1 + u1 * dist;
    final t2 = p1 + u2 * dist;
    final bis = u1 + u2;
    final bisU = bis / bis.distance;
    final centerDist = radius / sin(theta / 2);
    final center = p1 + bisU * centerDist;
    final startAngle = atan2(t1.dy - center.dy, t1.dx - center.dx);
    final endAngle = atan2(t2.dy - center.dy, t2.dx - center.dx);
    var sweep = endAngle - startAngle;
    if (sweep > pi) sweep -= 2 * pi;
    if (sweep < -pi) sweep += 2 * pi;
    path.lineTo(t1.dx, t1.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweep, false,
    );
    return t2;
  }

  @override
  bool shouldRepaint(covariant _CardWithTabPainter old) =>
      old.tabWidth != tabWidth ||
      old.tabHeight != tabHeight ||
      old.tabColor != tabColor ||
      old.bodyColor != bodyColor ||
      old.borderColor != borderColor;
}
