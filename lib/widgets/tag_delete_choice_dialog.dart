import 'package:flutter/material.dart';

import '../utils/safe_dialog.dart';
import 'dialog_styles.dart';

/// 親タグ削除時の3択ダイアログ（Memolette オリジナルデザイン）。
/// confirm_delete_dialog 系統のスタイル。
///
/// 戻り値:
/// - 'withMemos': メモも一緒に削除
/// - 'keepMemos': メモは残す（タグなしに変更）
/// - null: キャンセル / barrier タップ
Future<String?> showTagDeleteChoiceDialog({
  required BuildContext context,
  required String tagName,
}) async {
  return focusSafe(
    context,
    () => showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: DialogStyles.bodyDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '「$tagName」を削除します',
                      textAlign: TextAlign.center,
                      style: DialogStyles.title,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'このタグに含まれるメモの扱いを選んでください',
                      textAlign: TextAlign.center,
                      style: DialogStyles.message,
                    ),
                    const SizedBox(height: 16),
                    // メモも一緒に削除（destructive）
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop('withMemos'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: DialogStyles.accentButtonDecoration(
                            DialogStyles.destructive),
                        alignment: Alignment.center,
                        child: Text(
                          'メモも一緒に削除',
                          style: DialogStyles.actionLabel
                              .copyWith(color: DialogStyles.destructive),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // メモは残す（default action）
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop('keepMemos'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: DialogStyles.accentButtonDecoration(
                            DialogStyles.defaultAction),
                        alignment: Alignment.center,
                        child: Text(
                          'メモは残す(タグなしに変更)',
                          style: DialogStyles.actionLabel
                              .copyWith(color: DialogStyles.defaultAction),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Text(
                          'キャンセル',
                          style: DialogStyles.actionLabel
                              .copyWith(color: DialogStyles.textGrey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}
