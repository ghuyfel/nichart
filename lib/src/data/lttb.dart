import 'dart:math' as math;
import 'dart:ui';

/// Largest-Triangle-Three-Buckets downsampling.
///
/// Reduces [points] to at most [threshold] points while preserving the
/// visual shape of the line: the first and last points are always kept,
/// the rest are bucketed, and each bucket contributes the point forming
/// the largest triangle with the previously selected point and the next
/// bucket's average. Peaks and valleys survive; flat stretches thin out.
///
/// Returns the original list unchanged when `threshold >= points.length`
/// or `threshold < 3` (identity is cheap to detect via [identical]).
///
/// Reference: Sveinn Steinarsson, "Downsampling Time Series for Visual
/// Representation" (2013).
List<Offset> lttbDownsample(List<Offset> points, int threshold) {
  final n = points.length;
  if (threshold >= n || threshold < 3) return points;

  final sampled = <Offset>[points.first];
  final bucketSize = (n - 2) / (threshold - 2);
  var selected = points.first;

  for (var i = 0; i < threshold - 2; i++) {
    final rangeStart = (i * bucketSize).floor() + 1;
    final rangeEnd = math.min(((i + 1) * bucketSize).floor() + 1, n - 1);

    // Average of the *next* bucket (or the last point for the final one).
    final nextStart = rangeEnd;
    final nextEnd = math.min(((i + 2) * bucketSize).floor() + 1, n);
    double avgX, avgY;
    if (nextEnd > nextStart) {
      avgX = 0;
      avgY = 0;
      for (var j = nextStart; j < nextEnd; j++) {
        avgX += points[j].dx;
        avgY += points[j].dy;
      }
      final count = nextEnd - nextStart;
      avgX /= count;
      avgY /= count;
    } else {
      avgX = points[n - 1].dx;
      avgY = points[n - 1].dy;
    }

    var maxArea = -1.0;
    var maxIndex = rangeStart;
    for (var j = rangeStart; j < rangeEnd; j++) {
      final area = ((selected.dx - avgX) * (points[j].dy - selected.dy) -
              (selected.dx - points[j].dx) * (avgY - selected.dy))
          .abs();
      if (area > maxArea) {
        maxArea = area;
        maxIndex = j;
      }
    }
    selected = points[maxIndex];
    sampled.add(selected);
  }

  sampled.add(points.last);
  return sampled;
}
