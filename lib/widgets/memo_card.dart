import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../constants/memo_bg_colors.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../screens/home_screen.dart' show GridSizeOption;
import '../utils/image_storage.dart';
import '../utils/markdown_detect.dart';
import '../utils/responsive.dart';

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
  // 実際の表示行数は LayoutBuilder が constraints.maxHeight から算出し、この値は
  // その「上限 cap」としてのみ機能する。iPad ではカード高さが大きいので cap を緩める。
  int _bodyLinesFor(BuildContext context) {
    final isWide = Responsive.isWide(context);
    final isTablet = Responsive.isTablet(context);
    return switch (gridSize) {
      GridSizeOption.grid3x6 => isWide ? 4 : (isTablet ? 3 : 1),
      GridSizeOption.grid2x5 => isTablet ? 5 : 3,
      GridSizeOption.grid2x3 => isTablet ? 8 : 5,
      GridSizeOption.grid1x2 => isTablet ? 6 : 4,
      GridSizeOption.grid1flex => 20,
      GridSizeOption.titleOnly => 0,
    };
  }

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
  Widget _buildCornerThumb(List<MemoImage> images, {double? size}) {
    final first = images.first;
    final count = images.length;
    final s = size ?? _thumbSize;
    // バッジフォント: サムネが小さいときは控えめに
    final badgeFont = s <= 24 ? 8.0 : 10.0;
    final badgePadH = s <= 24 ? 3.0 : 4.0;
    // 通常時（起動後）はキャッシュ済みなので同期でパス取得 → FutureBuilder を介さず
    // 描画する。これでバッジ操作等の rebuild 時にサムネがチカチカするのを防ぐ。
    final syncPath = ImageStorage.absolutePathSync(first.filePath);
    if (syncPath != null) {
      return _buildThumbContent(syncPath, count, s, badgeFont, badgePadH);
    }
    return FutureBuilder<String>(
      future: ImageStorage.absolutePath(first.filePath),
      builder: (ctx, snap) {
        return _buildThumbContent(snap.data, count, s, badgeFont, badgePadH);
      },
    );
  }

  Widget _buildThumbContent(
      String? path, int count, double s, double badgeFont, double badgePadH) {
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: s,
              height: s,
              color: Colors.grey.shade200,
              child: path == null
                  ? const SizedBox()
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      // サムネは小サイズ。3x retina 想定で cacheWidth を
                      // 実表示の3倍に制限し、フルデコードを避ける
                      cacheWidth: (s * 3).round(),
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
                padding:
                    EdgeInsets.symmetric(horizontal: badgePadH, vertical: 1),
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
            // 右端マーク: eventDate / MD / Pin / Lock / 画像（小さめ）
            if (memo.eventDate != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.event_outlined,
                size: 9,
                color: Color(0xCCFF9500), // orange
              ),
            ],
            if (containsMarkdown(memo.content)) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'MD',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'monospace',
                    height: 1.0,
                  ),
                ),
              ),
            ],
            if (memo.isPinned) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.push_pin,
                size: 9,
                color: Color(0xCC007AFF), // blue
              ),
            ],
            if (memo.isLocked) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.lock,
                size: 9,
                color: Color(0xCCFF3B30), // red
              ),
            ],
            if (hasImages) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.image_outlined,
                size: 9,
                color: Color(0xCCFF9500),
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
                        final rawCap = _bodyLinesFor(context);
                        final cap = rawCap == 0 ? 999 : rawCap;
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
                        // 画像があるときは本文右端に小サムネ + カウントバッジ。
                        // Row だと bodyText の行数が少ないとき crossAxisAlignment が
                        // サムネ高さを潰してアスペクト比が崩れる（横長になる）ため、
                        // Stack + Positioned に切替: 本文右側に padding で逃がし、
                        // サムネは右上に絶対配置して正方形を維持する。
                        // サムネサイズは利用可能高さで頭打ちにして、3x6 など縦に
                        // 余裕がないグリッドでカードからはみ出さないようにする。
                        if (hasImages && _thumbSize > 0) {
                          final actualThumb = constraints.maxHeight.isFinite
                              ? math.min(_thumbSize, constraints.maxHeight)
                              : _thumbSize;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding:
                                    EdgeInsets.only(right: actualThumb + 4),
                                child: bodyText,
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _buildCornerThumb(images,
                                    size: actualThumb),
                              ),
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
          // 上方向のステータスバッジは外側の Stack（子タグバッジと同じ層）に
          // Positioned で出してカード上端からはみ出させる（タイトルと衝突しない）。
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
              // ステータスバッジ群（カード上端からはみ出して横並びで表示）
              if (memo.eventDate != null ||
                  containsMarkdown(memo.content) ||
                  memo.isPinned ||
                  memo.isLocked)
                Positioned(
                  right: 6,
                  top: -5, // カードからはみ出させてタイトルと干渉しない
                  child: IgnorePointer(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (memo.eventDate != null) ...[
                          const Icon(
                            Icons.event_outlined,
                            size: 12,
                            color: Color(0xE6FF9500), // orange
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (containsMarkdown(memo.content)) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'MD',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'monospace',
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (memo.isPinned) ...[
                          const Icon(
                            Icons.push_pin,
                            size: 12,
                            color: Color(0xE6007AFF), // blue
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (memo.isLocked)
                          const Icon(
                            Icons.lock,
                            size: 12,
                            color: Color(0xE6FF3B30), // red
                          ),
                      ],
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
