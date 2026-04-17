import 'package:flutter/material.dart';

/// メモ背景色パレット（テキスト可読性を保つ薄めパステル31色）
/// index 0 = 色なし（白）、1-31 = パレット色
class MemoBgColors {
  static const int count = 31;

  static const List<({Color color, String name})> palette = [
    (color: Color(0xFFF8C8D0), name: 'ローズ'),
    (color: Color(0xFFFCE0E6), name: 'サクラ'),
    (color: Color(0xFFFCDCD0), name: 'ブラッシュ'),
    (color: Color(0xFFFAB8A8), name: 'コーラル'),
    (color: Color(0xFFFCD0B0), name: 'ピーチ'),
    (color: Color(0xFFF8D2A8), name: 'アプリコット'),
    (color: Color(0xFFF8D890), name: 'ハニー'),
    (color: Color(0xFFFCE8A0), name: 'バター'),
    (color: Color(0xFFF8F0A8), name: 'レモン'),
    (color: Color(0xFFF0E4C0), name: 'シャンパン'),
    (color: Color(0xFFD8E8A0), name: 'マッチャ'),
    (color: Color(0xFFD0E8B8), name: 'ピスタチオ'),
    (color: Color(0xFFC8D8B8), name: 'セージ'),
    (color: Color(0xFFB8E8D0), name: 'ミント'),
    (color: Color(0xFFB8DCC8), name: 'ジェイド'),
    (color: Color(0xFFB8E8D8), name: 'シーフォーム'),
    (color: Color(0xFFB0E0E0), name: 'アクア'),
    (color: Color(0xFFB8DCE8), name: 'スカイ'),
    (color: Color(0xFFC8DCEC), name: 'パウダーブルー'),
    (color: Color(0xFFB0D0EC), name: 'セレスト'),
    (color: Color(0xFFC0C8E8), name: 'ペリウィンクル'),
    (color: Color(0xFFA8C0E8), name: 'アジュール'),
    (color: Color(0xFFC0B8E0), name: 'アイリス'),
    (color: Color(0xFFD0C0E8), name: 'ラベンダー'),
    (color: Color(0xFFD8C0E0), name: 'オーキッド'),
    (color: Color(0xFFE0C8E8), name: 'ライラック'),
    (color: Color(0xFFD8B8C8), name: 'モーヴ'),
    (color: Color(0xFFD0D0D0), name: 'アッシュ'),
    (color: Color(0xFFE0E0E0), name: 'フォグ'),
    (color: Color(0xFFF0F0F0), name: 'パール'),
    (color: Color(0xFFF0EDE8), name: 'ポーセリン'),
  ];

  static Color getColor(int index) {
    if (index <= 0 || index > count) return Colors.white;
    final base = palette[index - 1].color;
    // 少しだけ白に寄せて可読性を上げる
    return Color.lerp(base, Colors.white, 0.18) ?? base;
  }

  static String getName(int index) {
    if (index <= 0 || index > count) return '色なし';
    return palette[index - 1].name;
  }
}
