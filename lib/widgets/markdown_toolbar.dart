import 'package:flutter/material.dart';

/// マークダウン入力補助ツールバー
class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.grey[100],
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _button('H1', () => _insertPrefix('# ')),
          _button('H2', () => _insertPrefix('## ')),
          _button('H3', () => _insertPrefix('### ')),
          _divider(),
          _iconButton(Icons.format_bold, () => _wrapSelection('**')),
          _iconButton(Icons.format_italic, () => _wrapSelection('*')),
          _iconButton(
              Icons.format_strikethrough, () => _wrapSelection('~~')),
          _divider(),
          _iconButton(Icons.format_list_bulleted, () => _insertPrefix('- ')),
          _iconButton(
              Icons.format_list_numbered, () => _insertPrefix('1. ')),
          _iconButton(Icons.check_box_outlined,
              () => _insertPrefix('- [ ] ')),
          _divider(),
          _iconButton(Icons.code, () => _wrapSelection('`')),
          _button('```', () => _insertCodeBlock()),
          _iconButton(Icons.format_quote, () => _insertPrefix('> ')),
          _iconButton(Icons.horizontal_rule, () => _insertText('\n---\n')),
          _iconButton(Icons.link, () => _insertLink()),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Container(width: 1, color: Colors.grey[300]),
    );
  }

  /// 行頭にプレフィックスを挿入
  void _insertPrefix(String prefix) {
    final text = controller.text;
    final sel = controller.selection;
    final pos = sel.baseOffset.clamp(0, text.length);

    // 現在の行の先頭を探す
    int lineStart = text.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    final newText =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    controller.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: pos + prefix.length),
    );
    onChanged();
  }

  /// 選択範囲をラップ
  void _wrapSelection(String wrapper) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);

    if (start == end) {
      // 選択なし: ラッパーだけ挿入してカーソルを間に
      final insert = '$wrapper$wrapper';
      final newText =
          text.substring(0, start) + insert + text.substring(start);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: start + wrapper.length),
      );
    } else {
      final selected = text.substring(start, end);
      final replacement = '$wrapper$selected$wrapper';
      final newText =
          text.substring(0, start) + replacement + text.substring(end);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + wrapper.length,
          extentOffset: end + wrapper.length,
        ),
      );
    }
    onChanged();
  }

  void _insertText(String insert) {
    final text = controller.text;
    final pos = controller.selection.baseOffset.clamp(0, text.length);
    final newText =
        text.substring(0, pos) + insert + text.substring(pos);
    controller.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: pos + insert.length),
    );
    onChanged();
  }

  void _insertCodeBlock() {
    _insertText('\n```\n\n```\n');
    // カーソルをコードブロック内に
    final pos = controller.selection.baseOffset;
    controller.selection =
        TextSelection.collapsed(offset: pos - 5);
  }

  void _insertLink() {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);

    if (start == end) {
      _insertText('[リンクテキスト](url)');
    } else {
      final selected = text.substring(start, end);
      final replacement = '[$selected](url)';
      final newText =
          text.substring(0, start) + replacement + text.substring(end);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + selected.length + 3,
          extentOffset: start + selected.length + 6,
        ),
      );
      onChanged();
    }
  }
}
