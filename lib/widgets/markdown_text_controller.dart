import 'package:flutter/material.dart';

/// Bear風マークダウンインラインプレビュー付きTextEditingController。
/// 編集中にリアルタイムで記号を薄くし、見出し/太字/斜体等を反映する。
class MarkdownTextController extends TextEditingController {
  MarkdownTextController({super.text});

  // 記号のスタイル（薄グレー）
  static const _symbolColor = Color(0xFFBBBBBB);

  // ベースフォントサイズ
  static const _baseFontSize = 16.0;

  // 見出しサイズ
  static const _h1Size = 24.0;
  static const _h2Size = 20.0;
  static const _h3Size = 18.0;

  // マークダウンモードが有効か
  bool _enabled = false;
  bool get enabled => _enabled;
  set enabled(bool v) {
    if (_enabled != v) {
      _enabled = v;
      notifyListeners();
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // MD無効時は通常表示
    if (!_enabled) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final baseStyle = style ?? const TextStyle(fontSize: _baseFontSize);
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    bool isInCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      final line = lines[i];
      final trimmed = line.trimLeft();

      // コードブロックの開始/終了
      if (trimmed.startsWith('```')) {
        isInCodeBlock = !isInCodeBlock;
        spans.add(TextSpan(
          text: line,
          style: baseStyle.copyWith(
            color: _symbolColor,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ));
        continue;
      }

      // コードブロック内は等幅フォントで表示
      if (isInCodeBlock) {
        spans.add(TextSpan(
          text: line,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: 14,
            color: const Color(0xFF666666),
          ),
        ));
        continue;
      }

      // 水平線（---、***、___）
      final hrTrimmed = trimmed.replaceAll(' ', '');
      if (hrTrimmed.length >= 3 &&
          (hrTrimmed.split('').every((c) => c == '-') ||
           hrTrimmed.split('').every((c) => c == '*') ||
           hrTrimmed.split('').every((c) => c == '_'))) {
        spans.add(TextSpan(
          text: line,
          style: baseStyle.copyWith(color: _symbolColor),
        ));
        continue;
      }

      // 見出し（# ## ###）
      if (trimmed.startsWith('### ')) {
        _addHeadingSpans(spans, line, '### ', _h3Size, baseStyle);
        continue;
      }
      if (trimmed.startsWith('## ')) {
        _addHeadingSpans(spans, line, '## ', _h2Size, baseStyle);
        continue;
      }
      if (trimmed.startsWith('# ')) {
        _addHeadingSpans(spans, line, '# ', _h1Size, baseStyle);
        continue;
      }

      // 引用（> ）
      if (trimmed.startsWith('> ')) {
        final indent = line.length - trimmed.length;
        if (indent > 0) {
          spans.add(TextSpan(text: line.substring(0, indent), style: baseStyle));
        }
        spans.add(TextSpan(
          text: '> ',
          style: baseStyle.copyWith(color: _symbolColor),
        ));
        _addInlineSpans(spans, trimmed.substring(2), baseStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: const Color(0xFF888888),
        ));
        continue;
      }

      // チェックボックス（- [x] / - [ ] ）
      if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
        final indent = line.length - trimmed.length;
        if (indent > 0) {
          spans.add(TextSpan(text: line.substring(0, indent), style: baseStyle));
        }
        spans.add(TextSpan(
          text: trimmed.substring(0, 6),
          style: baseStyle.copyWith(color: _symbolColor),
        ));
        _addInlineSpans(spans, trimmed.substring(6), baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          color: const Color(0xFF999999),
        ));
        continue;
      }
      if (trimmed.startsWith('- [ ] ')) {
        final indent = line.length - trimmed.length;
        if (indent > 0) {
          spans.add(TextSpan(text: line.substring(0, indent), style: baseStyle));
        }
        spans.add(TextSpan(
          text: '- [ ] ',
          style: baseStyle.copyWith(color: _symbolColor),
        ));
        _addInlineSpans(spans, trimmed.substring(6), baseStyle);
        continue;
      }

      // 箇条書き（- ）
      if (trimmed.startsWith('- ')) {
        final indent = line.length - trimmed.length;
        if (indent > 0) {
          spans.add(TextSpan(text: line.substring(0, indent), style: baseStyle));
        }
        spans.add(TextSpan(
          text: '- ',
          style: baseStyle.copyWith(color: _symbolColor),
        ));
        _addInlineSpans(spans, trimmed.substring(2), baseStyle);
        continue;
      }

      // 番号付きリスト（1. 2. etc）
      final numMatch = RegExp(r'^(\d+\.\s)').firstMatch(trimmed);
      if (numMatch != null) {
        final prefix = numMatch.group(1)!;
        final indent = line.length - trimmed.length;
        if (indent > 0) {
          spans.add(TextSpan(text: line.substring(0, indent), style: baseStyle));
        }
        spans.add(TextSpan(
          text: prefix,
          style: baseStyle.copyWith(color: _symbolColor),
        ));
        _addInlineSpans(spans, trimmed.substring(prefix.length), baseStyle);
        continue;
      }

      // 通常行（インライン記法あり）
      _addInlineSpans(spans, line, baseStyle);
    }

    return TextSpan(children: spans);
  }

  /// 見出し行: プレフィックス記号を薄くし、本文を大きく太字に
  void _addHeadingSpans(
    List<InlineSpan> spans,
    String line,
    String prefix,
    double fontSize,
    TextStyle baseStyle,
  ) {
    final indent = line.length - line.trimLeft().length;
    if (indent > 0) {
      spans.add(TextSpan(text: line.substring(0, indent), style: baseStyle));
    }
    spans.add(TextSpan(
      text: prefix,
      style: baseStyle.copyWith(
        color: _symbolColor,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    ));
    spans.add(TextSpan(
      text: line.trimLeft().substring(prefix.length),
      style: baseStyle.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    ));
  }

  /// インライン記法をパースしてスパンを追加
  /// 対応: **太字**, *斜体*, ~~取消線~~, `コード`, [リンク](url)
  void _addInlineSpans(
    List<InlineSpan> spans,
    String text,
    TextStyle baseStyle,
  ) {
    if (text.isEmpty) return;

    // 全インラインパターンをマッチ
    final pattern = RegExp(
      r'(\*\*(.+?)\*\*)'        // 太字
      r'|(\*(.+?)\*)'           // 斜体
      r'|(~~(.+?)~~)'           // 取消線
      r'|(`([^`]+)`)'           // インラインコード
      r'|(\[([^\]]+)\]\([^)]+\))', // リンク
    );

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      // マッチ前のプレーンテキスト
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      if (match.group(1) != null) {
        // **太字**
        spans.add(TextSpan(text: '**', style: baseStyle.copyWith(color: _symbolColor)));
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
        spans.add(TextSpan(text: '**', style: baseStyle.copyWith(color: _symbolColor)));
      } else if (match.group(3) != null) {
        // *斜体*
        spans.add(TextSpan(text: '*', style: baseStyle.copyWith(color: _symbolColor)));
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
        spans.add(TextSpan(text: '*', style: baseStyle.copyWith(color: _symbolColor)));
      } else if (match.group(5) != null) {
        // ~~取消線~~
        spans.add(TextSpan(text: '~~', style: baseStyle.copyWith(color: _symbolColor)));
        spans.add(TextSpan(
          text: match.group(6),
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        ));
        spans.add(TextSpan(text: '~~', style: baseStyle.copyWith(color: _symbolColor)));
      } else if (match.group(7) != null) {
        // `コード`
        spans.add(TextSpan(text: '`', style: baseStyle.copyWith(color: _symbolColor)));
        spans.add(TextSpan(
          text: match.group(8),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: 14,
            color: const Color(0xFF666666),
            backgroundColor: const Color(0xFFF0F0F0),
          ),
        ));
        spans.add(TextSpan(text: '`', style: baseStyle.copyWith(color: _symbolColor)));
      } else if (match.group(9) != null) {
        // [リンク](url) — リンクテキストだけ青く
        final fullMatch = match.group(9)!;
        final linkText = match.group(10)!;
        final rest = fullMatch.substring(linkText.length + 1); // ](url)
        spans.add(TextSpan(text: '[', style: baseStyle.copyWith(color: _symbolColor)));
        spans.add(TextSpan(
          text: linkText,
          style: baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ));
        spans.add(TextSpan(text: rest, style: baseStyle.copyWith(color: _symbolColor)));
      }

      lastEnd = match.end;
    }

    // 残りのプレーンテキスト
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }
  }
}
