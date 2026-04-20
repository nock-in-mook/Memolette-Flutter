import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Undo/Redo アイコンラボ
/// フッターツールバーの Undo/Redo ボタンに使う候補ペアを比較する
class UndoRedoIconLabScreen extends StatelessWidget {
  const UndoRedoIconLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // (undoIcon, redoIcon, 名前)
    final pairs = <(IconData, IconData, String)>[
      (Icons.undo, Icons.redo, 'Icons.undo / redo (現行)'),
      (Icons.undo_outlined, Icons.redo_outlined, 'Icons.undo / redo outlined'),
      (
        CupertinoIcons.arrow_uturn_left,
        CupertinoIcons.arrow_uturn_right,
        'CupertinoIcons.arrow_uturn_left / right',
      ),
      (
        CupertinoIcons.arrow_uturn_left_circle,
        CupertinoIcons.arrow_uturn_right_circle,
        'CupertinoIcons.arrow_uturn_*_circle',
      ),
      (
        CupertinoIcons.gobackward,
        CupertinoIcons.goforward,
        'CupertinoIcons.gobackward / goforward',
      ),
      (
        CupertinoIcons.arrow_counterclockwise,
        CupertinoIcons.arrow_clockwise,
        'CupertinoIcons.arrow_counter / clockwise',
      ),
      (
        CupertinoIcons.reply,
        CupertinoIcons.arrowshape_turn_up_right,
        'CupertinoIcons.reply / arrowshape_turn_up_right',
      ),
      (
        CupertinoIcons.chevron_left,
        CupertinoIcons.chevron_right,
        'CupertinoIcons.chevron (参考)',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Undo/Redo アイコンラボ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pairs.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(0x22000000)),
        itemBuilder: (_, i) {
          final (undo, redo, name) = pairs[i];
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // 実寸 (size: 22, weight 700) ペア
                    _IconSample(
                        label: 'undo', icon: undo, size: 22, weight: 700),
                    const SizedBox(width: 20),
                    _IconSample(
                        label: 'redo', icon: redo, size: 22, weight: 700),
                    const SizedBox(width: 28),
                    // 大サイズ
                    _IconSample(label: '', icon: undo, size: 36, weight: 500),
                    const SizedBox(width: 8),
                    _IconSample(label: '', icon: redo, size: 36, weight: 500),
                    const SizedBox(width: 16),
                    // 無効風 (グレー)
                    _IconSample(
                        label: 'off',
                        icon: undo,
                        size: 22,
                        weight: 500,
                        color: Colors.grey.shade400),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IconSample extends StatelessWidget {
  final String label;
  final IconData icon;
  final double size;
  final double weight;
  final Color? color;

  const _IconSample({
    required this.label,
    required this.icon,
    required this.size,
    required this.weight,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: size,
          weight: weight,
          color: color ?? const Color(0xFF007AFF),
        ),
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Colors.black45, height: 1)),
          ),
      ],
    );
  }
}
