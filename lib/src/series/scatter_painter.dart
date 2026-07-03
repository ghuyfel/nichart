import 'dart:typed_data';
import 'dart:ui';

import '../core/coordinate_space.dart';
import '../style/chart_theme.dart';
import 'scatter_style.dart';
import 'series_painter.dart';

/// Above this point count, markers are drawn as one GPU point batch via
/// [Canvas.drawRawPoints] instead of individual circles.
const int _kRawPointsThreshold = 1500;

/// Paints a `ScatterSeries` as circular markers.
///
/// Large sets (> ~1500 points) are drawn as a single raw point batch —
/// round stroke caps at the marker diameter — into a reused
/// [Float32List] buffer, so painting 100k points allocates nothing per
/// frame beyond the one buffer.
class ScatterSeriesPainter extends SeriesPainter {
  /// Creates a painter for the given domain-space [points].
  ScatterSeriesPainter({
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
  final ScatterStyle style;

  /// Resolved base color for this series.
  final Color seriesColor;

  /// Opacity multiplier for the whole series (1 = full).
  final double opacityFactor;

  Float32List? _rawBuffer;

  @override
  void paint(
    Canvas canvas,
    CoordinateSpace space,
    ChartTheme theme, {
    double entrance = 1,
    double morph = 1,
  }) {
    if (entrance <= 0 || points.isEmpty) return;
    final base = style.color ?? seriesColor;
    var alpha = base.a * style.opacity * opacityFactor;

    if (points.length >= _kRawPointsThreshold) {
      // Batch path: one drawRawPoints call, entrance as a fade.
      if (entrance < 1) alpha *= entrance;
      final buffer =
          _rawBuffer ??= Float32List(points.length * 2);
      var count = 0;
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        if (!p.dx.isFinite || !p.dy.isFinite) continue;
        buffer[count++] = space.xToPixel(p.dx);
        buffer[count++] = space.yToPixel(p.dy);
      }
      canvas.drawRawPoints(
        PointMode.points,
        count == buffer.length
            ? buffer
            : Float32List.sublistView(buffer, 0, count),
        Paint()
          ..color = base.withValues(alpha: alpha)
          ..strokeWidth = style.radius * 2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final paint = Paint()..color = base.withValues(alpha: alpha);

    // Slight stagger so clouds sparkle in instead of appearing as one.
    final n = points.length;
    final delay = n <= 1 ? 0.0 : (0.3 / n).clamp(0.0, 0.02);
    final span = 1 - delay * (n - 1);

    final from = morphFrom;
    for (var i = 0; i < n; i++) {
      var p = points[i];
      if (from != null && morph < 1) {
        p = Offset.lerp(i < from.length ? from[i] : p, p, morph)!;
      }
      if (!p.dx.isFinite || !p.dy.isFinite) continue;
      var radius = style.radius;
      if (entrance < 1) {
        final t = ((entrance - delay * i) / span).clamp(0.0, 1.0);
        if (t <= 0) continue;
        radius *= t;
      }
      canvas.drawCircle(space.toPixel(p), radius, paint);
    }
  }
}
