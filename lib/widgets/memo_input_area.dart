import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import 'tag_dial_view.dart';

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
  bool _rouletteOpen = false;

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
    final allTagsAsync = ref.watch(allTagsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 0, 2),
      height: 316,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // メイン入力エリア
          Container(
            margin: const EdgeInsets.only(right: 10),
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
              children: [
                _buildHeader(),
                Container(height: 2, color: Colors.grey.withValues(alpha: 0.1)),
                _buildContent(),
                _buildToolbar(),
              ],
            ),
          ),
          // ルーレット（タイトル下端から入力欄下端まで）
          Positioned(
            right: 0,
            top: 42,
            bottom: 0,
            child: allTagsAsync.when(
              data: (allTags) => _buildRoulette(allTags),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ),
        ],
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

    final selectedParent = _attachedTags
        .where((t) => t.parentTagId == null)
        .toList();
    final parentId = selectedParent.isNotEmpty ? selectedParent.first.id : null;
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
                onTap: () => setState(() => _rouletteOpen = !_rouletteOpen),
                behavior: HitTestBehavior.opaque,
                child: CustomPaint(
                  painter: _TrayWithTabPainter(
                    color: const Color.fromRGBO(142, 142, 147, 1),
                    tabWidth: tabW,
                    tabHeight: 22,
                    tabRadius: 6,
                    bodyRadius: 10,
                    innerRadius: 10,
                    bodyPeek: _rouletteOpen ? 0 : peekAmount,
                  ),
                  child: SizedBox(
                    width: trayTotalWidth,
                    child: Column(
                      children: [
                        // ラベル帯
                        SizedBox(
                          height: 22,
                          child: Stack(
                            children: [
                              // 三角マーク（左端）
                              Positioned(
                                left: 4,
                                top: 0,
                                bottom: 0,
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
                              // 親タグ・子タグラベル（右端からの距離で配置）
                              if (_rouletteOpen) ...[
                                Positioned(
                                  right: 221,
                                  top: 0,
                                  bottom: 0,
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
                                  bottom: 0,
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
                                    onTap: () => setState(() => _rouletteOpen = false),
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
                        SizedBox(
                          height: 20,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 親タグ追加（上にオフセット）
                              Positioned(
                                right: 191,
                                top: -17,
                                child: GestureDetector(
                                  onTap: () {},
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
                              // 子タグ追加（上にオフセット）
                              Positioned(
                                right: 78,
                                top: -17,
                                child: GestureDetector(
                                  onTap: () {},
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
                                top: -8,
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chevron_right, size: 12,
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
    if (widget.editingMemoId == null || id == null) return;
    final db = ref.read(databaseProvider);
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
    setState(() {});
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              onChanged: (_) => _onChanged(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '\u30BF\u30A4\u30C8\u30EB\uFF08\u4EFB\u610F\uFF09',
                hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              maxLines: 1,
            ),
          ),
          if (_titleController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _titleController.clear();
                _onChanged();
              },
              child: Icon(Icons.close, size: 16,
                  color: Colors.grey.withValues(alpha: 0.5)),
            ),
          // \u7E26\u7DDA\u30BB\u30D1\u30EC\u30FC\u30BF\uFF08\u5E38\u6642\u8868\u793A\uFF09
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          // \u30BF\u30B0\u30A8\u30EA\u30A2
          if (_attachedTags.isEmpty)
            GestureDetector(
              onTap: () {
                // TODO: \u30C8\u30EC\u30FC\u3092\u958B\u304F
              },
              child: Icon(Icons.sell_outlined, size: 16,
                  color: Colors.grey.withValues(alpha: 0.3)),
            )
          else ...[
            ..._attachedTags.take(2).map((tag) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: TagColors.getColor(tag.colorIndex),
                    borderRadius: BorderRadius.circular(CornerRadius.parentTag),
                  ),
                  child: Text(
                    tag.name.length > 5
                        ? '${tag.name.substring(0, 5)}...'
                        : tag.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                )),
            GestureDetector(
              onTap: () async {
                if (widget.editingMemoId != null) {
                  final db = ref.read(databaseProvider);
                  for (final tag in _attachedTags) {
                    await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
                  }
                  _attachedTags = await db.getTagsForMemo(widget.editingMemoId!);
                  setState(() {});
                }
              },
              child: Icon(Icons.close, size: 14,
                  color: Colors.grey.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: TextField(
          controller: _contentController,
          onChanged: (_) => _onChanged(),
          style: const TextStyle(fontSize: 15, height: 1.5),
          decoration: const InputDecoration(
            hintText: '\u30E1\u30E2\u3092\u5165\u529B...',
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

  Widget _buildToolbar() {
    return Container(
      height: 28,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Row(
        children: [
          GestureDetector(
            onTap: _hasMemo ? _deleteMemo : null,
            child: Icon(Icons.delete_outline,
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
          Icon(Icons.undo, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Icon(Icons.redo, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {},
            child: Text('\u30B3\u30D4\u30FC',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ),
          const SizedBox(width: 12),
          if (_hasMemo)
            GestureDetector(
              onTap: _confirm,
              child: Row(
                children: [
                  Icon(Icons.check, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 2),
                  const Text('\u78BA\u5B9A',
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

class _DialArcShadowPainter extends CustomPainter {
  final double dialHeight;
  static const double radius = 350;

  _DialArcShadowPainter({required this.dialHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = radius + 2;
    final cy = dialHeight / 2;
    final maxSin = min(1.0, cy / radius);
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
