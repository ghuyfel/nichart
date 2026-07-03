import 'dart:ui';

import 'package:meta/meta.dart';

import '../scales/scale.dart';

/// Maps data-domain coordinates into the pixel-space plot rectangle.
///
/// The y axis is flipped as charts expect: larger values are higher on
/// screen (smaller `dy`). The x scale is any `Scale<double>` — a
/// `NumericScale` for numeric domains, a `NumericScale` over milliseconds
/// for time domains, or a `CategoryScale` over band indices for
/// categorical domains. Custom `SeriesPainter` implementations receive a
/// [CoordinateSpace] to project their data.
@immutable
class CoordinateSpace {
  /// Creates a coordinate space for [plotArea] with the given scales.
  const CoordinateSpace({
    required this.plotArea,
    required this.xScale,
    required this.yScale,
  });

  /// The pixel rectangle data is drawn into (excludes axis labels).
  final Rect plotArea;

  /// Scale for the horizontal axis, over the series' domain-space x values
  /// (numeric value, epoch milliseconds, or category index).
  final Scale<double> xScale;

  /// Scale for the vertical axis.
  final NumericScale yScale;

  /// Projects a domain x value to a pixel x coordinate.
  double xToPixel(double x) =>
      plotArea.left + xScale.normalize(x) * plotArea.width;

  /// Projects a domain y value to a pixel y coordinate (flipped).
  double yToPixel(double y) =>
      plotArea.bottom - yScale.normalize(y) * plotArea.height;

  /// Projects a domain point (`dx` = x value, `dy` = y value) to pixels.
  Offset toPixel(Offset domainPoint) =>
      Offset(xToPixel(domainPoint.dx), yToPixel(domainPoint.dy));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoordinateSpace &&
          other.plotArea == plotArea &&
          other.xScale == xScale &&
          other.yScale == yScale;

  @override
  int get hashCode => Object.hash(plotArea, xScale, yScale);

  @override
  String toString() => 'CoordinateSpace($plotArea, x: $xScale, y: $yScale)';
}
