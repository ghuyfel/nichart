import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Downsampling policy for line and area series.
///
/// Large series are reduced with LTTB (Largest-Triangle-Three-Buckets)
/// before painting — the visual shape is preserved while the point count
/// drops to what the plot can actually show. On by default; the raw data
/// is untouched (tooltips and hover always see every point).
///
/// ```dart
/// LineSeries(data: hundredK)                                  // auto
/// LineSeries(data: hundredK, downsampling: const Downsampling.none())
/// LineSeries(data: hundredK, downsampling: const Downsampling.fixed(2000))
/// ```
///
/// Bar and scatter series ignore this setting (scatter uses raw GPU point
/// batches instead).
@immutable
class Downsampling {
  /// Downsample automatically when a series exceeds ~[pixelFactor]× the
  /// plot width in points. The default.
  const Downsampling.auto({this.pixelFactor = 2})
      : maxPoints = null,
        disabled = false;

  /// Never downsample — paint every point.
  const Downsampling.none()
      : pixelFactor = 0,
        maxPoints = null,
        disabled = true;

  /// Downsample to at most [maxPoints] points, regardless of plot width.
  const Downsampling.fixed(int this.maxPoints)
      : pixelFactor = 0,
        disabled = false;

  /// Points-per-pixel-of-plot-width multiplier for [Downsampling.auto].
  final double pixelFactor;

  /// Fixed point budget for [Downsampling.fixed], else null.
  final int? maxPoints;

  /// Whether downsampling is disabled entirely.
  final bool disabled;

  /// The point budget for a plot of [plotWidth] logical pixels, or null
  /// when downsampling is disabled.
  int? thresholdFor(double plotWidth) {
    if (disabled) return null;
    final fixed = maxPoints;
    if (fixed != null) return math.max(3, fixed);
    return math.max(256, (plotWidth * pixelFactor).round());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Downsampling &&
          other.pixelFactor == pixelFactor &&
          other.maxPoints == maxPoints &&
          other.disabled == disabled;

  @override
  int get hashCode => Object.hash(pixelFactor, maxPoints, disabled);
}
