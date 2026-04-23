import 'dart:ui';

import 'package:flutter/material.dart';

/// 軽い完了通知用の自前トースト。
/// Scaffold 不依存で、キーボード上でも見える。
/// 画面中央に半透明バーをふわっと表示し、指定時間後に自動消滅。
///
/// 使い分け:
/// - 完了通知・軽い状態変化 → 本関数 (showToast)
/// - ユーザーの行動を止める警告 → showFrostedAlert
void showToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1500),
  /// 画面高に対する上からの比率 (0.0〜1.0)。省略時は 0.38（やや上寄り中央）
  double topFraction = 0.38,
  /// 絶対ピクセルでの上端位置。指定時は topFraction を無視
  double? topPx,
  /// トースト下端の絶対 Y 座標（画面 top 基準）。指定時は上端系を無視して下端を合わせる
  double? bottomY,
  /// 背景色。省略時はすりガラス黒
  Color? backgroundColor,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) {
    final screenH = MediaQuery.of(ctx).size.height;
    final double? topValue =
        bottomY != null ? null : (topPx ?? screenH * topFraction);
    final double? bottomValue =
        bottomY != null ? (screenH - bottomY) : null;
    return Positioned(
      top: topValue,
      bottom: bottomValue,
      left: 40,
      right: 40,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (_, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: backgroundColor ??
                          Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  });
  overlay.insert(entry);
  Future.delayed(duration, () {
    try {
      entry.remove();
    } catch (_) {}
  });
}
