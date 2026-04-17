import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 最大化アイコンラボ
/// 機能バー右端の最大化ボタンに使う候補を一覧で比較する
class MaximizeIconLabScreen extends StatelessWidget {
  const MaximizeIconLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // (IconData, 名前)
    final candidates = <(IconData, String)>[
      (Icons.zoom_out_map, 'zoom_out_map'),
      (Icons.fullscreen, 'fullscreen'),
      (Icons.open_in_full, 'open_in_full (現行)'),
      (Icons.open_with, 'open_with'),
      (Icons.fit_screen, 'fit_screen'),
      (Icons.fit_screen_outlined, 'fit_screen_outlined'),
      (Icons.crop_free, 'crop_free'),
      (Icons.aspect_ratio, 'aspect_ratio'),
      (Icons.center_focus_strong, 'center_focus_strong'),
      (Icons.center_focus_weak, 'center_focus_weak'),
      (Icons.settings_overscan, 'settings_overscan'),
      (Icons.unfold_more, 'unfold_more'),
      (Icons.expand, 'expand'),
      (Icons.keyboard_double_arrow_down, 'keyboard_double_arrow_down'),
      (CupertinoIcons.fullscreen, 'CupertinoIcons.fullscreen'),
      (CupertinoIcons.arrow_up_left_arrow_down_right,
          'CupertinoIcons.arrow_up_left_arrow_down_right'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('最大化アイコンラボ'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 機能バー実寸プレビュー（44x44枠 + アイコン22）
                SizedBox(
                  width: 56,
                  height: 44,
                  child: Center(
                    child: Icon(icon, size: 22, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                // 大サイズ（36）プレビュー
                Icon(icon, size: 36, color: Colors.black),
                const SizedBox(width: 16),
                // 名前
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
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
