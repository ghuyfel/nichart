import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Visual style for a `DonutSeries`.
///
/// Defaults are the product: a 72% cutout, 2 px surface-color gaps between
/// segments, and a small corner radius on segment ends. Set [cutout] to 0
/// for a pie chart.
@immutable
class DonutStyle {
  /// Creates a donut style. Every parameter has an opinionated default.
  const DonutStyle({
    this.cutout = 0.72,
    this.gap = 2,
    this.cornerRadius = 3,
    this.startAngle = -math.pi / 2,
    this.radius,
  });

  /// Inner radius as a fraction of the outer radius. 0 renders a pie.
  final double cutout;

  /// Explicit outer radius in logical pixels. When null (the default) the
  /// donut fills its box; when set, it is still clamped to what the box
  /// can fit. Useful to shrink the ring and leave more room for a center
  /// widget.
  final double? radius;

  /// Gap between segments in logical pixels — the surface shows through,
  /// never a stroke.
  final double gap;

  /// Corner radius on segment ends in logical pixels.
  final double cornerRadius;

  /// Angle of the first segment's start, in radians. Defaults to the top
  /// of the circle (12 o'clock), sweeping clockwise.
  final double startAngle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DonutStyle &&
          other.cutout == cutout &&
          other.gap == gap &&
          other.cornerRadius == cornerRadius &&
          other.startAngle == startAngle &&
          other.radius == radius;

  @override
  int get hashCode =>
      Object.hash(cutout, gap, cornerRadius, startAngle, radius);
}
