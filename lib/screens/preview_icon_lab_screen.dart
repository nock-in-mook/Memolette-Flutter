import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// プレビューアイコンラボ
/// メモ入力ツールバーの「プレビュー」ボタンに使う候補を一覧で比較する。
/// 各行: 左に ON 状態（オレンジ塗り）、右に OFF 状態（白+グレー枠）、その先に名前。
class PreviewIconLabScreen extends StatelessWidget {
  const PreviewIconLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final candidates = <(IconData, String)>[
      (Icons.preview, 'Icons.preview'),
      (Icons.visibility_outlined, 'Icons.visibility_outlined'),
      (Icons.visibility, 'Icons.visibility'),
      (Icons.remove_red_eye_outlined, 'Icons.remove_red_eye_outlined'),
      (Icons.remove_red_eye, 'Icons.remove_red_eye'),
      (Icons.article_outlined, 'Icons.article_outlined'),
      (Icons.description_outlined, 'Icons.description_outlined'),
      (Icons.subject, 'Icons.subject'),
      (Icons.text_snippet_outlined, 'Icons.text_snippet_outlined'),
      (Icons.menu_book_outlined, 'Icons.menu_book_outlined'),
      (CupertinoIcons.eye, 'CupertinoIcons.eye'),
      (CupertinoIcons.eye_fill, 'CupertinoIcons.eye_fill'),
      (CupertinoIcons.doc_text, 'CupertinoIcons.doc_text'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('プレビューアイコンラボ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: candidates.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(0x22000000)),
        itemBuilder: (_, i) {
          final (icon, name) = candidates[i];
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // ON 状態プレビュー（現行ボタンと同じ見た目）
                _PreviewButtonPreview(icon: icon, isOn: true),
                const SizedBox(width: 10),
                // OFF 状態プレビュー
                _PreviewButtonPreview(icon: icon, isOn: false),
                const SizedBox(width: 14),
                // 名前
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreviewButtonPreview extends StatelessWidget {
  final IconData icon;
  final bool isOn;
  const _PreviewButtonPreview({required this.icon, required this.isOn});

  @override
  Widget build(BuildContext context) {
    final accent = Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isOn ? accent : Colors.grey.shade500, width: 1),
        color: isOn ? accent : Colors.white,
      ),
      child: Icon(
        icon,
        size: 18,
        color: isOn ? Colors.white : Colors.grey.shade500,
      ),
    );
  }
}
