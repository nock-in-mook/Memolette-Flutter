import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'memo_input_area.dart' show EraserGlyph;

/// 爆速モードのカード本文編集中、キーボード上に Overlay 表示するツールバー
/// 4ボタン: 消しゴム / 画像追加 / Undo / Redo
/// 「完了」ボタンは MaterialApp.builder の KeyboardDoneBar が自動で出すため不要
class QuickSortToolbar extends StatelessWidget {
  /// このツールバーの高さ（KeyboardDoneBar.accessoryHeight 用）
  static const double toolbarHeight = 44;

  final bool hasContent;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onClearBody;
  final VoidCallback onAttachImage;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const QuickSortToolbar({
    super.key,
    required this.hasContent,
    required this.canUndo,
    required this.canRedo,
    required this.onClearBody,
    required this.onAttachImage,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: toolbarHeight,
      padding: const EdgeInsets.fromLTRB(16, 6, 14, 6),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasContent ? onClearBody : null,
            child: SizedBox(
              width: 28,
              height: 28,
              child: EraserGlyph(
                color: hasContent
                    ? const Color(0xFFFB8C00)
                    : const Color(0x66FB8C00),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAttachImage,
            child: Icon(CupertinoIcons.photo,
                size: 22, color: Colors.grey[600]),
          ),
          const SizedBox(width: 30),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canUndo ? onUndo : null,
            child: Icon(
              Icons.undo,
              size: 24,
              weight: 700,
              color: canUndo
                  ? const Color(0xFF007AFF)
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 22),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canRedo ? onRedo : null,
            child: Icon(
              Icons.redo,
              size: 24,
              weight: 700,
              color: canRedo
                  ? const Color(0xFF007AFF)
                  : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
