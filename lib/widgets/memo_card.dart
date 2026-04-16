import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../screens/home_screen.dart' show GridSizeOption;

/// メモカード（グリッド表示用）
/// 長押し時のメニューは外側で CupertinoContextMenu でラップして実現する
/// parentTagId を渡すと、本家準拠で右下に子タグバッジを overlay 表示する。
class MemoCard extends ConsumerWidget {
  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final String? parentTagId;
  final GridSizeOption gridSize;
  final bool isHighlighted;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    this.onDoubleTap,
    this.parentTagId,
    this.gridSize = GridSizeOption.grid2x3,
    this.isHighlighted = false,
  });

  // 本家準拠: グリッドサイズに応じたフォントサイズ・行数・パディング
  double get _titleFont => switch (gridSize) {
        GridSizeOption.grid3x6 => 13,
        GridSizeOption.grid2x5 => 15,
        GridSizeOption.grid2x3 => 16,
        GridSizeOption.grid1x2 => 17,
        GridSizeOption.grid1flex => 16,
        GridSizeOption.titleOnly => 14,
      };

  double get _bodyFont => switch (gridSize) {
        GridSizeOption.grid3x6 => 13,
        GridSizeOption.grid2x5 => 14,
        GridSizeOption.grid2x3 => 14,
        GridSizeOption.grid1x2 => 15,
        GridSizeOption.grid1flex => 14,
        GridSizeOption.titleOnly => 12,
      };

  // bodyLines: 0 = 無制限。grid1flex は本家にはないFlutter版の可変モードで最大15行
  int get _bodyLines => switch (gridSize) {
        GridSizeOption.grid3x6 => 1,
        GridSizeOption.grid2x5 => 3,
        GridSizeOption.grid2x3 => 5,
        GridSizeOption.grid1x2 => 4,
        GridSizeOption.grid1flex => 15,
        GridSizeOption.titleOnly => 0,
      };

  double get _cardPadding => switch (gridSize) {
        GridSizeOption.grid3x6 => 4,
        GridSizeOption.grid2x5 => 8,
        GridSizeOption.grid2x3 => 10,
        GridSizeOption.grid1x2 => 12,
        GridSizeOption.grid1flex => 10,
        GridSizeOption.titleOnly => 6,
      };

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

  // タイトルのみモード: HStack 1行スタイル（本家準拠）
  Widget _buildTitleOnly() {
    final hasTitle = memo.title.isNotEmpty;
    final displayTitle = hasTitle ? memo.title : '無題';
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFFFFF3E0) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayTitle,
                style: TextStyle(
                  fontSize: _titleFont,
                  fontWeight:
                      hasTitle ? FontWeight.w700 : FontWeight.w400,
                  color: hasTitle
                      ? Colors.black
                      : Colors.grey.withValues(alpha: 0.5),
                  height: 1.0,
                  fontFamily: 'PingFang JP',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 右端マーク: Pin / Lock（小さめ）
            if (memo.isPinned) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.push_pin,
                size: 9,
                color: Color(0x99FF9500),
              ),
            ],
            if (memo.isLocked) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.lock,
                size: 9,
                color: Color(0x99FF9500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // タイトルのみモードは別レイアウト
    if (gridSize == GridSizeOption.titleOnly) {
      return _buildTitleOnly();
    }
    // 本家準拠: タイトル空なら "(タイトルなし)" を薄く、本文は常に memo.content
    final hasTitle = memo.title.isNotEmpty;
    final displayTitle = hasTitle ? memo.title : '(無題)';
    final displayBody = memo.content;

    // 現在のフォルダの親タグに属する子タグを1つ見つける（本家 childTagForBadge 準拠）
    Tag? childTagBadge;
    if (parentTagId != null) {
      final tags =
          ref.watch(tagsForMemoStreamProvider(memo.id)).valueOrNull ??
              const <Tag>[];
      childTagBadge = tags
          .where((t) => t.parentTagId == parentTagId)
          .firstOrNull;
    }

    // カード本体（白背景・角丸・影）。中身（タイトル・本文）+ 右上 Pin/Lock
    final cardBody = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(_cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: TextStyle(
                    fontSize: _titleFont,
                    fontWeight:
                        hasTitle ? FontWeight.w700 : FontWeight.w400,
                    color: hasTitle
                        ? Colors.black
                        : Colors.grey.withValues(alpha: 0.5),
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(top: 4, bottom: 3),
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
                if (displayBody.isNotEmpty) ...[
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 利用可能な高さから表示できる行数を動的計算
                        final lineHeight = _bodyFont * 1.4;
                        final maxLines = (constraints.maxHeight / lineHeight)
                            .floor()
                            .clamp(1, _bodyLines == 0 ? 999 : _bodyLines);
                        return Text(
                          displayBody,
                          style: TextStyle(
                            fontSize: _bodyFont,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          maxLines: maxLines,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 右上マーク: Pin / Lock（本家 .overlay(alignment: .topTrailing) 準拠）
          if (memo.isPinned || memo.isLocked)
            Positioned(
              top: 3,
              right: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (memo.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Icon(
                        Icons.push_pin,
                        size: 10,
                        color: Color(0x99FF9500), // orange opacity 0.6
                      ),
                    ),
                  if (memo.isLocked)
                    const Icon(
                      Icons.lock,
                      size: 10,
                      color: Color(0x99FF9500),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      // 子タグバッジは右下にカード端からはみ出して表示
      // 親の高さ制約が有限ならカードがセル全体を埋め(StackFit.expand)、
      // 無限なら内容に合わせて縮む(StackFit.loose) — 両ケースに対応
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final hasBoundedHeight = constraints.maxHeight.isFinite;
          return Stack(
            fit: hasBoundedHeight ? StackFit.expand : StackFit.loose,
            clipBehavior: Clip.none,
            children: [
              hasBoundedHeight
                  ? cardBody
                  : SizedBox(width: double.infinity, child: cardBody),
              if (childTagBadge != null)
                Positioned(
                  right: 0,
                  bottom: -2, // カードに少しめり込ませる
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: TagColors.getColor(childTagBadge.colorIndex),
                        borderRadius: BorderRadius.circular(20), // capsule
                      ),
                      child: Text(
                        _truncated(childTagBadge.name),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PingFang JP',
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
