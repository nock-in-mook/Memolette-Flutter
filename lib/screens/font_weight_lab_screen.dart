import 'package:flutter/material.dart';

/// フォントウェイトラボ: タイトル・本文のFontWeightを100刻みで比較
class FontWeightLabScreen extends StatelessWidget {
  const FontWeightLabScreen({super.key});

  static const _weights = [
    (FontWeight.w100, 'w100 Thin'),
    (FontWeight.w200, 'w200 ExtraLight'),
    (FontWeight.w300, 'w300 Light'),
    (FontWeight.w400, 'w400 Regular'),
    (FontWeight.w500, 'w500 Medium'),
    (FontWeight.w600, 'w600 SemiBold'),
    (FontWeight.w700, 'w700 Bold'),
    (FontWeight.w800, 'w800 ExtraBold'),
    (FontWeight.w900, 'w900 Black'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('フォントウェイトラボ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _weights.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final (weight, label) = _weights[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color.fromRGBO(142, 142, 147, 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ラベル
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                // タイトルプレビュー
                Text(
                  '買い物リスト（タイトル）',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: weight,
                    fontFamily: 'PingFang JP',
                    color: Colors.black87,
                  ),
                ),
                const Divider(height: 12),
                // 本文プレビュー
                Text(
                  '牛乳、卵、パン、バター、りんご\n明日の朝ごはんの材料を忘れずに買う',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: weight,
                    fontFamily: 'PingFang JP',
                    color: Colors.black87,
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
