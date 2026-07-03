// Fritsch–Carlson monotone cubic interpolation.
//
// Internal library — not exported from the package barrel. Kept as pure
// functions over pixel-space offsets so the math is trivially unit-testable
// (see test/monotone_spline_test.dart for the no-overshoot property test).

import 'dart:math' as math;
import 'dart:ui';

/// Computes Fritsch–Carlson tangents for [points] (assumed sorted by x).
///
/// The returned tangents make the piecewise cubic Hermite interpolant
/// monotone on every interval where the data is monotone — no overshoot or
/// ringing, unlike Catmull-Rom. Reference: Fritsch & Carlson, "Monotone
/// Piecewise Cubic Interpolation", SIAM J. Numer. Anal. 17 (1980).
List<double> monotoneTangents(List<Offset> points) {
  final n = points.length;
  if (n < 2) return List<double>.filled(n, 0);

  final delta = List<double>.filled(n - 1, 0);
  for (var i = 0; i < n - 1; i++) {
    final dx = points[i + 1].dx - points[i].dx;
    final dy = points[i + 1].dy - points[i].dy;
    delta[i] = dx == 0 ? 0 : dy / dx;
  }

  final m = List<double>.filled(n, 0);
  m[0] = delta[0];
  m[n - 1] = delta[n - 2];
  for (var i = 1; i < n - 1; i++) {
    // Zero tangent at local extrema (secant sign change) keeps the curve
    // from overshooting a peak or valley.
    m[i] = delta[i - 1] * delta[i] <= 0 ? 0 : (delta[i - 1] + delta[i]) / 2;
  }

  for (var i = 0; i < n - 1; i++) {
    if (delta[i] == 0) {
      // Flat segment: both ends must be flat or the curve would bulge.
      m[i] = 0;
      m[i + 1] = 0;
      continue;
    }
    final alpha = m[i] / delta[i];
    final beta = m[i + 1] / delta[i];
    final d = alpha * alpha + beta * beta;
    if (d > 9) {
      // Pull tangents back inside the monotonicity circle of radius 3.
      final tau = 3 / math.sqrt(d);
      m[i] = tau * alpha * delta[i];
      m[i + 1] = tau * beta * delta[i];
    }
  }
  return m;
}

/// Evaluates the cubic Hermite segment from `p0` to `p1` (tangents `m0`,
/// `m1` in dy/dx form) at parameter [t] ∈ [0, 1]. Used by tests to verify
/// the no-overshoot property; painting uses the Bézier form instead.
double hermiteY(Offset p0, Offset p1, double m0, double m1, double t) {
  final dx = p1.dx - p0.dx;
  final t2 = t * t;
  final t3 = t2 * t;
  final h00 = 2 * t3 - 3 * t2 + 1;
  final h10 = t3 - 2 * t2 + t;
  final h01 = -2 * t3 + 3 * t2;
  final h11 = t3 - t2;
  return h00 * p0.dy + h10 * dx * m0 + h01 * p1.dy + h11 * dx * m1;
}

/// Builds a smooth [Path] through [points] using monotone cubic segments,
/// expressed as cubic Béziers (the Hermite→Bézier conversion is exact).
Path monotonePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) return path;

  final m = monotoneTangents(points);
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i];
    final p1 = points[i + 1];
    final dx = (p1.dx - p0.dx) / 3;
    path.cubicTo(
      p0.dx + dx,
      p0.dy + m[i] * dx,
      p1.dx - dx,
      p1.dy - m[i + 1] * dx,
      p1.dx,
      p1.dy,
    );
  }
  return path;
}

/// Builds a straight-segment [Path] through [points].
Path linearPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  return path;
}

/// Converts [source] into a dashed path following [pattern]
/// (alternating on/off lengths, e.g. `[6, 4]`).
Path dashPath(Path source, List<double> pattern) {
  assert(pattern.isNotEmpty, 'dash pattern must not be empty');
  final dest = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var index = 0;
    var draw = true;
    while (distance < metric.length) {
      final len = pattern[index % pattern.length];
      index++;
      if (draw && len > 0) {
        dest.addPath(
          metric.extractPath(
            distance,
            math.min(distance + len, metric.length),
          ),
          Offset.zero,
        );
      }
      distance += len;
      draw = !draw;
    }
  }
  return dest;
}
