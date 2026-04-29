/// テキストが Markdown 記法を含むかを判定する。
/// Swift 版 `containsMarkdown(_:)` に準拠。先頭 500 文字をサンプルにパターン照合。
bool containsMarkdown(String text) {
  if (text.isEmpty) return false;
  final sample = text.length > 500 ? text.substring(0, 500) : text;
  for (final pattern in _patterns) {
    if (pattern.hasMatch(sample)) return true;
  }
  return false;
}

final List<RegExp> _patterns = [
  RegExp(r'^#{1,6} ', multiLine: true),           // 見出し
  RegExp(r'^- ', multiLine: true),                // リスト（-）
  RegExp(r'^\* ', multiLine: true),               // リスト（*）
  RegExp(r'^\d+\. ', multiLine: true),            // 番号付きリスト
  RegExp(r'^> ', multiLine: true),                // 引用
  RegExp(r'\*\*.+\*\*'),                          // 太字
  RegExp(r'\*[^*]+\*'),                           // 斜体
  RegExp(r'~~.+~~'),                              // 取り消し線
  RegExp(r'^(---|\*\*\*|___)$', multiLine: true), // 水平線
  RegExp(r'\[.+\]\(.+\)'),                        // リンク
  RegExp(r'^- \[[ x]\]', multiLine: true),        // チェックボックス
  RegExp(r'`.+`'),                                // インラインコード
];
