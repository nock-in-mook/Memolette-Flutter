import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// キーボード表示中にフローティング「完了」ボタンを表示するウィジェット。
/// Scaffoldのbodyをこれで包むと、キーボード表示中に自動でボタンが出る。
class KeyboardDoneBar extends StatelessWidget {
  final Widget child;
  const KeyboardDoneBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    return Stack(
      children: [
        child,
        if (isKeyboardVisible)
          Positioned(
            right: 12,
            bottom: bottomInset + 8,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
