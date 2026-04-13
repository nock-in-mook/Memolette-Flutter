import 'dart:math';

import 'package:flutter/material.dart';

/// Swift版 TrapezoidTabShape 移植
/// 角丸台形タブ（ファイルのインデックスタブ風）
///   上部: 丸い角（半径 topRadius）
///   底辺の付け根: 逆カーブで外側に膨らむ（半径 rootRadius）
///
/// SwiftのaddArc(tangent1:tangent2:radius:)を、tan/sin/atan2で算出して再現する。
class TrapezoidTabClipper extends CustomClipper<Path> {
  final double inset;       // 台形の傾き量（小さめ→長方形寄り）— 左右同値の場合に使う
  final double? leftInset;  // 左側だけ個別指定（nullならinsetを使う）
  final double? rightInset; // 右側だけ個別指定（nullならinsetを使う）
  final double topRadius;   // 上部の角丸半径
  final double rootRadius;  // 付け根の逆カーブ半径

  const TrapezoidTabClipper({
    this.inset = 6,
    this.leftInset,
    this.rightInset,
    this.topRadius = 7,
    this.rootRadius = 9,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = topRadius;
    final br = rootRadius;
    final li = leftInset ?? inset;   // 左側インセット
    final ri = rightInset ?? inset;  // 右側インセット

    final path = Path();

    if (li == 0) {
      // 左辺が垂直 → 付け根カーブ不要、左上角丸のみ
      path.moveTo(0, h);
      var current = const Offset(0, 0);
      path.lineTo(0, r);
      // 左上角丸（垂直→水平）
      current = _arcTangent(path, Offset(0, r),
          const Offset(0, 0), Offset(w - ri, 0), r);
      // 右上角丸
      current = _arcTangent(path, current,
          Offset(w - ri, 0), Offset(w, h), r);
      // 右付け根の逆カーブ
      current = _arcTangent(path, current,
          Offset(w, h), Offset(w + br, h), br);
      path.lineTo(w + br, h);
      path.close();
      return path;
    }

    var current = Offset(-br, h);
    path.moveTo(current.dx, current.dy);

    // 左付け根の逆カーブ
    current = _arcTangent(path, current,
        Offset(0, h), Offset(li, 0), br);

    // 左上角丸
    current = _arcTangent(path, current,
        Offset(li, 0), Offset(w - ri, 0), r);

    // 右上角丸
    current = _arcTangent(path, current,
        Offset(w - ri, 0), Offset(w, h), r);

    // 右付け根の逆カーブ
    current = _arcTangent(path, current,
        Offset(w, h), Offset(w + br, h), br);

    // 右付け根の外側へ
    path.lineTo(w + br, h);

    path.close();
    return path;
  }

  /// SwiftのPath.addArc(tangent1End:tangent2End:radius:) と同等の処理。
  /// current → p1 へ向かう線と、p1 → p2 へ向かう線の両方に接する半径radiusの円弧。
  /// 円弧の開始接点まで lineTo してから arcTo を引く。
  /// 戻り値は終端接点。
  Offset _arcTangent(Path path, Offset current, Offset p1, Offset p2, double radius) {
    final v1 = current - p1;
    final v2 = p2 - p1;
    final l1 = v1.distance;
    final l2 = v2.distance;
    if (l1 == 0 || l2 == 0) {
      path.lineTo(p1.dx, p1.dy);
      return p1;
    }
    final u1 = v1 / l1;
    final u2 = v2 / l2;

    final dot = u1.dx * u2.dx + u1.dy * u2.dy;
    if (dot.abs() >= 0.9999) {
      // ほぼ直線 → 円弧不要
      path.lineTo(p1.dx, p1.dy);
      return p1;
    }
    final theta = acos(dot.clamp(-1.0, 1.0));
    // 接点までの距離 d = r / tan(θ/2)
    final dist = radius / tan(theta / 2);

    // 接点1: p1 から u1 方向に dist
    final t1 = p1 + u1 * dist;
    // 接点2: p1 から u2 方向に dist
    final t2 = p1 + u2 * dist;

    // 円の中心: 二等分線方向に r/sin(θ/2)
    final bis = u1 + u2;
    final blen = bis.distance;
    final bisU = bis / blen;
    final centerDist = radius / sin(theta / 2);
    final center = p1 + bisU * centerDist;

    // 開始角・終了角を計算し、短い方の弧で描画
    final startAngle = atan2(t1.dy - center.dy, t1.dx - center.dx);
    final endAngle = atan2(t2.dy - center.dy, t2.dx - center.dx);
    var sweep = endAngle - startAngle;
    if (sweep > pi) sweep -= 2 * pi;
    if (sweep < -pi) sweep += 2 * pi;

    path.lineTo(t1.dx, t1.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
    );
    return t2;
  }

  @override
  bool shouldReclip(covariant TrapezoidTabClipper old) =>
      old.inset != inset ||
      old.leftInset != leftInset ||
      old.rightInset != rightInset ||
      old.topRadius != topRadius ||
      old.rootRadius != rootRadius;
}

/// CustomPainterで描画する版（fill＋影）
class TrapezoidTabPainter extends CustomPainter {
  final Color color;
  final double inset;
  final double? leftInset;
  final double? rightInset;
  final double topRadius;
  final double rootRadius;
  final List<Shadow> shadows;

  const TrapezoidTabPainter({
    required this.color,
    this.inset = 6,
    this.leftInset,
    this.rightInset,
    this.topRadius = 7,
    this.rootRadius = 9,
    this.shadows = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = TrapezoidTabClipper(
      inset: inset,
      leftInset: leftInset,
      rightInset: rightInset,
      topRadius: topRadius,
      rootRadius: rootRadius,
    );
    final path = clipper.getClip(size);

    // 影
    for (final shadow in shadows) {
      final shadowPaint = Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius);
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }

    // 本体
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant TrapezoidTabPainter old) =>
      old.color != color ||
      old.inset != inset ||
      old.leftInset != leftInset ||
      old.rightInset != rightInset ||
      old.topRadius != topRadius ||
      old.rootRadius != rootRadius;
}
