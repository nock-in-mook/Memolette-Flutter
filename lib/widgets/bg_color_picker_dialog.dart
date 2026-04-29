import 'package:flutter/material.dart';

import '../constants/memo_bg_colors.dart';

/// 背景色選択ダイアログ（メモ・ToDoリスト共通）
/// 8×4 パレット（31色 + 色なし）/ 色名 / サンプルパネル / 決定・キャンセル
/// 戻り値: 選択された index（キャンセル時は null）
class BgColorPickerDialog extends StatefulWidget {
  final int current;
  const BgColorPickerDialog({super.key, required this.current});

  @override
  State<BgColorPickerDialog> createState() => _BgColorPickerDialogState();
}

class _BgColorPickerDialogState extends State<BgColorPickerDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final sampleBg =
        _selected == 0 ? Colors.white : MemoBgColors.getColor(_selected);
    final name = MemoBgColors.getName(_selected);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('背景色',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 32,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                mainAxisExtent: 30,
              ),
              itemBuilder: (_, i) {
                final isNone = i == MemoBgColors.count;
                final index = isNone ? 0 : i + 1;
                final isSelected = index == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isNone
                          ? Colors.white
                          : MemoBgColors.getColor(index),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : (isNone
                                ? Colors.grey.shade300
                                : Colors.transparent),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isNone
                        ? Icon(Icons.block,
                            size: 14, color: Colors.grey[500])
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: sampleBg,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.grey.shade300, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'サンプル',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      foregroundColor: Colors.grey.shade700,
                      backgroundColor: Colors.grey.shade100,
                    ),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF007AFF),
                    ),
                    child: const Text('決定',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
