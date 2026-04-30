import 'package:flutter/material.dart';

import '../utils/safe_dialog.dart';
import 'dialog_styles.dart';

/// 削除確認ダイアログ（Memolette オリジナルデザイン）。
/// メモ・TODO等の「単体削除」確認で共通利用。
///
/// 戻り値: 削除確定で true、キャンセル / barrier タップで false。
Future<bool> showConfirmDeleteDialog({
  required BuildContext context,
  required String title,
  String message = '削除します。よろしいですか？',
  String confirmLabel = '削除する',
  String cancelLabel = 'キャンセル',
}) async {
  final result = await focusSafe(
    context,
    () => showGeneralDialog<bool>(
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
                    Text(title,
                        textAlign: TextAlign.center,
                        style: DialogStyles.title),
                    const SizedBox(height: 12),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: DialogStyles.message),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: DialogStyles.accentButtonDecoration(
                            DialogStyles.destructive),
                        alignment: Alignment.center,
                        child: Text(
                          confirmLabel,
                          style: DialogStyles.actionLabel.copyWith(
                              color: DialogStyles.destructive),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Text(
                          cancelLabel,
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
  return result ?? false;
}
