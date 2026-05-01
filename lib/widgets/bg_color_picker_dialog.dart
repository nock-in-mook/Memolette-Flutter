import 'package:flutter/material.dart';

import '../constants/memo_bg_colors.dart';
import '../utils/safe_dialog.dart';
import 'dialog_styles.dart';

/// 背景色選択ダイアログ（メモ・ToDoリスト共通・Memolette オリジナルデザイン）
/// 8×4 パレット（31色 + 色なし）/ 色名 / サンプルパネル / キャンセル・決定
///
/// 戻り値: 選択された index（キャンセル / barrier タップ時は null）
Future<int?> showBgColorPickerDialog({
  required BuildContext context,
  required int current,
}) async {
  return focusSafe(
    context,
    () => showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: DialogStyles.bodyDecoration,
                child: _BgColorPickerContent(current: current),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _BgColorPickerContent extends StatefulWidget {
  final int current;
  const _BgColorPickerContent({required this.current});

  @override
  State<_BgColorPickerContent> createState() => _BgColorPickerContentState();
}

class _BgColorPickerContentState extends State<_BgColorPickerContent> {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '背景色',
          textAlign: TextAlign.center,
          style: DialogStyles.title,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              name,
              style: DialogStyles.message.copyWith(fontSize: 12),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 6),
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
                    ? Icon(Icons.block, size: 14, color: Colors.grey[500])
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: sampleBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'サンプル',
              style: DialogStyles.message,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration:
                      DialogStyles.accentButtonDecoration(DialogStyles.textGrey),
                  alignment: Alignment.center,
                  child: Text(
                    'キャンセル',
                    style: DialogStyles.actionLabel
                        .copyWith(color: DialogStyles.textGrey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(_selected),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: DialogStyles.accentButtonDecoration(
                      DialogStyles.defaultAction),
                  alignment: Alignment.center,
                  child: Text(
                    '決定',
                    style: DialogStyles.actionLabel
                        .copyWith(color: DialogStyles.defaultAction),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
