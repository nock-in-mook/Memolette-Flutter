import 'package:flutter/material.dart';

/// Memolette オリジナルダイアログ群の共通スタイル定数。
/// 全ダイアログで参照することで「太さ・グレー濃度・サイズ」を一箇所で
/// 調整可能にする。個別箇所で TextStyle を直書きしないこと。
class DialogStyles {
  DialogStyles._();

  /// ダイアログ内の本文・キャンセルボタン等で使う「濃いめのグレー」
  static const Color textGrey = Color(0xCC3C3C43);

  /// 補足テキストや placeholder 等で使う「薄めのグレー」
  static const Color textGreyLight = Color(0x99999999);

  /// タイトル: 中央配置・太字
  static const TextStyle title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontFamily: 'Hiragino Sans',
  );

  /// 本文（メッセージ）
  static const TextStyle message = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFamily: 'Hiragino Sans',
    color: textGrey,
  );

  /// アクションボタン（OK / 削除する 等）共通の太さとサイズ
  static const TextStyle actionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFamily: 'Hiragino Sans',
  );

  /// ダイアログ全体: 白背景・角丸・影
  static BoxDecoration get bodyDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// アクションボタンの背景（accent 色を 0.1 alpha で）
  static BoxDecoration accentButtonDecoration(Color accent) => BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      );

  /// 行動色（destructive=赤 / default=青）
  static const Color destructive = Colors.red;
  static const Color defaultAction = Color(0xFF007AFF);
}
