import 'package:flutter/material.dart';

import '../utils/safe_dialog.dart';
import 'dialog_styles.dart';

/// Memolette オリジナルデザインのカスタムアラートダイアログ。
/// 白背景 + 角丸 + 縦並びボタン（showConfirmDeleteDialog と統一感あり）。
///
/// 単一ボタン: showFrostedAlert(...)
/// 複数ボタン: actions パラメータで複数渡せる
class FrostedAlertDialog extends StatelessWidget {
  final String title;
  final String? message;
  final List<FrostedAlertAction> actions;

  const FrostedAlertDialog({
    super.key,
    required this.title,
    this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: DialogStyles.bodyDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      textAlign: TextAlign.center,
                      style: DialogStyles.title),
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    Text(message!,
                        textAlign: TextAlign.center,
                        style: DialogStyles.message),
                  ],
                  const SizedBox(height: 16),
                  for (int i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ActionButton(action: actions[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final FrostedAlertAction action;
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final isDestructive = action.isDestructive;
    final isDefault = action.isDefault;
    final showBackground = isDestructive || isDefault;
    final accent = isDestructive
        ? DialogStyles.destructive
        : DialogStyles.defaultAction;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        action.onPressed?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: showBackground
            ? DialogStyles.accentButtonDecoration(accent)
            : null,
        alignment: Alignment.center,
        child: Text(
          action.label,
          style: DialogStyles.actionLabel.copyWith(
              color: showBackground ? accent : DialogStyles.textGrey),
        ),
      ),
    );
  }
}

class FrostedAlertAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDefault;
  final bool isDestructive;

  const FrostedAlertAction({
    required this.label,
    this.onPressed,
    this.isDefault = false,
    this.isDestructive = false,
  });
}

/// すりガラスアラートを表示するヘルパー
Future<void> showFrostedAlert({
  required BuildContext context,
  required String title,
  String? message,
  List<FrostedAlertAction>? actions,
}) {
  return focusSafe(
    context,
    () => showGeneralDialog<void>(
      context: context,
      barrierLabel: 'frosted-alert',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return FrostedAlertDialog(
          title: title,
          message: message,
          actions: actions ??
              const [FrostedAlertAction(label: 'OK', isDefault: true)],
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        // フェード＋わずかなズーム
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    ),
  );
}
