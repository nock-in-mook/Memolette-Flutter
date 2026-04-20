import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../constants/memo_bg_colors.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../screens/home_screen.dart' show GridSizeOption;
import '../utils/image_storage.dart';

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
  // 一時的な強調表示の強度 (0.0 = 表示なし / 1.0 = フル)
  // ロック/トップ移動などの操作後にジワッと点滅させる
  final double flashLevel;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    this.onDoubleTap,
    this.parentTagId,
    this.gridSize = GridSizeOption.grid2x3,
    this.isHighlighted = false,
    this.flashLevel = 0,
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

  // bodyLines: 0 = 無制限。grid1flex は本家にはないFlutter版の可変モードで最大20行
  int get _bodyLines => switch (gridSize) {
        GridSizeOption.grid3x6 => 1,
        GridSizeOption.grid2x5 => 3,
        GridSizeOption.grid2x3 => 5,
        GridSizeOption.grid1x2 => 4,
        GridSizeOption.grid1flex => 20,
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

  /// 本文右端の小サムネ一辺サイズ（正方形、グリッドサイズ連動）。0 は非表示
  double get _thumbSize => switch (gridSize) {
        GridSizeOption.grid3x6 => 22,
        GridSizeOption.grid2x5 => 28,
        GridSizeOption.grid2x3 => 36,
        GridSizeOption.grid1x2 => 44,
        GridSizeOption.grid1flex => 44,
        GridSizeOption.titleOnly => 0,
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

  /// 画像マーカーを画像アイコンに置換したインラインスパンを構築。
  /// 閲覧モードと同じ見た目（テキスト・画像・テキストが縦に並ぶ）になるよう
  /// 画像アイコンの前後に改行を挿入する（既に改行がある場合は二重にしない）。
  List<InlineSpan> _buildBodySpans(String content, double fontSize) {
    final regex = RegExp('\uFFFC[^\uFFFC]+\uFFFC');
    final spans = <InlineSpan>[];
    var cursor = 0;
    bool needsLeadingNewline() {
      if (spans.isEmpty) return false;
      final last = spans.last;
      if (last is TextSpan) {
        final t = last.text ?? '';
        if (t.endsWith('\n')) return false;
      }
      return true;
    }

    for (final match in regex.allMatches(content)) {
      final before = content.substring(cursor, match.start);
      if (before.isNotEmpty) spans.add(TextSpan(text: before));
      if (needsLeadingNewline()) spans.add(const TextSpan(text: '\n'));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            Icons.image_outlined,
            size: fontSize * 0.95,
            color: Colors.grey[600],
          ),
        ),
      ));
      cursor = match.end;
      // 画像アイコンの直後に改行。次の文字が \n ならそれに任せる
      if (cursor < content.length && content[cursor] != '\n') {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    final rest = content.substring(cursor);
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
    return spans;
  }

  /// 本文右端に置く小サムネ（正方形）+ 2枚以上なら右上に件数バッジ
  Widget _buildCornerThumb(List<MemoImage> images) {
    final first = images.first;
    final count = images.length;
    // バッジフォント: サムネが小さいときは控えめに
    final badgeFont = _thumbSize <= 24 ? 8.0 : 10.0;
    final badgePadH = _thumbSize <= 24 ? 3.0 : 4.0;
    return FutureBuilder<String>(
      future: ImageStorage.absolutePath(first.filePath),
      builder: (ctx, snap) {
        final path = snap.data;
        return SizedBox(
          width: _thumbSize,
          height: _thumbSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  color: Colors.grey.shade200,
                  child: path == null
                      ? const SizedBox()
                      : Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          // サムネは小サイズ。3x retina 想定で cacheWidth を
                          // 実表示の3倍に制限し、フルデコードを避ける
                          cacheWidth: (_thumbSize * 3).round(),
                          errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 14),
                        ),
                ),
              ),
              if (count >= 2)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: badgePadH, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: badgeFont,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
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

  // タイトルのみモード: HStack 1行スタイル（本家準拠）
  Widget _buildTitleOnly(WidgetRef ref) {
    final hasImages =
        (ref.watch(memoImagesProvider(memo.id)).valueOrNull ?? const [])
            .isNotEmpty;
    final hasTitle = memo.title.isNotEmpty;
    final displayTitle = hasTitle ? memo.title : '無題';
    // 背景はメモ色（未設定なら白）。ハイライトはオレンジ枠で表現
    final bgColor = memo.bgColorIndex == 0
        ? Colors.white
        : MemoBgColors.getColor(memo.bgColorIndex);
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        // 縁取りは foregroundDecoration として中身に重ねる
        // （border 分だけコンテンツが押されてレイアウトが変わるのを防ぐ）
        foregroundDecoration: flashLevel > 0
            ? BoxDecoration(
                border: Border.all(
                    color: Colors.orange.withValues(alpha: flashLevel * 0.7),
                    width: 1.5),
                borderRadius: BorderRadius.circular(4),
              )
            : isHighlighted
                ? BoxDecoration(
                    border: Border.all(
                        color: Colors.black.withValues(alpha: 0.35),
                        width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
        decoration: BoxDecoration(
          color: bgColor,
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
                      ? const Color(0xFF2D1F50) // 黒寄り紫
                      : Colors.grey.withValues(alpha: 0.5),
                  height: 1.0,
                  fontFamily: 'PingFang JP',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 右端マーク: Pin / Lock / 画像（小さめ）
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
            if (hasImages) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.image_outlined,
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
      return _buildTitleOnly(ref);
    }
    // 本家準拠: タイトル空なら "(タイトルなし)" を薄く、本文は常に memo.content
    final hasTitle = memo.title.isNotEmpty;
    final displayTitle = hasTitle ? memo.title : '(無題)';
    // ブロックエディタの画像マーカー (U+FFFC でID を挟む) は Text.rich で
    // 画像アイコンとしてインライン描画するので、ここでは生の content を保持
    final displayBody = memo.content;
    // 画像（Phase 10）
    final images =
        ref.watch(memoImagesProvider(memo.id)).valueOrNull ?? const <MemoImage>[];
    final hasImages = images.isNotEmpty;

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

    // カード本体（メモ背景色・角丸・影、ハイライトは半透明黒枠）
    final cardBgColor = memo.bgColorIndex == 0
        ? Colors.white
        : MemoBgColors.getColor(memo.bgColorIndex);
    // ValueKey でハイライト状態変化時に Widget を強制差し替え（アニメ抑制）
    final cardBody = KeyedSubtree(
      key: ValueKey('memocard_body_${memo.id}_${isHighlighted ? 1 : 0}_${(flashLevel * 10).round()}'),
      child: Container(
      clipBehavior: Clip.hardEdge,
      // 縁取りは foregroundDecoration で中身に重ねてレイアウトを変えない
      foregroundDecoration: flashLevel > 0
          ? BoxDecoration(
              border: Border.all(
                  color: Colors.orange.withValues(alpha: flashLevel * 0.7),
                  width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : isHighlighted
              ? BoxDecoration(
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.35),
                      width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
      decoration: BoxDecoration(
        color: cardBgColor,
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
                        ? const Color(0xFF2D1F50) // 黒寄り紫
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
                        final lineHeight = _bodyFont * 1.4;
                        // grid1flex のように高さが無限になるケースで
                        // Infinity.floor() が投げられるのを防ぐ
                        final cap = _bodyLines == 0 ? 999 : _bodyLines;
                        final maxLines = constraints.maxHeight.isFinite
                            ? (constraints.maxHeight / lineHeight)
                                .floor()
                                .clamp(1, cap)
                            : cap;
                        final bodyStyle = TextStyle(
                          fontSize: _bodyFont,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          height: 1.4,
                        );
                        final bodyText = Text.rich(
                          TextSpan(
                            style: bodyStyle,
                            children: _buildBodySpans(displayBody, _bodyFont),
                          ),
                          maxLines: maxLines,
                          overflow: TextOverflow.ellipsis,
                        );
                        // 画像があるときは本文右端に小サムネ + カウントバッジ
                        if (hasImages && _thumbSize > 0) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: bodyText),
                              const SizedBox(width: 4),
                              _buildCornerThumb(images),
                            ],
                          );
                        }
                        return bodyText;
                      },
                    ),
                  ),
                ],
                // 本文が空でも画像がある場合は右端サムネだけを出す
                if (displayBody.isEmpty && hasImages && _thumbSize > 0) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildCornerThumb(images),
                  ),
                ],
              ],
            ),
          ),
          // 右上マーク: Pin / Lock / 画像バッジ
          if (memo.isPinned || memo.isLocked || (hasImages && _thumbSize == 0))
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
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Icon(
                        Icons.lock,
                        size: 10,
                        color: Color(0x99FF9500),
                      ),
                    ),
                  // サムネが出ない小さいグリッド用に、画像付きを示すアイコン
                  if (hasImages && _thumbSize == 0)
                    const Icon(
                      Icons.image_outlined,
                      size: 10,
                      color: Color(0x99FF9500),
                    ),
                ],
              ),
            ),
        ],
      ),
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
