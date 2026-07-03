import 'dart:ui';

import 'package:meta/meta.dart';

/// One series' data point under the crosshair.
@immutable
class HoveredPoint {
  /// Creates a hovered-point description.
  const HoveredPoint({
    required this.seriesIndex,
    required this.color,
    required this.x,
    required this.y,
    required this.pixel,
    this.seriesId,
    this.seriesLabel,
  });

  /// Position of the series in the chart's `series` list.
  final int seriesIndex;

  /// The series' `id`, if set.
  final String? seriesId;

  /// The series' `label`, if set.
  final String? seriesLabel;

  /// Resolved series color (explicit color or palette assignment).
  final Color color;

  /// Domain x value of the point (numeric value, epoch milliseconds, or
  /// category index).
  final double x;

  /// Domain y value of the point.
  final double y;

  /// The point projected into chart-local pixels.
  final Offset pixel;
}

/// Everything known about the current crosshair position — passed to
/// tooltip builders and hover listeners.
@immutable
class ChartHoverInfo {
  /// Creates a hover description.
  const ChartHoverInfo({
    required this.position,
    required this.x,
    required this.xPixel,
    required this.xLabel,
    required this.points,
  });

  /// The raw pointer position in chart-local pixels.
  final Offset position;

  /// The snapped domain x value (index mode: the nearest data x across all
  /// series).
  final double x;

  /// The snapped x position in chart-local pixels.
  final double xPixel;

  /// [x] formatted with the axis' formatter (`'Mar 5'`, `'12k'`, or the
  /// category name).
  final String xLabel;

  /// The matched point of every series at the snapped x, in series order.
  final List<HoveredPoint> points;
}
