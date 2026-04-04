import 'package:flutter/material.dart';

// ========================================
// 角丸定数
// ========================================
class CornerRadius {
  static const double card = 10.0;
  static const double button = 8.0;
  static const double parentTag = 6.0;
  static const double childTag = 5.0;
  static const double badge = 4.0;
  static const double dialog = 16.0;
}

// ========================================
// シャドウ定数
// ========================================
class AppShadows {
  static BoxShadow light() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 2,
        offset: const Offset(0, 1),
      );

  static BoxShadow medium() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 6,
        offset: const Offset(0, 2),
      );

  static BoxShadow card() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 3,
        offset: const Offset(0, 1),
      );

  static BoxShadow dialog() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 10,
        offset: const Offset(0, 4),
      );

  static BoxShadow heavy() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );
}

// ========================================
// 72色タグカラーパレット（Swift版完全移植）
// ========================================
class TagColors {
  // 特殊タブカラー
  static const Color allTabColor = Color.fromRGBO(250, 245, 209, 1); // 0.98, 0.96, 0.82
  static const Color frequentTabColor = Color.fromRGBO(217, 237, 250, 1); // 0.85, 0.93, 0.98

  // 子タグボーダー色（半透明白）
  static const Color childTagBorder = Color.fromRGBO(255, 255, 255, 0.3);

  static const List<Color> palette = [
    // 0: ノーカラー
    Color.fromRGBO(209, 204, 194, 1),
    // 1-7: ベーシックカラー（明るい）
    Color.fromRGBO(140, 204, 242, 1), // アクア
    Color.fromRGBO(242, 179, 140, 1), // みかん
    Color.fromRGBO(179, 230, 179, 1), // ピスタチオ
    Color.fromRGBO(230, 179, 230, 1), // すみれ
    Color.fromRGBO(242, 217, 140, 1), // レモン
    Color.fromRGBO(242, 153, 153, 1), // ストロベリー
    Color.fromRGBO(153, 191, 242, 1), // コバルト
    // 8-14: パステル
    Color.fromRGBO(204, 235, 250, 1), // シャボン
    Color.fromRGBO(250, 217, 204, 1), // ピーチ
    Color.fromRGBO(217, 242, 217, 1), // ミント
    Color.fromRGBO(242, 217, 242, 1), // ラベンダー
    Color.fromRGBO(250, 242, 204, 1), // バニラ
    Color.fromRGBO(250, 209, 209, 1), // サーモン
    Color.fromRGBO(209, 224, 250, 1), // あじさい
    // 15-21: ディープ
    Color.fromRGBO(89, 166, 204, 1),  // ティール
    Color.fromRGBO(217, 153, 115, 1), // テラコッタ
    Color.fromRGBO(102, 179, 128, 1), // フォレスト
    Color.fromRGBO(191, 148, 199, 1), // プラム
    Color.fromRGBO(204, 179, 102, 1), // マスタード
    Color.fromRGBO(209, 133, 133, 1), // ガーネット
    Color.fromRGBO(133, 158, 217, 1), // インディゴ
    // 22-28: アクセント
    Color.fromRGBO(128, 217, 204, 1), // ターコイズ
    Color.fromRGBO(242, 140, 102, 1), // コーラル
    Color.fromRGBO(153, 209, 140, 1), // ライム
    Color.fromRGBO(191, 140, 217, 1), // アメジスト
    Color.fromRGBO(230, 204, 128, 1), // ゴールド
    Color.fromRGBO(224, 140, 158, 1), // ローズ
    Color.fromRGBO(128, 166, 217, 1), // ブルーベリー
    // 29-35: ナチュラル
    Color.fromRGBO(217, 199, 173, 1), // サンド
    Color.fromRGBO(184, 209, 191, 1), // セージ
    Color.fromRGBO(199, 184, 166, 1), // モカ
    Color.fromRGBO(224, 217, 199, 1), // アイボリー
    Color.fromRGBO(173, 191, 179, 1), // オリーブ
    Color.fromRGBO(209, 179, 158, 1), // キャメル
    Color.fromRGBO(191, 204, 209, 1), // シルバーレイク
    // 36-42: ビビッド
    Color.fromRGBO(250, 115, 133, 1), // チェリー
    Color.fromRGBO(77, 191, 237, 1),  // ソーダ
    Color.fromRGBO(140, 224, 115, 1), // メロン
    Color.fromRGBO(250, 191, 77, 1),  // マンゴー
    Color.fromRGBO(173, 133, 235, 1), // グレープ
    Color.fromRGBO(250, 107, 77, 1),  // トマト
    Color.fromRGBO(64, 209, 191, 1),  // エメラルド
    // 43-49: ニュアンス（くすみ）
    Color.fromRGBO(191, 173, 184, 1), // モーヴ
    Color.fromRGBO(173, 199, 191, 1), // ユーカリ
    Color.fromRGBO(209, 191, 184, 1), // さくら
    Color.fromRGBO(184, 184, 204, 1), // フォグ
    Color.fromRGBO(199, 204, 173, 1), // カーキ
    Color.fromRGBO(204, 173, 173, 1), // カメオ
    Color.fromRGBO(173, 191, 209, 1), // しずく
    // 50-56: レトロ・クラシック
    Color.fromRGBO(224, 158, 122, 1), // シナモン
    Color.fromRGBO(148, 184, 173, 1), // ヒスイ
    Color.fromRGBO(184, 148, 133, 1), // ココア
    Color.fromRGBO(158, 173, 209, 1), // ウェッジウッド
    Color.fromRGBO(217, 184, 133, 1), // ハニー
    Color.fromRGBO(199, 153, 166, 1), // ボルドー
    Color.fromRGBO(133, 184, 199, 1), // ナイル
    // 57-63: ポップ
    Color.fromRGBO(250, 153, 191, 1), // フラミンゴ
    Color.fromRGBO(115, 209, 242, 1), // アクアマリン
    Color.fromRGBO(191, 235, 115, 1), // キウイ
    Color.fromRGBO(242, 209, 102, 1), // サンフラワー
    Color.fromRGBO(209, 140, 235, 1), // オーキッド
    Color.fromRGBO(235, 133, 115, 1), // パプリカ
    Color.fromRGBO(102, 224, 209, 1), // ラムネ
    // 64-70: スモーキー
    Color.fromRGBO(158, 148, 166, 1), // トワイライト
    Color.fromRGBO(166, 179, 158, 1), // モス
    Color.fromRGBO(184, 158, 148, 1), // クレイ
    Color.fromRGBO(148, 166, 184, 1), // ミスト
    Color.fromRGBO(191, 184, 148, 1), // サンドストーン
    Color.fromRGBO(179, 148, 158, 1), // カシス
    Color.fromRGBO(148, 179, 184, 1), // アイス
    // 71-72: スペシャル
    Color.fromRGBO(235, 224, 184, 1), // シャンパン
    Color.fromRGBO(140, 158, 140, 1), // フォレストミスト
  ];

  // カラー名（日本語）
  static const List<String> colorNames = [
    'ノーカラー',
    'アクア', 'みかん', 'ピスタチオ', 'すみれ', 'レモン', 'ストロベリー', 'コバルト',
    'シャボン', 'ピーチ', 'ミント', 'ラベンダー', 'バニラ', 'サーモン', 'あじさい',
    'ティール', 'テラコッタ', 'フォレスト', 'プラム', 'マスタード', 'ガーネット', 'インディゴ',
    'ターコイズ', 'コーラル', 'ライム', 'アメジスト', 'ゴールド', 'ローズ', 'ブルーベリー',
    'サンド', 'セージ', 'モカ', 'アイボリー', 'オリーブ', 'キャメル', 'シルバーレイク',
    'チェリー', 'ソーダ', 'メロン', 'マンゴー', 'グレープ', 'トマト', 'エメラルド',
    'モーヴ', 'ユーカリ', 'さくら', 'フォグ', 'カーキ', 'カメオ', 'しずく',
    'シナモン', 'ヒスイ', 'ココア', 'ウェッジウッド', 'ハニー', 'ボルドー', 'ナイル',
    'フラミンゴ', 'アクアマリン', 'キウイ', 'サンフラワー', 'オーキッド', 'パプリカ', 'ラムネ',
    'トワイライト', 'モス', 'クレイ', 'ミスト', 'サンドストーン', 'カシス', 'アイス',
    'シャンパン', 'フォレストミスト',
  ];

  /// インデックスからカラーを取得（範囲外はノーカラー）
  static Color getColor(int index) {
    if (index < 0 || index >= palette.length) return palette[0];
    return palette[index];
  }

  /// インデックスからカラー名を取得
  static String getName(int index) {
    if (index < 0 || index >= colorNames.length) return colorNames[0];
    return colorNames[index];
  }
}
