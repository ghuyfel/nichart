import 'dart:math' as math;
import 'dart:ui';

import '../core/coordinate_space.dart';
import '../style/chart_theme.dart';
import 'donut_style.dart';
import 'series_painter.dart';

Offset _polar(Offset center, double radius, double angle) =>
    center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);

/// Paints a `DonutSeries` as annular segments (or pie wedges when the
/// cutout is 0), with gaps and rounded segment ends.
class DonutSeriesPainter extends SeriesPainter {
  /// Creates a painter for the given segment [values].
  const DonutSeriesPainter({
    required this.values,
    required this.colors,
    required this.style,
    this.morphFrom,
    this.opacityFactor = 1,
  });

  /// Segment magnitudes, in display order. Non-positive values are
  /// skipped.
  final List<double> values;

  /// Previous-data values aligned to [values], or null when not morphing.
  final List<double>? morphFrom;

  /// Per-segment colors (palette order).
  final List<Color> colors;

  /// The visual style to paint with.
  final DonutStyle style;

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
    if (entrance <= 0 || values.isEmpty) return;

    final source = morphFrom;
    final display = <double>[
      for (var i = 0; i < values.length; i++)
        source != null && morph < 1 && i < source.length
            ? source[i] + (values[i] - source[i]) * morph
            : values[i],
    ];

    var total = 0.0;
    for (final v in display) {
      if (v > 0 && v.isFinite) total += v;
    }
    if (total <= 0) return;

    final bounds = space.plotArea;
    final center = bounds.center;
    final maxOuter = math.max(1.0, bounds.shortestSide / 2);
    final outer =
        style.radius == null ? maxOuter : style.radius!.clamp(1.0, maxOuter);
    final inner = (outer * style.cutout).clamp(0.0, outer - 1);

    // Entrance: segments sweep in clockwise from the start angle.
    final visibleEnd = style.startAngle + entrance * 2 * math.pi;

    var cursor = style.startAngle;
    for (var i = 0; i < display.length; i++) {
      final v = display[i];
      if (v <= 0 || !v.isFinite) continue;
      final start = cursor;
      final end = cursor + v / total * 2 * math.pi;
      cursor = end;
      final clippedEnd = math.min(end, visibleEnd);
      if (clippedEnd <= start) continue;

      var color = colors[i % colors.length];
      if (opacityFactor < 1) {
        color = color.withValues(alpha: color.a * opacityFactor);
      }
      canvas.drawPath(
        _segmentPath(center, outer, inner, start, clippedEnd),
        Paint()..color = color,
      );
    }
  }

  Path _segmentPath(
    Offset center,
    double outer,
    double inner,
    double a0,
    double a1,
  ) {
    final path = Path();
    // Half the pixel gap, as an angle at each radius; single full-circle
    // segments get no gap.
    final fullCircle = (a1 - a0) >= 2 * math.pi - 1e-6;
    final gapOut = fullCircle ? 0.0 : style.gap / 2 / outer;
    final o0 = a0 + gapOut;
    final o1 = a1 - gapOut;
    if (o1 <= o0) return path; // Segment thinner than its gap.

    final outerRect = Rect.fromCircle(center: center, radius: outer);

    if (inner <= math.max(style.gap, 1)) {
      // Pie wedge: edges converge at the center; round only the two outer
      // corners.
      final r = math.min(style.cornerRadius, (o1 - o0) * outer / 3);
      final c = r / outer;
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        _polar(center, outer - r, o0).dx,
        _polar(center, outer - r, o0).dy,
      );
      final q0 = _polar(center, outer, o0);
      path.quadraticBezierTo(
        q0.dx,
        q0.dy,
        _polar(center, outer, o0 + c).dx,
        _polar(center, outer, o0 + c).dy,
      );
      path.arcTo(outerRect, o0 + c, (o1 - c) - (o0 + c), false);
      final q1 = _polar(center, outer, o1);
      path.quadraticBezierTo(
        q1.dx,
        q1.dy,
        _polar(center, outer - r, o1).dx,
        _polar(center, outer - r, o1).dy,
      );
      path.close();
      return path;
    }

    // Annular segment. Gap angles differ per radius so the gap edges stay
    // parallel; corners are rounded with small quadratic cuts.
    final gapIn = fullCircle ? 0.0 : style.gap / 2 / inner;
    final i0 = a0 + gapIn;
    final i1 = a1 - gapIn;
    if (i1 <= i0) {
      // Too thin for parallel gaps at the inner radius: draw an un-gapped
      // sliver so tiny segments stay visible.
      path.moveTo(_polar(center, outer, o0).dx, _polar(center, outer, o0).dy);
      path.arcTo(outerRect, o0, o1 - o0, false);
      final mid = (a0 + a1) / 2;
      path.lineTo(_polar(center, inner, mid).dx, _polar(center, inner, mid).dy);
      path.close();
      return path;
    }

    final thickness = outer - inner;
    final r = math.min(
      style.cornerRadius,
      math.min(thickness / 3, (o1 - o0) * outer / 4),
    );
    final cOut = r / outer;
    final cIn = r / inner;
    final innerRect = Rect.fromCircle(center: center, radius: inner);

    // Corner anchor points.
    final outerStart = _polar(center, outer, o0);
    final outerEnd = _polar(center, outer, o1);
    final innerStart = _polar(center, inner, i0);
    final innerEnd = _polar(center, inner, i1);

    Offset along(Offset from, Offset to) {
      final d = to - from;
      final len = d.distance;
      return len == 0 ? from : from + d * (r / len);
    }

    path.moveTo(
      _polar(center, outer, o0 + cOut).dx,
      _polar(center, outer, o0 + cOut).dy,
    );
    path.arcTo(outerRect, o0 + cOut, (o1 - cOut) - (o0 + cOut), false);
    path.quadraticBezierTo(
      outerEnd.dx,
      outerEnd.dy,
      along(outerEnd, innerEnd).dx,
      along(outerEnd, innerEnd).dy,
    );
    path.lineTo(
      along(innerEnd, outerEnd).dx,
      along(innerEnd, outerEnd).dy,
    );
    path.quadraticBezierTo(
      innerEnd.dx,
      innerEnd.dy,
      _polar(center, inner, i1 - cIn).dx,
      _polar(center, inner, i1 - cIn).dy,
    );
    path.arcTo(innerRect, i1 - cIn, (i0 + cIn) - (i1 - cIn), false);
    path.quadraticBezierTo(
      innerStart.dx,
      innerStart.dy,
      along(innerStart, outerStart).dx,
      along(innerStart, outerStart).dy,
    );
    path.lineTo(
      along(outerStart, innerStart).dx,
      along(outerStart, innerStart).dy,
    );
    path.quadraticBezierTo(
      outerStart.dx,
      outerStart.dy,
      _polar(center, outer, o0 + cOut).dx,
      _polar(center, outer, o0 + cOut).dy,
    );
    path.close();
    return path;
  }
}
