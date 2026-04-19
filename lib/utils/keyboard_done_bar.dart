import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// キーボード完了ボタンを抑制するためのInheritedWidget。
/// モーダルシート等で完了ボタンを非表示にしたい場合に使う。
class SuppressKeyboardDoneBar extends InheritedWidget {
  const SuppressKeyboardDoneBar({super.key, required super.child});

  static bool isSuppressed(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SuppressKeyboardDoneBar>() != null;
  }

  @override
  bool updateShouldNotify(SuppressKeyboardDoneBar oldWidget) => false;
}

/// キーボード表示中にフローティング「完了」ボタンを表示するウィジェット。
/// MaterialAppのbuilderで全体を包めば全画面に自動適用される。
/// SuppressKeyboardDoneBarで包まれた子ツリーでは非表示になる。
class KeyboardDoneBar extends StatelessWidget {
  final Widget child;
  const KeyboardDoneBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;
    final isSuppressed = SuppressKeyboardDoneBar.isSuppressed(context);

    return Stack(
      children: [
        child,
        if (isKeyboardVisible && !isSuppressed)
          Positioned(
            right: 6,
            bottom: bottomInset + 4,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.keyboard_chevron_compact_down,
                        size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('完了', style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    )),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
