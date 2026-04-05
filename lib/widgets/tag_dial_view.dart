import 'dart:math';

import 'package:flutter/material.dart';

/// タグルーレット（扇形ダイヤル）— Swift版 TagDialView の移植
/// 2つの同心円リング: 外側=親タグ, 内側=子タグ
class TagDialView extends StatefulWidget {
  final double height;
  final List<TagDialOption> parentOptions;
  final List<TagDialOption> childOptions;
  final String? selectedParentId;
  final String? selectedChildId;
  final bool isOpen;
  final void Function(String? id) onParentSelected;
  final void Function(String? id) onChildSelected;

  const TagDialView({
    super.key,
    this.height = 211,
    required this.parentOptions,
    this.childOptions = const [],
    this.selectedParentId,
    this.selectedChildId,
    this.isOpen = true,
    required this.onParentSelected,
    required this.onChildSelected,
  });

  @override
  State<TagDialView> createState() => _TagDialViewState();
}

class _TagDialViewState extends State<TagDialView>
    with TickerProviderStateMixin {
  // ジオメトリ定数（Swift版準拠）
  static const double parentInnerR = 240;
  static const double childInnerR = 130;
  static const double itemAngle = 8.0; // 度

  // 回転状態
  double _parentRotation = 0;
  double _childRotation = 0;
  bool _parentDragging = false;
  bool _childDragging = false;
  bool _parentSettling = false;
  bool _childSettling = false;

  @override
  void initState() {
    super.initState();
    // 選択中タグの位置にスナップ
    _syncToSelection();
  }

  @override
  void didUpdateWidget(covariant TagDialView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedParentId != widget.selectedParentId ||
        oldWidget.selectedChildId != widget.selectedChildId) {
      _syncToSelection();
    }
  }

  void _syncToSelection() {
    if (widget.selectedParentId != null) {
      final idx = widget.parentOptions
          .indexWhere((o) => o.id == widget.selectedParentId);
      if (idx >= 0 && !_parentDragging && !_parentSettling) {
        _parentRotation = idx * itemAngle;
      }
    }
    if (widget.selectedChildId != null) {
      final idx = widget.childOptions
          .indexWhere((o) => o.id == widget.selectedChildId);
      if (idx >= 0 && !_childDragging && !_childSettling) {
        _childRotation = idx * itemAngle;
      }
    }
  }

  int _snappedIndex(double rotation, int count) {
    final raw = (rotation / itemAngle).round();
    return raw.clamp(0, max(0, count - 1));
  }

  // 実際の回転値（制限なし）— ラバーバンドの元値
  double _parentRawRotation = 0;
  double _childRawRotation = 0;

  /// ラバーバンド適用: 範囲外を引っ張れるが抵抗がある
  /// セクター1.5個分（12度）くらいまで伸びて頭打ちになる
  double _applyRubberBand(double raw, double maxRot) {
    const maxStretch = 12.0; // 最大伸び（度）
    if (raw < 0) {
      final excess = -raw;
      // 対数的に抵抗が増す（引っ張るほど重くなる）
      final stretched = maxStretch * (1 - exp(-excess / 20));
      return -stretched;
    } else if (raw > maxRot) {
      final excess = raw - maxRot;
      final stretched = maxStretch * (1 - exp(-excess / 20));
      return maxRot + stretched;
    }
    return raw;
  }

  void _onDragUpdate(DragUpdateDetails details, bool isChild) {
    setState(() {
      final delta = details.delta.dy * -0.3;
      if (isChild) {
        _childDragging = true;
        _childRawRotation += delta;
        final maxRot = max(0.0, (widget.childOptions.length - 1) * itemAngle);
        _childRotation = _applyRubberBand(_childRawRotation, maxRot);
      } else {
        _parentDragging = true;
        _parentRawRotation += delta;
        final maxRot =
            max(0.0, (widget.parentOptions.length - 1) * itemAngle);
        _parentRotation = _applyRubberBand(_parentRawRotation, maxRot);
      }
    });
  }

  void _onDragEnd(DragEndDetails details, bool isChild) {
    if (isChild) {
      _childDragging = false;
      _childSettling = true;
      final maxRot =
          max(0.0, (widget.childOptions.length - 1) * itemAngle);
      // rawが範囲外ならclampしてからスナップ計算
      final clamped = _childRawRotation.clamp(0.0, maxRot);
      final target =
          ((clamped / itemAngle).round() * itemAngle).clamp(0.0, maxRot);
      _childRawRotation = target;
      _animateTo(target, isChild: true);
    } else {
      _parentDragging = false;
      _parentSettling = true;
      final maxRot =
          max(0.0, (widget.parentOptions.length - 1) * itemAngle);
      final clamped = _parentRawRotation.clamp(0.0, maxRot);
      final target =
          ((clamped / itemAngle).round() * itemAngle).clamp(0.0, maxRot);
      _parentRawRotation = target;
      _animateTo(target, isChild: false);
    }
  }

  /// バウンスアニメーションでスナップ
  void _animateTo(double target, {required bool isChild}) {
    final from = isChild ? _childRotation : _parentRotation;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    final animation = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );
    animation.addListener(() {
      setState(() {
        if (isChild) {
          _childRotation = animation.value;
        } else {
          _parentRotation = animation.value;
        }
      });
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        // 選択通知
        if (isChild) {
          final idx =
              _snappedIndex(_childRotation, widget.childOptions.length);
          if (idx < widget.childOptions.length) {
            widget.onChildSelected(widget.childOptions[idx].id);
          }
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _childSettling = false);
          });
        } else {
          final idx =
              _snappedIndex(_parentRotation, widget.parentOptions.length);
          if (idx < widget.parentOptions.length) {
            widget.onParentSelected(widget.parentOptions[idx].id);
          }
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _parentSettling = false);
          });
        }
      }
    });
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final showChild = widget.childOptions.isNotEmpty;
    final cx = 350.0 + 2; // wheelRadius + 2
    final cy = widget.height / 2;

    // キャンバス幅計算
    final innermost = showChild ? childInnerR : parentInnerR;
    final neededWidth = cx - innermost * cos(30 * pi / 180) + 14;
    final canvasWidth = max(neededWidth, 100.0);

    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (!widget.isOpen) return;
        // タッチX位置で親/子を判定
        final touchX = d.localPosition.dx;
        final borderX = cx - parentInnerR;
        _onDragUpdate(d, showChild && touchX > canvasWidth - borderX);
      },
      onVerticalDragEnd: (d) {
        if (!widget.isOpen) return;
        // 最後のドラッグ対象に対してスナップ
        if (_childDragging) {
          _onDragEnd(d, true);
        } else {
          _onDragEnd(d, false);
        }
      },
      child: ClipRect(
        child: SizedBox(
          width: canvasWidth,
          height: widget.height,
          child: CustomPaint(
            size: Size(canvasWidth, widget.height),
            painter: _TagDialPainter(
              cx: cx,
              cy: cy,
              parentOptions: widget.parentOptions,
              childOptions: showChild ? widget.childOptions : [],
              parentRotation: _parentRotation,
              childRotation: _childRotation,
              isOpen: widget.isOpen,
            ),
          ),
        ),
      ),
    );
  }
}

/// ルーレット描画
class _TagDialPainter extends CustomPainter {
  final double cx;
  final double cy;
  final List<TagDialOption> parentOptions;
  final List<TagDialOption> childOptions;
  final double parentRotation;
  final double childRotation;
  final bool isOpen;

  static const double parentOuterR = 350;
  static const double parentInnerR = 240;
  static const double childOuterR = 240;
  static const double childInnerR = 130;
  static const double itemAngle = 8.0;

  _TagDialPainter({
    required this.cx,
    required this.cy,
    required this.parentOptions,
    required this.childOptions,
    required this.parentRotation,
    required this.childRotation,
    required this.isOpen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 親リング描画
    _drawRing(
      canvas,
      options: parentOptions,
      rotation: parentRotation,
      outerR: parentOuterR,
      innerR: parentInnerR,
      isParent: true,
    );

    // 子リング描画
    if (childOptions.isNotEmpty) {
      _drawRing(
        canvas,
        options: childOptions,
        rotation: childRotation,
        outerR: childOuterR,
        innerR: childInnerR,
        isParent: false,
      );
    }

    // ポインター（選択インジケーター）
    _drawPointer(canvas);

    // リング境界線
    _drawEdgeArc(canvas, parentOuterR, 3.0);
    _drawEdgeArc(canvas, parentInnerR, 1.5);
    if (childOptions.isNotEmpty) {
      _drawEdgeArc(canvas, childInnerR, 1.5);
    }
  }

  void _drawRing(
    Canvas canvas, {
    required List<TagDialOption> options,
    required double rotation,
    required double outerR,
    required double innerR,
    required bool isParent,
  }) {
    final maxFont = isParent ? 20.0 : 14.0;
    final minFont = isParent ? 13.0 : 11.0;

    for (int offset = -12; offset <= 12; offset++) {
      final baseIndex = (rotation / itemAngle).round();
      final rawIndex = baseIndex + offset;
      if (rawIndex < 0 || rawIndex >= options.length) continue;

      final option = options[rawIndex];
      final displayAngle = rawIndex * itemAngle - rotation;
      final distance = displayAngle.abs();

      // フェード計算
      final fade = max(0.0, 1.0 - distance / (itemAngle * 8));
      if (fade <= 0) continue;

      final isSelected = distance < itemAngle / 2;

      // セクター描画
      final startAngle = (180 - displayAngle - itemAngle / 2) * pi / 180;
      final endAngle = (180 - displayAngle + itemAngle / 2) * pi / 180;

      final sectorPath = Path();
      // 内側の弧
      sectorPath.arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
        startAngle,
        endAngle - startAngle,
        false,
      );
      // 外側の弧（逆方向）
      sectorPath.arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
        endAngle,
        startAngle - endAngle,
        false,
      );
      sectorPath.close();

      // 塗りつぶし
      Color fillColor;
      if (!isOpen) {
        fillColor = const Color.fromRGBO(235, 235, 235, 1);
      } else if (option.id == null) {
        fillColor = Colors.white;
      } else {
        fillColor = option.color;
      }

      final fillPaint = Paint()
        ..color = fillColor.withValues(alpha: fade)
        ..style = PaintingStyle.fill;
      canvas.drawPath(sectorPath, fillPaint);

      // 区切り線
      final dividerPaint = Paint()
        ..color = Color.fromRGBO(90, 90, 90, fade * 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final divAngle = (180 - displayAngle - itemAngle / 2) * pi / 180;
      canvas.drawLine(
        Offset(cx + innerR * cos(divAngle), cy + innerR * sin(divAngle)),
        Offset(cx + outerR * cos(divAngle), cy + outerR * sin(divAngle)),
        dividerPaint,
      );

      // テキスト描画
      if (isOpen && fade > 0.3) {
        final midR = (innerR + outerR) / 2;
        final midAngle = (180 - displayAngle) * pi / 180;
        final textX = cx + midR * cos(midAngle);
        final textY = cy + midR * sin(midAngle);

        // フォントサイズ決定
        var fontSize = maxFont;
        if (option.id == null) fontSize = isParent ? 14.0 : 12.0;
        fontSize = fontSize.clamp(minFont, maxFont);

        final textPainter = TextPainter(
          text: TextSpan(
            text: _truncateText(option.name, isParent ? 10 : 7),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: option.id == null
                  ? Color.fromRGBO(140, 140, 140, fade)
                  : Color.fromRGBO(
                      isSelected ? 0 : 64,
                      isSelected ? 0 : 64,
                      isSelected ? 0 : 64,
                      fade,
                    ),
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.layout();

        canvas.save();
        canvas.translate(textX, textY);
        canvas.rotate(-displayAngle * pi / 180);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }
  }

  void _drawPointer(Canvas canvas) {
    // 選択ポインター（左端の三角形）
    final pointerPath = Path();
    final px = cx - parentOuterR - 2;
    final py = cy;
    pointerPath.moveTo(px, py - 8);
    pointerPath.lineTo(px + 12, py);
    pointerPath.lineTo(px, py + 8);
    pointerPath.close();

    final pointerPaint = Paint()
      ..color = isOpen
          ? const Color.fromRGBO(230, 38, 25, 1)
          : const Color.fromRGBO(140, 140, 140, 1)
      ..style = PaintingStyle.fill;

    canvas.drawPath(pointerPath, pointerPaint);

    // ポインターの影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(pointerPath.shift(const Offset(1, 1)), shadowPaint);
    canvas.drawPath(pointerPath, pointerPaint);
  }

  void _drawEdgeArc(Canvas canvas, double radius, double lineWidth) {
    final halfHeight = cy;
    final maxSin = min(1.0, halfHeight / radius);
    final maxAngle = asin(maxSin);

    final edgePaint = Paint()
      ..color = const Color.fromRGBO(90, 90, 90, 0.4)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      pi - maxAngle,
      maxAngle * 2,
      false,
      edgePaint,
    );
  }

  String _truncateText(String text, int maxHalfWidth) {
    int width = 0;
    int endIndex = 0;
    for (int i = 0; i < text.length; i++) {
      final charWidth = text.codeUnitAt(i) < 128 ? 1 : 2;
      if (width + charWidth > maxHalfWidth) {
        return '${text.substring(0, endIndex)}…';
      }
      width += charWidth;
      endIndex = i + 1;
    }
    return text;
  }

  @override
  bool shouldRepaint(covariant _TagDialPainter oldDelegate) {
    return oldDelegate.parentRotation != parentRotation ||
        oldDelegate.childRotation != childRotation ||
        oldDelegate.isOpen != isOpen ||
        oldDelegate.parentOptions != parentOptions ||
        oldDelegate.childOptions != childOptions;
  }
}

/// ルーレットに表示するタグオプション
class TagDialOption {
  final String? id; // nullなら「タグなし」
  final String name;
  final Color color;

  const TagDialOption({
    this.id,
    required this.name,
    required this.color,
  });
}
