import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 多機能ボタン（… のメニュー）アイコン候補比較ラボ
class MultiActionIconLabScreen extends StatelessWidget {
  const MultiActionIconLabScreen({super.key});

  static const _candidates = <(IconData, String)>[
    (CupertinoIcons.ellipsis_circle, 'ellipsis_circle（現在）'),
    (CupertinoIcons.ellipsis_circle_fill, 'ellipsis_circle_fill'),
    (CupertinoIcons.ellipsis, 'ellipsis（…）'),
    (Icons.more_horiz, 'more_horiz（…）'),
    (Icons.more_vert, 'more_vert（⋮）'),
    (Icons.menu, 'menu（≡）'),
    (CupertinoIcons.line_horizontal_3, 'line_horizontal_3'),
    (CupertinoIcons.bars, 'bars（≡）'),
    (CupertinoIcons.square_grid_2x2, 'square_grid_2x2'),
    (CupertinoIcons.square_grid_2x2_fill, 'square_grid_2x2_fill'),
    (CupertinoIcons.square_grid_3x2, 'square_grid_3x2'),
    (CupertinoIcons.rectangle_grid_2x2, 'rectangle_grid_2x2'),
    (Icons.apps, 'apps（▦）'),
    (Icons.dashboard_outlined, 'dashboard_outlined'),
    (Icons.dashboard, 'dashboard'),
    (Icons.view_module_outlined, 'view_module_outlined'),
    (Icons.widgets_outlined, 'widgets_outlined'),
    (CupertinoIcons.list_bullet, 'list_bullet'),
    (CupertinoIcons.list_dash, 'list_dash'),
    (CupertinoIcons.text_alignleft, 'text_alignleft'),
    (CupertinoIcons.chevron_compact_down, 'chevron_compact_down'),
    (Icons.expand_circle_down_outlined, 'expand_circle_down_outlined'),
    (Icons.tune, 'tune（スライダー）'),
    (CupertinoIcons.slider_horizontal_3, 'slider_horizontal_3'),
    (CupertinoIcons.ellipses_bubble, 'ellipses_bubble（吹き出し）'),
    (CupertinoIcons.wand_stars, 'wand_stars（魔法の杖）'),
    (CupertinoIcons.square_stack_3d_up, 'square_stack_3d_up'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('多機能アイコンラボ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _candidates.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final (icon, label) = _candidates[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // 実際の使用サイズ（20pt、グレー）— 機能バーでの見え方
                Icon(icon, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 16),
                // 大きめプレビュー（比較用）
                Icon(icon, size: 32, color: Colors.grey[600]),
                const SizedBox(width: 16),
                // ラベル
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13),
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
