import 'dart:ui';

import 'package:flutter/material.dart';

/// すりガラス背景＋中央配置のカスタムアラートダイアログ
/// Swift版 .alert() 相当（ただしカスタムUI）
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
    // Materialで囲んでテキストの黄色下線（debug警告）を消す
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              // 追加シートと同じすりガラス設定
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.white.withValues(alpha: 0.65),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // タイトル＋メッセージ
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 区切り線
                  Container(
                    height: 0.5,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  // ボタン行
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 0.5,
                              color: Colors.grey.withValues(alpha: 0.4),
                            ),
                          Expanded(
                            child: _ActionButton(
                              action: actions[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        action.onPressed?.call();
      },
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Text(
          action.label,
          style: TextStyle(
            fontSize: 17,
            fontWeight:
                action.isDefault ? FontWeight.w600 : FontWeight.w400,
            color: action.isDestructive
                ? Colors.red
                : const Color(0xFF007AFF),
          ),
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
  return showGeneralDialog<void>(
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
  );
}
