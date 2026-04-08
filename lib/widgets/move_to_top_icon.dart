import 'package:flutter/material.dart';

/// 「複数選択して最上部に移動」用のカスタムアイコン
/// Swift版 MoveToTopIcon を移植: 横に3枚カード + 上向き矢印
class MoveToTopIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MoveToTopIcon({
    super.key,
    this.size = 20,
    this.color = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MoveToTopPainter(color: color),
    );
  }
}

class _MoveToTopPainter extends CustomPainter {
  final Color color;

  _MoveToTopPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // カード3枚（下半分に横並び）
    final c1 = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.02, h * 0.5, w * 0.28, h * 0.4),
        const Radius.circular(2));
    final c2 = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.35, h * 0.5, w * 0.28, h * 0.4),
        const Radius.circular(2));
    final c3 = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.68, h * 0.5, w * 0.28, h * 0.4),
        const Radius.circular(2));

    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRRect(c1, paint..color = color.withValues(alpha: 0.35));
    canvas.drawRRect(c2, paint..color = color.withValues(alpha: 0.45));
    canvas.drawRRect(c3, paint..color = color.withValues(alpha: 0.25));

    // 上矢印（三角頭 + 短いシャフト）
    final ax = w * 0.5;
    final ay = h * 0.02;
    final arrow = Path()
      ..moveTo(ax, ay)
      ..lineTo(ax - w * 0.2, ay + h * 0.25)
      ..lineTo(ax + w * 0.2, ay + h * 0.25)
      ..close();
    canvas.drawPath(arrow, paint..color = color.withValues(alpha: 0.45));

    final shaft = Rect.fromLTWH(
        ax - w * 0.06, ay + h * 0.22, w * 0.12, h * 0.2);
    canvas.drawRect(shaft, paint..color = color.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(_MoveToTopPainter oldDelegate) =>
      oldDelegate.color != color;
}
