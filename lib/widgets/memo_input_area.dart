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
      // 新規メモ自動作成（タイトルか本文に入力があれば）
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
    // タグ自動付与
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

    // Swift版準拠: ヘッダー40 + 区切り2 + 本文 + フッター28 + マージン
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 0, 2), // 右マージンなし（トレーがはみ出すため）
      height: 316,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // メイン入力エリア
          Container(
            margin: const EdgeInsets.only(right: 10), // Stack内で右に余白
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
                // Swift版: 区切り線 2pt
                Container(height: 2, color: Colors.grey.withValues(alpha: 0.1)),
                _buildContent(),
                _buildToolbar(),
              ],
            ),
          ),
          // ルーレット（タイトル行の下端〜入力欄の下端）
          Positioned(
            right: 0,
            top: 20, // タブがヘッダー横に出るように（42 - タブ高さ22）
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
    // 「タグなし」オプション + 親タグ
    final parentOptions = [
      const TagDialOption(id: null, name: 'タグなし', color: Colors.white),
      ...parentTags.map((t) => TagDialOption(
            id: t.id,
            name: t.name,
            color: TagColors.getColor(t.colorIndex),
          )),
    ];

    // 選択中の親タグの子タグ
    final selectedParent = _attachedTags
        .where((t) => t.parentTagId == null)
        .toList();
    final parentId = selectedParent.isNotEmpty ? selectedParent.first.id : null;
    final childTags = parentId != null
        ? allTags.where((t) => t.parentTagId == parentId).toList()
        : <Tag>[];
    // 子タグがなくても常に内側リングを表示（「なし」のみ）
    final childOptions = [
      const TagDialOption(id: null, name: '子タグなし', color: Colors.white),
      ...childTags.map((t) => TagDialOption(
            id: t.id,
            name: t.name,
            color: TagColors.getColor(t.colorIndex),
          )),
    ];

    // トレー幅（ルーレットはみ出し分は含まない）
    final trayWidth = _rouletteOpen ? 300.0 : 28.0;
    // ルーレットの左はみ出し量（Swift版準拠: 開き時-27pt）
    const dialOverhang = 60.0;

    return SizedBox(
      width: trayWidth + (_rouletteOpen ? dialOverhang : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // トレー背景（TrayWithTabShape: タブ+ボディ一体型）
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                setState(() => _rouletteOpen = !_rouletteOpen);
              },
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                painter: _TrayWithTabPainter(
                  color: const Color.fromRGBO(142, 142, 147, 1),
                  tabWidth: 22,
                  tabHeight: 22,
                  tabRadius: 6,
                  bodyRadius: 10,
                  innerRadius: 10,
                ),
                child: SizedBox(
                  width: trayWidth + 22, // トレー幅 + タブはみ出し分
                  child: Column(
                    children: [
                      // ラベル帯（タブ領域を含む）
                      GestureDetector(
                        onTap: () =>
                            setState(() => _rouletteOpen = !_rouletteOpen),
                        child: SizedBox(
                          height: 22,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 8),
                            child: Row(
                              children: [
                                Icon(
                                    _rouletteOpen ? Icons.play_arrow : Icons.arrow_left,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.7)),
                                if (_rouletteOpen) ...[
                                  const Spacer(),
                                  Text('親タグ',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.7))),
                                  const SizedBox(width: 24),
                                  Text('子タグ',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.7))),
                                  const Spacer(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                        // トレー中央 + 右端に収納ボタン
                        Expanded(
                          child: _rouletteOpen
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        setState(() => _rouletteOpen = false),
                                    child: Transform.translate(
                                      offset: const Offset(-8, 0),
                                      child: SizedBox(
                                        width: 36,
                                        child: Center(
                                          child: Text(
                                            '›',
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
                        // 下部ボタン
                        if (_rouletteOpen)
                          Container(
                            height: 28,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle_outline,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('親タグ追加',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600])),
                                const SizedBox(width: 12),
                                const Icon(Icons.add_circle_outline,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('子タグ追加',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600])),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // ルーレット本体 + 影（同じPositioned内でStackに重ねる）
          if (_rouletteOpen)
            Positioned(
              right: 0,
              top: 22,   // ラベル分
              bottom: 28, // ボタン分
              width: trayWidth + dialOverhang,
              child: Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: const Offset(-dialOverhang, -5),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 影（TagDialViewと同じサイズ、クリップなし）
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _DialArcShadowPainter(dialHeight: 211),
                          ),
                        ),
                      ),
                      // ルーレット本体
                      TagDialView(
                        height: 211,
                        parentOptions: parentOptions,
                        childOptions: childOptions,
                        selectedParentId: parentId,
                        isOpen: true,
                        onParentSelected: (id) =>
                            _onTagSelected(id, false),
                        onChildSelected: (id) =>
                            _onTagSelected(id, true),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 0,
              top: 22, // ラベル帯の下から
              bottom: 0,
              width: trayWidth,
              child: IgnorePointer(
                child: TagDialView(
                  height: 260,
                  parentOptions: parentOptions,
                  childOptions: childOptions,
                  selectedParentId: parentId,
                  isOpen: false,
                  onParentSelected: (id) =>
                      _onTagSelected(id, false),
                  onChildSelected: (id) =>
                      _onTagSelected(id, true),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onTagSelected(String? id, bool isChild) async {
    if (widget.editingMemoId == null || id == null) return;
    final db = ref.read(databaseProvider);
    // 既存タグを外してから付ける
    if (!isChild) {
      // 親タグ: 既存の親タグを外す
      for (final tag in _attachedTags.where((t) => t.parentTagId == null)) {
        await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
      }
      await db.addTagToMemo(widget.editingMemoId!, id);
    } else {
      // 子タグ: 既存の子タグを外す
      for (final tag in _attachedTags.where((t) => t.parentTagId != null)) {
        await db.removeTagFromMemo(widget.editingMemoId!, tag.id);
      }
      await db.addTagToMemo(widget.editingMemoId!, id);
    }
    _attachedTags = await db.getTagsForMemo(widget.editingMemoId!);
    setState(() {});
  }

  /// ヘッダー（タイトル＋タグバッジ）— Swift版: 40pt高さ
  Widget _buildHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          // タイトル入力
          Expanded(
            child: TextField(
              controller: _titleController,
              onChanged: (_) => _onChanged(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'タイトル（任意）',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              maxLines: 1,
            ),
          ),
          // クリアボタン
          if (_titleController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _titleController.clear();
                _onChanged();
              },
              child: const Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          // 区切り線
          if (_attachedTags.isNotEmpty)
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          // タグバッジ
          ..._attachedTags.take(2).map((tag) => Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: TagColors.getColor(tag.colorIndex),
                  borderRadius: BorderRadius.circular(CornerRadius.childTag),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag.name.length > 5
                          ? '${tag.name.substring(0, 5)}...'
                          : tag.name,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: () async {
                        if (widget.editingMemoId != null) {
                          final db = ref.read(databaseProvider);
                          await db.removeTagFromMemo(
                              widget.editingMemoId!, tag.id);
                          _attachedTags = await db
                              .getTagsForMemo(widget.editingMemoId!);
                          setState(() {});
                        }
                      },
                      child: const Icon(Icons.close,
                          size: 12, color: Colors.black54),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// 本文入力
  Widget _buildContent() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: TextField(
          controller: _contentController,
          onChanged: (_) => _onChanged(),
          style: const TextStyle(fontSize: 15, height: 1.5),
          decoration: const InputDecoration(
            hintText: 'メモを入力...',
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

  /// ツールバー — Swift版: 28pt高さ
  Widget _buildToolbar() {
    return Container(
      height: 28,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Row(
        children: [
          // 削除ボタン
          GestureDetector(
            onTap: _hasMemo ? _deleteMemo : null,
            child: Icon(Icons.delete_outline,
                size: 18,
                color:
                    _hasMemo ? Colors.red.withValues(alpha: 0.5) : Colors.grey.shade300),
          ),
          const SizedBox(width: 12),
          // MDトグル
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
          // Undo / Redo
          Icon(Icons.undo, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Icon(Icons.redo, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 12),
          // コピー
          GestureDetector(
            onTap: () {},
            child: Text('コピー',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ),
          const SizedBox(width: 12),
          // 確定 / メモを閉じる
          if (_hasMemo)
            GestureDetector(
              onTap: _confirm,
              child: Row(
                children: [
                  Icon(Icons.check, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 2),
                  const Text('確定',
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

/// Swift版 TrayWithTabShape の移植
/// タブ（左上に飛び出す取っ手）+ ボディ（本体）の一体型形状
class _TrayWithTabPainter extends CustomPainter {
  final Color color;
  final double tabWidth;
  final double tabHeight;
  final double tabRadius;
  final double bodyRadius;
  final double innerRadius;

  _TrayWithTabPainter({
    required this.color,
    required this.tabWidth,
    required this.tabHeight,
    required this.tabRadius,
    required this.bodyRadius,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyTop = tabHeight;
    final bodyLeftX = tabWidth;
    final ir = innerRadius.clamp(0.0, bodyTop);

    final path = Path();

    // 1. タブ左上角（丸み）
    path.moveTo(0, tabRadius);
    path.arcTo(
      Rect.fromLTWH(0, 0, tabRadius * 2, tabRadius * 2),
      pi, pi / 2, false,
    );

    // 2. タブ上辺 → 右端
    path.lineTo(size.width, 0);

    // 3. 右辺を下へ
    path.lineTo(size.width, size.height);

    // 4. ボディ下辺 → ボディ左下角（丸み）
    path.lineTo(bodyLeftX + bodyRadius, size.height);
    path.arcTo(
      Rect.fromLTWH(bodyLeftX, size.height - bodyRadius * 2, bodyRadius * 2, bodyRadius * 2),
      pi / 2, pi / 2, false,
    );

    // 5. ボディ左辺を上へ → 内側角の手前
    path.lineTo(bodyLeftX, bodyTop + ir);

    // 5.5. 内側角の丸み（凹カーブ: 時計回り = SwiftのclockwiseTrue）
    path.arcTo(
      Rect.fromLTWH(bodyLeftX - ir * 2, bodyTop, ir * 2, ir * 2),
      0, -pi / 2, false,
    );

    // 6. タブ下辺を左へ
    path.lineTo(tabRadius, bodyTop);

    // 7. タブ左下角（丸み）
    path.arcTo(
      Rect.fromLTWH(0, bodyTop - tabRadius * 2, tabRadius * 2, tabRadius * 2),
      pi / 2, pi / 2, false,
    );

    // 8. 閉じる
    path.close();

    // ドロップシャドウ（Swift版準拠: black 20%, radius 3, x -2, y 0）
    canvas.save();
    canvas.translate(-2, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    // 本体
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrayWithTabPainter old) =>
      old.color != color;
}

/// ルーレット外周弧と同じ位置に透明な円弧を描き、影だけ付ける
class _DialArcShadowPainter extends CustomPainter {
  final double dialHeight;
  static const double radius = 350;

  _DialArcShadowPainter({required this.dialHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = radius + 2; // TagDialViewと同じ = 352
    final cy = dialHeight / 2;
    final maxSin = min(1.0, cy / radius);
    final maxAngle = asin(maxSin);

    // 外周弧と同じパス
    final arcPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        pi - maxAngle,
        maxAngle * 2,
      )
      ..close();

    // 影だけ描画（x: -2にオフセット、Swift版準拠: black 50%, radius 3）
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

