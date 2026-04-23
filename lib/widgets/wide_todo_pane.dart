import 'package:flutter/material.dart';

import '../screens/todo_list_screen.dart';

/// iPad 横画面のスプリットビューで右カラムに TODO リスト詳細を表示する共通部品。
///
/// 呼び出し側:
/// - メモ一覧 (home_screen): メモタップで入力欄、TODOタップでこのpane を重ね表示
/// - TODO一覧 (todo_lists_screen): リスト選択で右カラムに表示
///
/// 閉じるボタン付き。`onClose` が呼ばれたら呼び出し側で listId を null にするのが前提。
class WideTodoPane extends StatelessWidget {
  final String listId;
  final VoidCallback onClose;

  const WideTodoPane({
    super.key,
    required this.listId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: Colors.white,
            child: TodoListScreen(
              key: ValueKey('wide_todo_$listId'),
              listId: listId,
              embedded: true,
            ),
          ),
        ),
        // 左上に浮かせる「閉じる」ボタン
        Positioned(
          left: 8,
          top: 8,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 14, color: Color(0xFF007AFF)),
                    SizedBox(width: 4),
                    Text(
                      '閉じる',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF007AFF),
                        fontFamily: 'Hiragino Sans',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
