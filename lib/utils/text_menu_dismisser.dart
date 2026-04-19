import 'package:flutter/material.dart';

/// TextField のコンテキストメニュー（コピー/ペースト等のポップアップ）が
/// 一度表示されたあとタップしても消えない問題への対処ヘルパー。
///
/// 使い方:
/// ```dart
/// TextField(
///   onTap: TextMenuDismisser.wrap(myOriginalOnTap),
///   contextMenuBuilder: TextMenuDismisser.builder,
///   ...
/// )
/// ```
///
/// グローバルに最後にメニューが表示された時刻を覚えておき、
/// それから 300ms 以上経過したタップで `ContextMenuController.removeAny()` を呼んで
/// 表示中のメニューを閉じる。アプリ全体で同時に開けるメニューは1つなので
/// 静的状態で問題ない。
class TextMenuDismisser {
  static DateTime? _lastShown;

  /// 既存の onTap に「残ってるメニューを消す」処理をかぶせて返す
  static GestureTapCallback wrap(GestureTapCallback? original) {
    return () {
      if (_lastShown != null &&
          DateTime.now().difference(_lastShown!) >
              const Duration(milliseconds: 300)) {
        ContextMenuController.removeAny();
        _lastShown = null;
      }
      original?.call();
    };
  }

  /// TextField の contextMenuBuilder にそのまま渡せる
  static Widget builder(
      BuildContext context, EditableTextState editableTextState) {
    _lastShown = DateTime.now();
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }
}
