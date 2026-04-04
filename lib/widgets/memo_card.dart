import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final dateFormat = DateFormat('M/d HH:mm');
    // タイトルがあればタイトル、なければ本文の先頭を表示
    final displayTitle = memo.title.isNotEmpty
        ? memo.title
        : (memo.content.isNotEmpty ? memo.content : '新規メモ');
    final displayBody =
        memo.title.isNotEmpty ? memo.content : '';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
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
            // タイトル
            Text(
              displayTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (displayBody.isNotEmpty) ...[
              const SizedBox(height: 4),
              Expanded(
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
            ] else
              const Spacer(),
            // 日時
            Text(
              dateFormat.format(memo.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
