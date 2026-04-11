import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 設定アイコンラボ: 候補アイコンを比較
class SettingsIconLabScreen extends StatelessWidget {
  const SettingsIconLabScreen({super.key});

  static const _candidates = <(IconData, String)>[
    (Icons.settings_outlined, 'settings_outlined（現在）'),
    (Icons.settings, 'settings（塗り）'),
    (CupertinoIcons.gear, 'gear（Cupertino）'),
    (CupertinoIcons.gear_alt, 'gear_alt'),
    (CupertinoIcons.gear_big, 'gear_big'),
    (CupertinoIcons.gear_solid, 'gear_solid'),
    (Icons.tune, 'tune（スライダー）'),
    (Icons.tune_outlined, 'tune_outlined'),
    (Icons.more_horiz, 'more_horiz（…）'),
    (Icons.more_vert, 'more_vert（⋮）'),
    (CupertinoIcons.ellipsis, 'ellipsis（…Cupertino）'),
    (CupertinoIcons.slider_horizontal_3, 'slider_horizontal_3'),
    (Icons.menu, 'menu（≡）'),
    (CupertinoIcons.line_horizontal_3, 'line_horizontal_3'),
    (Icons.dashboard_customize_outlined, 'dashboard_customize'),
    (Icons.widgets_outlined, 'widgets_outlined'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('設定アイコンラボ'),
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
                // 実際の使用サイズ（22pt、青）
                Icon(icon, size: 22, color: const Color(0xFF007AFF)),
                const SizedBox(width: 16),
                // 大きめプレビュー（比較用）
                Icon(icon, size: 32, color: const Color(0xFF007AFF)),
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
