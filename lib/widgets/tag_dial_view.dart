import 'dart:math';
import 'dart:ui' as ui;

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

  // ドラッグ開始時に確定したターゲット（途中で切り替えない）
  bool? _dragTargetIsChild;

  @override
  void initState() {
    super.initState();
    // 選択中タグの位置にスナップ
    _syncToSelection();
  }

  @override
  void didUpdateWidget(covariant TagDialView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 選択IDが変わった or オプション数が変わった（タグ追加直後など）にsync
    if (oldWidget.selectedParentId != widget.selectedParentId ||
        oldWidget.selectedChildId != widget.selectedChildId ||
        oldWidget.parentOptions.length != widget.parentOptions.length ||
        oldWidget.childOptions.length != widget.childOptions.length) {
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
    } else {
      // 親タグなし: 0番目（「タグなし」）にアニメーションでリセット。
      // これがないと、×ボタンでタグを消した直後にルーレットを再表示したとき、
      // 親タグの回転位置だけ前回の選択を指したまま残って、子タグ列が
      // 空（_parentTag=null による）になり矛盾した見た目になる。
      if (!_parentDragging && !_parentSettling && _parentRotation != 0) {
        _animateTo(0, isChild: false, notify: false,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic);
      }
    }
    if (widget.selectedChildId != null) {
      final idx = widget.childOptions
          .indexWhere((o) => o.id == widget.selectedChildId);
      if (idx >= 0 && !_childDragging && !_childSettling) {
        _childRotation = idx * itemAngle;
      }
    } else {
      // 子タグなし: 0番目（「子タグなし」）にアニメーションでリセット
      if (!_childDragging && !_childSettling && _childRotation != 0) {
        _animateTo(0, isChild: true, notify: false,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic);
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

  /// タップ位置からセクターを特定してスナップ
  void _onTapAtPosition(Offset pos, double canvasWidth, bool showChild) {
    final cx = 350.0 + 2;
    final cy = widget.height / 2;

    // タッチ位置から中心への角度（atan2）
    final dx = pos.dx - cx;
    final dy = pos.dy - cy;
    var angleRad = atan2(dy, dx); // Canvas座標系: 右=0, 下=pi/2, 左=±pi, 上=-pi/2
    // セクター中央の描画角度 = (180 - displayAngle) * pi / 180
    // 逆算: displayAngle = 180 - angleRad * 180 / pi
    // 上側(dy<0)ではangleRadが-pi近くになり、displayAngleが大きくなりすぎるので
    // angleRadをpi中心（左方向）に正規化
    if (angleRad < 0) angleRad += 2 * pi; // 0〜2piに正規化
    // 左方向(pi)が中心、上はpi+α、下はpi-α
    final displayAngle = (pi - angleRad) * 180 / pi;

    // タッチ位置の中心からの距離（半径）で親/子を判定。
    // 視覚的な境界は半径 parentInnerR の円弧（親の内半径＝子の外半径）。
    // 距離 < parentInnerR なら子エリア、それ以上なら親エリア。
    // ※ 旧実装の「borderX = cx - parentInnerR」の垂直線判定だと、
    //   上下に傾いたセクター（中心軸から離れた親セクター）の内側端付近が
    //   borderX より右側に来てしまい、子タグ判定として吸われていた。
    final dr = sqrt(dx * dx + dy * dy);
    final isChild = showChild && dr < parentInnerR;

    final rotation = isChild ? _childRotation : _parentRotation;
    final options = isChild ? widget.childOptions : widget.parentOptions;
    // displayAngle = rawIndex * itemAngle - rotation
    // rawIndex = (displayAngle + rotation) / itemAngle
    final tappedIndex = ((displayAngle + rotation) / itemAngle).round();

    // 範囲外チェック
    if (tappedIndex < 0 || tappedIndex >= options.length) return;

    // 目標回転角度
    final target = tappedIndex * itemAngle;
    if ((target - rotation).abs() < 0.1) return;

    // rawRotationも更新
    if (isChild) {
      _childRawRotation = target;
      _childSettling = true;
    } else {
      _parentRawRotation = target;
      _parentSettling = true;
    }

    // アニメーション: セクター数に応じた長さ（Swift版準拠: 1タグ6コマ×12ms≒72ms/タグ）
    final sectorCount = ((target - rotation).abs() / itemAngle).round();
    final duration = Duration(milliseconds: max(200, min(600, sectorCount * 60)));
    _animateTo(target, isChild: isChild, duration: duration, curve: Curves.easeInOutCubic);
  }

  /// アニメーションでスナップ
  void _animateTo(double target, {required bool isChild, bool notify = true, Duration? duration, Curve? curve}) {
    final from = isChild ? _childRotation : _parentRotation;
    final controller = AnimationController(
      vsync: this,
      duration: duration ?? const Duration(milliseconds: 250),
    );
    final animation = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: controller, curve: curve ?? Curves.easeOutBack),
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
          if (notify) {
            final idx =
                _snappedIndex(_childRotation, widget.childOptions.length);
            if (idx < widget.childOptions.length) {
              widget.onChildSelected(widget.childOptions[idx].id);
            }
          }
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _childSettling = false);
          });
        } else {
          if (notify) {
            final idx =
                _snappedIndex(_parentRotation, widget.parentOptions.length);
            if (idx < widget.parentOptions.length) {
              widget.onParentSelected(widget.parentOptions[idx].id);
            }
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
      onTapUp: (d) {
        if (!widget.isOpen) return;
        if (_parentDragging || _childDragging) return;
        if (_parentSettling || _childSettling) return;
        _onTapAtPosition(d.localPosition, canvasWidth, showChild);
      },
      onVerticalDragStart: (d) {
        if (!widget.isOpen) return;
        // ドラッグ開始時にターゲットを確定（途中で切り替えない）。
        // 中心からの距離（半径）で親/子を判定（タップと同じロジック）。
        final ddx = d.localPosition.dx - cx;
        final ddy = d.localPosition.dy - cy;
        final dr = sqrt(ddx * ddx + ddy * ddy);
        _dragTargetIsChild = showChild && dr < parentInnerR;
      },
      onVerticalDragUpdate: (d) {
        if (!widget.isOpen || _dragTargetIsChild == null) return;
        _onDragUpdate(d, _dragTargetIsChild!);
      },
      onVerticalDragEnd: (d) {
        if (!widget.isOpen || _dragTargetIsChild == null) return;
        _onDragEnd(d, _dragTargetIsChild!);
        _dragTargetIsChild = null;
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
              canvasWidth: canvasWidth,
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
  final double canvasWidth; // クリップ用の本来の幅
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
    required this.canvasWidth,
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

    // リング境界線（Swift版準拠のグラデーション）
    _drawEdgeArc(canvas, parentOuterR, 3.0, brightness: (0.35, 0.5, 0.35));
    _drawEdgeArc(canvas, parentInnerR, 1.5, brightness: (0.3, 0.45, 0.3));
    if (childOptions.isNotEmpty) {
      _drawEdgeArc(canvas, childInnerR, 1.5, brightness: (0.3, 0.45, 0.3));
    }

    // ポインター（最前面に描画、開き時のみ）
    if (isOpen) _drawPointer(canvas);

    // インナーシャドウ（上・下・右の三辺、Swift版準拠）
    _drawInnerShadows(canvas, size);
  }

  void _drawInnerShadows(Canvas canvas, Size size) {
    const shadowSize = 7.0;
    // 弧の左端位置を計算（弧の外にはみ出さないように）
    final sinAngle = min(1.0, cy / parentOuterR);
    final cosAngle = sqrt(1.0 - sinAngle * sinAngle);
    final shadowLeft = cx - (parentOuterR + 2) * cosAngle;

    // 上辺: 上から下へ
    canvas.drawRect(
      Rect.fromLTWH(shadowLeft, 0, size.width - shadowLeft, shadowSize),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(0, shadowSize),
          [Colors.black.withValues(alpha: 0.1), Colors.transparent],
        ),
    );

    // 下辺: 下から上へ
    canvas.drawRect(
      Rect.fromLTWH(shadowLeft, size.height - shadowSize, size.width - shadowLeft, shadowSize),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height),
          Offset(0, size.height - shadowSize),
          [Colors.black.withValues(alpha: 0.1), Colors.transparent],
        ),
    );

    // 右辺: 右から左へ
    canvas.drawRect(
      Rect.fromLTWH(size.width - shadowSize, 0, shadowSize, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width, 0),
          Offset(size.width - shadowSize, 0),
          [Colors.black.withValues(alpha: 0.1), Colors.transparent],
        ),
    );
  }

  void _drawRing(
    Canvas canvas, {
    required List<TagDialOption> options,
    required double rotation,
    required double outerR,
    required double innerR,
    required bool isParent,
  }) {
    for (int offset = -12; offset <= 12; offset++) {
      final baseIndex = (rotation / itemAngle).round();
      final rawIndex = baseIndex + offset;
      final hasTag = rawIndex >= 0 && rawIndex < options.length;

      final displayAngle = rawIndex * itemAngle - rotation;
      final distance = displayAngle.abs();

      // フェード計算
      final fade = max(0.0, 1.0 - distance / (itemAngle * 8));
      if (fade <= 0) continue;

      final isSelected = hasTag && distance < itemAngle / 2;

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
      if (!hasTag) {
        // タグ範囲外: グレー（Swift版準拠: Color(white: 0.92)）
        fillColor = const Color.fromRGBO(235, 235, 235, 1);
      } else if (!isOpen) {
        fillColor = const Color.fromRGBO(235, 235, 235, 1);
      } else if (options[rawIndex].id == null) {
        fillColor = Colors.white;
      } else {
        fillColor = options[rawIndex].color;
      }

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(sectorPath, fillPaint);

      // タグ範囲外はセクター塗りだけで終了
      if (!hasTag) continue;

      final option = options[rawIndex];

      // 仕切り線（Swift版準拠: Color(white: 0.35), opacity: fade * 0.5）
      final dividerPaint = Paint()
        ..color = Color.fromRGBO(89, 89, 89, fade * 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // 上端の仕切り線（cgEnd相当）
      final divAngle = (180 - displayAngle + itemAngle / 2) * pi / 180;
      canvas.drawLine(
        Offset(cx + innerR * cos(divAngle), cy + innerR * sin(divAngle)),
        Offset(cx + outerR * cos(divAngle), cy + outerR * sin(divAngle)),
        dividerPaint,
      );

      // 最後のセクターの下端仕切り線
      if (rawIndex == options.length - 1) {
        final bottomAngle = (180 - displayAngle - itemAngle / 2) * pi / 180;
        canvas.drawLine(
          Offset(cx + innerR * cos(bottomAngle), cy + innerR * sin(bottomAngle)),
          Offset(cx + outerR * cos(bottomAngle), cy + outerR * sin(bottomAngle)),
          dividerPaint,
        );
      }

      // テキスト描画
      if (isOpen && fade > 0.3) {
        final midR = (innerR + outerR) / 2;
        final midAngle = (180 - displayAngle) * pi / 180;
        final textX = cx + midR * cos(midAngle);
        final textY = cy + midR * sin(midAngle);

        final isNoneTag = option.id == null;
        // Swift版準拠: 文字数制限（半角幅換算: 親12、子10）
        final displayName = _truncateText(option.name, isParent ? 12 : 10);
        // Swift版準拠: セクター放射方向幅の90%に収まる最大フォントサイズを探す
        final sectorWidth = (outerR - innerR) * 0.9;
        final fMaxFont = isNoneTag ? (isParent ? 16.0 : 14.0) : (isParent ? 22.0 : 16.0);
        final fMinFont = isParent ? 13.0 : 11.0;
        final fontWeight = isSelected ? FontWeight.bold : FontWeight.w600;
        final textColor = isNoneTag
            ? Color.fromRGBO(140, 140, 140, fade)
            : Color.fromRGBO(
                isSelected ? 0 : 64,
                isSelected ? 0 : 64,
                isSelected ? 0 : 64,
                fade,
              );

        double fontSize = fMaxFont;
        late TextPainter textPainter;
        for (double fs = fMaxFont; fs >= fMinFont; fs -= 0.5) {
          textPainter = TextPainter(
            text: TextSpan(
              text: displayName,
              style: TextStyle(
                fontSize: fs,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          textPainter.layout();
          if (textPainter.width <= sectorWidth) {
            fontSize = fs;
            break;
          }
          fontSize = fs;
        }
        // ループで最終値が残っている場合、最小サイズで再レイアウト
        if (fontSize <= fMinFont) {
          textPainter = TextPainter(
            text: TextSpan(
              text: displayName,
              style: TextStyle(
                fontSize: fMinFont,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          textPainter.layout();
        }

        canvas.save();
        canvas.translate(textX, textY);
        canvas.rotate(-displayAngle * pi / 180);
        final textOffset = Offset(-textPainter.width / 2, -textPainter.height / 2);
        // 選択中タグにドロップシャドウ（Swift版準拠）
        if (isSelected && !isNoneTag) {
          final shadowPainter = TextPainter(
            text: TextSpan(
              text: displayName,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                foreground: Paint()
                  ..color = Colors.black.withValues(alpha: 0.4)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          shadowPainter.layout();
          shadowPainter.paint(canvas, textOffset + const Offset(0.5, 0.5));
        }
        textPainter.paint(canvas, textOffset);
        canvas.restore();
      }
    }
  }

  void _drawPointer(Canvas canvas) {
    // Swift版準拠: pw=10, ph=16, pLeft=-2
    const pw = 10.0, ph = 16.0, pLeft = -2.0;

    // 影（オフセット(1,1)のベタ影）
    final shadowPath = Path()
      ..moveTo(pLeft + 1, cy - ph / 2 + 1)
      ..lineTo(pLeft + pw + 1, cy + 1)
      ..lineTo(pLeft + 1, cy + ph / 2 + 1)
      ..close();
    canvas.drawPath(shadowPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill);

    // 本体（上→下のグラデーション）
    final pointerPath = Path()
      ..moveTo(pLeft, cy - ph / 2)
      ..lineTo(pLeft + pw, cy)
      ..lineTo(pLeft, cy + ph / 2)
      ..close();

    final colors = isOpen
        ? [const Color.fromRGBO(230, 38, 25, 1), const Color.fromRGBO(179, 25, 20, 1)]
        : [const Color.fromRGBO(140, 140, 140, 1), const Color.fromRGBO(115, 115, 115, 1)];

    final pointerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, cy - ph / 2),
        Offset(0, cy + ph / 2),
        colors,
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(pointerPath, pointerPaint);

    // ハイライト線（上辺に白50%）
    final hlPath = Path()
      ..moveTo(pLeft + 1, cy - ph / 2 + 2)
      ..lineTo(pLeft + pw - 3, cy);
    canvas.drawPath(hlPath, Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke);
  }

  void _drawEdgeArc(Canvas canvas, double radius, double lineWidth,
      {required (double, double, double) brightness}) {
    // 少し余分に描画してトレー端まで円弧を到達させる
    final halfHeight = cy + 4;
    final maxSin = min(1.0, halfHeight / radius);
    final maxAngle = asin(maxSin);

    // Swift版準拠: グラデーションで弧を描画
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final startAngle = pi - maxAngle;
    final sweepAngle = maxAngle * 2;

    Color _gray(double w) {
      final v = (w * 255).round();
      return Color.fromRGBO(v, v, v, 1);
    }

    final gradient = SweepGradient(
      center: Alignment(
        (cx - rect.center.dx) / (rect.width / 2),
        (cy - rect.center.dy) / (rect.height / 2),
      ),
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [_gray(brightness.$1), _gray(brightness.$2), _gray(brightness.$3)],
      stops: const [0.0, 0.5, 1.0],
    );

    final edgePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(rect, startAngle, sweepAngle, false, edgePaint);
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
