import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 近六個月趨勢折線圖（點為空心圓，最新月份以虛線標示）
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.values, required this.months, required this.color, this.height = 190});
  final List<double> values;
  final List<DateTime> months;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TrendPainter(values, months, color)),
    );
  }
}

double _niceCeil(double v) {
  if (v <= 0) return 4000;
  final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final n = v / mag;
  for (final s in const [1.2, 2.0, 4.0, 6.0, 8.0, 10.0]) {
    if (n <= s) return s * mag;
  }
  return 10 * mag;
}

String _axisLabel(double v) {
  if (v == 0) return '0';
  if (v.abs() >= 1000) {
    final k = v / 1000;
    return k == k.roundToDouble() ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
  }
  return v.toStringAsFixed(0);
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.months, this.color);
  final List<double> values;
  final List<DateTime> months;
  final Color color;

  void _text(Canvas canvas, String s, Offset anchor, {bool right = false, bool center = false, Color col = C.muted}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = anchor.dx;
    var dy = anchor.dy;
    if (right) {
      dx -= tp.width;
      dy -= tp.height / 2;
    } else if (center) {
      dx -= tp.width / 2;
    }
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 56.0;
    const right = 24.0;
    const top = 10.0;
    const bottomSpace = 44.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottomSpace);
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final hi = _niceCeil(math.max(maxV, 0));
    final lo = minV < 0 ? -_niceCeil(-minV) : 0.0;
    final span = hi - lo;

    double yOf(double v) => plot.bottom - (v - lo) / span * plot.height;

    final grid = Paint()
      ..color = C.lineSoft
      ..strokeWidth = 1;
    final base = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = lo + span * i / 4;
      final y = yOf(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), i == 0 ? base : grid);
      _text(canvas, _axisLabel(v), Offset(plot.left - 10, y), right: true);
    }

    final n = values.length;
    final xs = [
      for (var i = 0; i < n; i++)
        n == 1 ? plot.center.dx : plot.left + 30 + (plot.width - 60) * i / (n - 1)
    ];
    final pts = [for (var i = 0; i < n; i++) Offset(xs[i], yOf(values[i]))];

    // 最新月份的虛線
    final dash = Paint()
      ..color = color
      ..strokeWidth = 2;
    var y = plot.top;
    while (y < plot.bottom) {
      canvas.drawLine(Offset(pts.last.dx, y), Offset(pts.last.dx, math.min(y + 5, plot.bottom)), dash);
      y += 9;
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);

    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      canvas.drawCircle(pts[i], 5.5, Paint()..color = isLast ? color : C.panel);
      canvas.drawCircle(
        pts[i],
        5.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    for (var i = 0; i < n; i++) {
      final m = months[i];
      final col = i == n - 1 ? C.text : C.muted;
      _text(canvas, '${m.month}月', Offset(xs[i], plot.bottom + 8), center: true, col: col);
      _text(canvas, '${m.year}', Offset(xs[i], plot.bottom + 24), center: true, col: C.muted);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.color != color || old.values.join(',') != values.join(',') || old.months.length != months.length;
}

class DonutSlice {
  final double value;
  final Color color;
  const DonutSlice(this.value, this.color);
}

/// 甜甜圈圖（中間由外層 Stack 放文字）
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 150, this.thickness = 28});
  final List<DonutSlice> slices;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DonutPainter(slices, thickness)),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.thickness);
  final List<DonutSlice> slices;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(thickness / 2, thickness / 2, size.width - thickness, size.height - thickness);
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = C.raised
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}
