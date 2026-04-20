import 'package:flutter/widgets.dart';

/// iPad / タブレット対応のレスポンシブ helper。
/// Step A の土台。Step B（スプリットビュー）や Step C（サイドバー等）でも使う。
class Responsive {
  Responsive._();

  /// shortestSide >= 600 でタブレット判定（Material / Apple の定番基準）。
  /// デバイス種別ベースなので、Split View で画面幅が縮んでも true のまま。
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  /// 画面幅ベースの「広いレイアウト」判定。
  /// Split View / Slide Over 中は iPad でも狭くなるので、
  /// スプリットビュー等は isTablet ではなくこちらを主軸に使う。
  /// 「横向き（width > height）」を条件に含める: iPad Pro 13 は縦画面でも
  /// width=1024 あり、条件なしだと縦画面で誤発動するため。
  static bool isWide(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= 840 && size.width > size.height;
  }

  /// コンテンツを中央寄せするときの最大幅。
  /// 960 にしているのは、iPhone Pro Max の横幅（430〜440pt）の約2倍で、
  /// iPad 縦画面（820〜1024pt）でも左右に適度な余白が残るため。
  static const double contentMaxWidth = 960;
}
