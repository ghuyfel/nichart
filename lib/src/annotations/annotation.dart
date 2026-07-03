import 'dart:ui';

import 'package:meta/meta.dart';

/// A decoration drawn in the plot's domain space — reference bands and
/// lines that give data context (a target range, a threshold, an event
/// moment) without being data themselves.
///
/// Annotations never participate in interaction: they are invisible to
/// crosshair snapping, tooltips and hover, and they don't affect the
/// automatic domain bounds.
///
/// ```dart
/// Chart(
///   annotations: [
///     BandAnnotation.y(from: 70, to: 180, color: green.withValues(alpha: .12)),
///     LineAnnotation.x(value: 12.5, dashPattern: [6, 4]),
///   ],
///   series: [LineSeries(data: points)],
/// )
/// ```
@immutable
sealed class ChartAnnotation {
  /// Const constructor for subclasses.
  const ChartAnnotation();
}

/// A filled band between two values on one axis, spanning the full plot
/// along the other. Painted beneath the grid, so gridlines stay visible
/// through the wash.
final class BandAnnotation extends ChartAnnotation {
  /// A horizontal band between two y values (e.g. a target range).
  const BandAnnotation.y({required this.from, required this.to, this.color})
      : vertical = false;

  /// A vertical band between two x values (e.g. a time window).
  const BandAnnotation.x({required this.from, required this.to, this.color})
      : vertical = true;

  /// Whether the band spans two x values (true) or two y values (false).
  final bool vertical;

  /// Band start, in domain units of its axis.
  final double from;

  /// Band end, in domain units of its axis.
  final double to;

  /// Fill color. Defaults to a whisper of the theme's grid color; pass a
  /// translucent color — the band sits behind the data.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BandAnnotation &&
          other.vertical == vertical &&
          other.from == from &&
          other.to == to &&
          other.color == color;

  @override
  int get hashCode => Object.hash(vertical, from, to, color);
}

/// A reference line at one value on one axis, spanning the full plot
/// along the other. Painted over the series, beneath interaction chrome.
final class LineAnnotation extends ChartAnnotation {
  /// A horizontal line at a y value (e.g. a threshold).
  const LineAnnotation.y({
    required this.value,
    this.color,
    this.strokeWidth = 1.5,
    this.dashPattern,
  }) : vertical = false;

  /// A vertical line at an x value (e.g. an event moment).
  const LineAnnotation.x({
    required this.value,
    this.color,
    this.strokeWidth = 1.5,
    this.dashPattern,
  }) : vertical = true;

  /// Whether the line marks an x value (true) or a y value (false).
  final bool vertical;

  /// The marked value, in domain units of its axis.
  final double value;

  /// Line color. Defaults to the theme's context (muted) color.
  final Color? color;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// Alternating on/off dash lengths, or null for a solid line.
  final List<double>? dashPattern;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LineAnnotation) return false;
    final a = dashPattern;
    final b = other.dashPattern;
    final dashEqual = identical(a, b) ||
        (a != null &&
            b != null &&
            a.length == b.length &&
            () {
              for (var i = 0; i < a.length; i++) {
                if (a[i] != b[i]) return false;
              }
              return true;
            }());
    return other.vertical == vertical &&
        other.value == value &&
        other.color == color &&
        other.strokeWidth == strokeWidth &&
        dashEqual;
  }

  @override
  int get hashCode => Object.hash(
        vertical,
        value,
        color,
        strokeWidth,
        dashPattern == null ? null : Object.hashAll(dashPattern!),
      );
}
