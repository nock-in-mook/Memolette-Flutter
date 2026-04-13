import 'dart:math';

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

          // カードを画面中央寄りに浮かせる
          const Spacer(flex: 5),

          // メモカード（スワイプ＋スライドアニメーション）
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
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.29,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    // 進む: 右からスライドイン / 戻る: 左からスライドイン
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
                    onTagged: () => _taggedMemoIds.add(memo.id),
                    onTitled: () => _titledMemoIds.add(memo.id),
                    onEdited: () => _editedMemoIds.add(memo.id),
                    tabColor: _labTabColor,
                    tagFooterColor: _labTagFooterColor,
                  ),
                ),
              ),
            ),
          ),

          // 日付情報
          Align(
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

          // カード下のスペース（弧型コントローラー用）
          const Spacer(flex: 7),

          // ナビゲーション
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 前へ
                _navTriangle(
                  icon: Icons.arrow_left,
                  enabled: canPrev,
                  onTap: canPrev ? _prevCard : null,
                ),
                // 削除
                _navCircleButton(
                  icon: Icons.delete_outline,
                  label: '削除',
                  color: memo.isLocked
                      ? Colors.grey[300]!
                      : Colors.red,
                  onTap: () => _deleteCurrent(memo),
                ),
                // ロック
                _navCircleButton(
                  icon: memo.isLocked
                      ? Icons.lock
                      : Icons.lock_open,
                  label: memo.isLocked ? '解除' : 'ロック',
                  color: memo.isLocked
                      ? Colors.orange
                      : Colors.grey,
                  size: 36,
                  iconSize: 14,
                  onTap: () => _toggleLock(memo),
                ),
                // 次へ or 完了
                if (isLast)
                  GestureDetector(
                    onTap: _finishCurrentSet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                    ),
                  )
                else
                  _navTriangle(
                    icon: Icons.arrow_right,
                    enabled: canNext,
                    onTap: canNext ? _nextCard : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _toggleLock(Memo memo) {
    final db = ref.read(databaseProvider);
    db.updateMemo(id: memo.id, isLocked: !memo.isLocked);
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
  final VoidCallback onTagged;
  final VoidCallback onTitled;
  final VoidCallback onEdited;
  final Color tabColor;
  final Color tagFooterColor;

  const _QuickSortCard({
    super.key,
    required this.memo,
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
  List<Tag> _memoTags = [];
  bool _isEditingTitle = false;
  bool _isEditingContent = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo.title);
    _contentController = TextEditingController(text: widget.memo.content);
    _loadTags();
  }

  @override
  void didUpdateWidget(covariant _QuickSortCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memo.id != widget.memo.id) {
      _titleController.text = widget.memo.title;
      _contentController.text = widget.memo.content;
      _isEditingTitle = false;
      _isEditingContent = false;
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
    setState(() => _isEditingTitle = false);
  }

  void _saveContent() {
    final db = ref.read(databaseProvider);
    db.updateMemo(id: widget.memo.id, content: _contentController.text);
    widget.onEdited();
  }

  @override
  void dispose() {
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
              child: GestureDetector(
                onTap: () {
                  if (!_isEditingTitle) {
                    setState(() => _isEditingTitle = true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _isEditingTitle
                        ? TextField(
                            controller: _titleController,
                            autofocus: true,
                            onTap: TextMenuDismisser.wrap(null),
                            contextMenuBuilder: TextMenuDismisser.builder,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: 'タイトルなし',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _saveTitle(),
                          )
                        : Text(
                            _titleController.text.isEmpty
                                ? 'タイトルなし'
                                : _titleController.text,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _titleController.text.isEmpty
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                          child: _isEditingContent
                              ? TextField(
                                  controller: _contentController,
                                  autofocus: true,
                                  onTap: TextMenuDismisser.wrap(null),
                                  contextMenuBuilder:
                                      TextMenuDismisser.builder,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600, height: 1.5),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'メモを入力...',
                                  ),
                                  onChanged: (_) => _saveContent(),
                                )
                              : GestureDetector(
                                  onTap: () => setState(
                                      () => _isEditingContent = true),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _contentController.text.isEmpty
                                          ? '（内容なし）'
                                          : _contentController.text,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        height: 1.5,
                                        color:
                                            _contentController.text.isEmpty
                                                ? Colors.grey
                                                : Colors.black87,
                                      ),
                                    ),
                                  ),
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
                        if (widget.memo.isLocked)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Colors.orange.withValues(alpha: 0.4),
                                  width: 1),
                            ),
                            child: const Icon(Icons.lock,
                                size: 13, color: Colors.orange),
                          ),
                      ],
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
                                color: Colors.grey.withValues(alpha: 0.15),
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
