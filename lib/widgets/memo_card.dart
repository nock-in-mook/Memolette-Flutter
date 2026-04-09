import 'package:flutter/material.dart';

import '../db/database.dart';

/// メモカード（グリッド表示用）
class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 本家準拠: タイトル空なら "(タイトルなし)" を薄く、本文は常に memo.content
    final hasTitle = memo.title.isNotEmpty;
    final displayTitle = hasTitle ? memo.title : '(タイトルなし)';
    final displayBody = memo.content;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ピン留め・ロックアイコン行
            if (memo.isPinned || memo.isLocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    if (memo.isPinned)
                      const Icon(Icons.push_pin,
                          size: 14, color: Colors.orange),
                    if (memo.isPinned && memo.isLocked)
                      const SizedBox(width: 4),
                    if (memo.isLocked)
                      const Icon(Icons.lock, size: 14, color: Colors.red),
                  ],
                ),
              ),
            // タイトル（本家: 空なら .regular + gray.opacity(0.5)）
            Text(
              displayTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: hasTitle ? FontWeight.w600 : FontWeight.w400,
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
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
