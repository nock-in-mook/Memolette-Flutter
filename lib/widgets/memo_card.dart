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
  final String? parentTagId;
  final GridSizeOption gridSize;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    this.parentTagId,
    this.gridSize = GridSizeOption.grid2x3,
  });

  // 本家準拠: グリッドサイズに応じたフォントサイズ・行数・パディング
  double get _titleFont => switch (gridSize) {
        GridSizeOption.grid3x6 => 13,
        GridSizeOption.grid2x5 => 15,
        GridSizeOption.grid2x3 => 16,
        GridSizeOption.grid1x2 => 17,
        GridSizeOption.full => 18,
        GridSizeOption.titleOnly => 14,
      };

  double get _bodyFont => switch (gridSize) {
        GridSizeOption.grid3x6 => 13,
        GridSizeOption.grid2x5 => 14,
        GridSizeOption.grid2x3 => 14,
        GridSizeOption.grid1x2 => 15,
        GridSizeOption.full => 16,
        GridSizeOption.titleOnly => 12,
      };

  // bodyLines: 0 = 無制限
  int get _bodyLines => switch (gridSize) {
        GridSizeOption.grid3x6 => 1,
        GridSizeOption.grid2x5 => 3,
        GridSizeOption.grid2x3 => 5,
        GridSizeOption.grid1x2 => 4,
        GridSizeOption.full => 0,
        GridSizeOption.titleOnly => 0,
      };

  double get _cardPadding => switch (gridSize) {
        GridSizeOption.grid3x6 => 4,
        GridSizeOption.grid2x5 => 8,
        GridSizeOption.grid2x3 => 10,
        GridSizeOption.grid1x2 => 12,
        GridSizeOption.full => 12,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 本家準拠: タイトル空なら "(タイトルなし)" を薄く、本文は常に memo.content
    final hasTitle = memo.title.isNotEmpty;
    final displayTitle = hasTitle ? memo.title : '(タイトルなし)';
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
        color: Colors.white,
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
                        hasTitle ? FontWeight.w600 : FontWeight.w400,
                    color: hasTitle
                        ? Colors.black
                        : Colors.grey.withValues(alpha: 0.5),
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (displayBody.isNotEmpty)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        displayBody,
                        style: TextStyle(
                          fontSize: _bodyFont,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        // 本家準拠: …で省略、グラデーションフェードしない
                        // bodyLines == 0 は無制限
                        maxLines: _bodyLines == 0 ? null : _bodyLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
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
      // 子タグバッジは右下にカード端からはみ出して表示
      // StackFit.expand で cardBody がセル全体を埋めるようにする（縮まない）
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          cardBody,
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
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
