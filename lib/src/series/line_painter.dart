import 'dart:math' as math;
import 'dart:ui';

import '../core/coordinate_space.dart';
import '../style/chart_theme.dart';
import 'area_fill.dart';
import 'line_style.dart';
import 'monotone_spline.dart';
import 'series_painter.dart';

/// Paints a `LineSeries` or `AreaSeries`: an optional area fill below a
/// smooth (or linear) stroke.
class LineSeriesPainter extends SeriesPainter {
  /// Creates a painter for the given domain-space [points].
  ///
  /// [seriesColor] is the already-resolved palette/series color; the
  /// [style] may still override it (explicit color or context styling).
  /// [opacityFactor] mutes the whole series (used by `SeriesEmphasis`).
  /// [morphFrom], when set, holds previous-data points aligned index-wise
  /// with [points]; the painter lerps between the two by the `morph`
  /// progress.
  const LineSeriesPainter({
    required this.points,
    required this.style,
    required this.seriesColor,
    this.opacityFactor = 1,
    this.morphFrom,
  });

  /// Series data in domain space (`dx` = x value, `dy` = y value).
  final List<Offset> points;

  /// Previous-data points aligned to [points], or null when not morphing.
  final List<Offset>? morphFrom;

  /// The visual style to paint with.
  final LineStyle style;

  /// Resolved base color for this series.
  final Color seriesColor;

  /// Opacity multiplier for the whole series (1 = full).
  final double opacityFactor;

  @override
  void paint(
    Canvas canvas,
    CoordinateSpace space,
    ChartTheme theme, {
    double entrance = 1,
    double morph = 1,
  }) {
    if (entrance <= 0) return;
    final display = _displayPoints(morph);
    final pixels = <Offset>[
      for (final p in display)
        if (p.dx.isFinite && p.dy.isFinite) space.toPixel(p),
    ];
    if (pixels.isEmpty) return;

    var color =
        style.color ?? (style.isContext ? theme.contextColor : seriesColor);
    if (opacityFactor < 1) {
      color = color.withValues(alpha: color.a * opacityFactor);
    }

    if (pixels.length == 1) {
      // A single datum still deserves to be visible: draw a dot.
      canvas.drawCircle(
        pixels.first,
        style.strokeWidth * entrance,
        Paint()..color = color,
      );
      return;
    }

    var path = style.interpolation == LineInterpolation.monotone
        ? monotonePath(pixels)
        : linearPath(pixels);
    if (entrance < 1) {
      // Progressive reveal along the path length.
      path = _trimPath(path, entrance);
    }

    final area = style.area;
    if (area != null) {
      final frontier =
          entrance < 1 ? path.getBounds().right : double.infinity;
      _paintArea(canvas, space, pixels, area, color, frontier);
    }

    final dash = style.dashPattern;
    if (dash != null && dash.isNotEmpty) {
      path = dashPath(path, dash);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  List<Offset> _displayPoints(double morph) {
    final from = morphFrom;
    if (from == null || morph >= 1) return points;
    return <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset.lerp(
          i < from.length ? from[i] : points[i],
          points[i],
          morph,
        )!,
    ];
  }

  void _paintArea(
    Canvas canvas,
    CoordinateSpace space,
    List<Offset> pixels,
    AreaFill area,
    Color lineColor,
    double frontier,
  ) {
    // Baseline: y = 0 when it is inside the domain, else the domain edge
    // nearest zero.
    final yScale = space.yScale;
    final baseValue = yScale.min <= 0 && yScale.max >= 0
        ? 0.0
        : (yScale.min > 0 ? yScale.min : yScale.max);
    final baseY = space.yToPixel(baseValue);

    final linePath = style.interpolation == LineInterpolation.monotone
        ? monotonePath(pixels)
        : linearPath(pixels);
    final fillPath = Path.from(linePath)
      ..lineTo(pixels.last.dx, baseY)
      ..lineTo(pixels.first.dx, baseY)
      ..close();

    final fillColor = area.color ?? lineColor;
    final peak = fillColor.withValues(
      alpha: fillColor.a * area.opacity * opacityFactor,
    );

    final fillPaint = Paint();
    if (area.mode == AreaFillMode.solid) {
      fillPaint.color = peak;
    } else {
      // Gradient from the data edge (the point furthest from the baseline)
      // fading to transparent at the baseline.
      var extremeY = pixels.first.dy;
      for (final p in pixels) {
        if ((p.dy - baseY).abs() > (extremeY - baseY).abs()) {
          extremeY = p.dy;
        }
      }
      if ((extremeY - baseY).abs() < 1) {
        fillPaint.color = peak; // Degenerate flat area: flat fill.
      } else {
        fillPaint.shader = Gradient.linear(
          Offset(0, extremeY),
          Offset(0, baseY),
          <Color>[peak, fillColor.withValues(alpha: 0)],
        );
      }
    }

    if (frontier.isFinite) {
      // Entrance: only fill up to the revealed part of the stroke.
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
        space.plotArea.left - 8,
        space.plotArea.top - 8,
        frontier,
        space.plotArea.bottom + 8,
      ));
      canvas.drawPath(fillPath, fillPaint);
      canvas.restore();
    } else {
      canvas.drawPath(fillPath, fillPaint);
    }
  }

  Path _trimPath(Path source, double fraction) {
    final metrics = source.computeMetrics().toList();
    var total = 0.0;
    for (final m in metrics) {
      total += m.length;
    }
    var remaining = total * fraction;
    final dest = Path();
    for (final m in metrics) {
      if (remaining <= 0) break;
      final take = math.min(remaining, m.length);
      dest.addPath(m.extractPath(0, take), Offset.zero);
      remaining -= take;
    }
    return dest;
  }
}
