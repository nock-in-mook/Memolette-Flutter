import 'package:flutter/material.dart';

/// ダイアログ/モーダル閉時の自動フォーカス復元を防ぐヘルパー。
///
/// Navigator は Route を pop する瞬間に直前の FocusNode を自動復元するため、
/// TextField にフォーカスがあった状態でモーダルを開いてキャンセルすると、
/// キーボードが勝手に再表示される。
/// 本ヘルパーは開閉前後で unfocus を呼び、その挙動を防ぐ。
///
/// 使い方:
/// ```dart
/// final result = await focusSafe(
///   context,
///   () => showGeneralDialog<String>(context: context, ...),
/// );
/// ```
Future<T?> focusSafe<T>(
  BuildContext context,
  Future<T?> Function() show,
) async {
  FocusScope.of(context).unfocus();
  final result = await show();
  if (context.mounted) {
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) FocusScope.of(context).unfocus();
    });
  }
  return result;
}
