import 'dart:ui';

import 'package:meta/meta.dart';

import 'area_fill.dart';

/// How consecutive points of a line series are connected.
enum LineInterpolation {
  /// Monotone cubic (Fritsch–Carlson) — smooth with no overshoot.
  /// The default.
  monotone,

  /// Straight segments between points.
  linear,
}

/// Visual style for a `LineSeries` or `AreaSeries`.
///
/// The defaults are the product: a 2 px round-capped monotone-smooth stroke.
/// Add [area] for the signature gradient fill, and use [LineStyle.context]
/// for a muted, dashed comparison series ("last period" next to "this
/// period").
///
/// ```dart
/// LineSeries(data: thisPeriod, style: LineStyle(area: AreaFill.gradient()))
/// LineSeries(data: lastPeriod, style: const LineStyle.context())
/// ```
@immutable
class LineStyle {
  /// Creates a line style. Every parameter has an opinionated default.
  const LineStyle({
    this.strokeWidth = 2.0,
    this.interpolation = LineInterpolation.monotone,
    this.dashPattern,
    this.color,
    this.area,
  }) : isContext = false;

  /// A muted, dashed style for comparison ("context") series.
  ///
  /// Renders in the theme's `contextColor` (a low-emphasis gray) with a
  /// dash pattern, so the primary series stays the hero.
  const LineStyle.context({
    this.strokeWidth = 1.5,
    this.interpolation = LineInterpolation.monotone,
    this.dashPattern = const <double>[6, 4],
  })  : color = null,
        area = null,
        isContext = true;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// How points are connected.
  final LineInterpolation interpolation;

  /// Alternating on/off dash lengths, or null for a solid stroke.
  final List<double>? dashPattern;

  /// Explicit stroke color. When null the color comes from the series
  /// (`Series.color`) or the theme palette; context styles use the theme's
  /// `contextColor`.
  final Color? color;

  /// Fill painted between the line and the baseline, or null for none.
  final AreaFill? area;

  /// Whether this is a muted comparison style created with
  /// [LineStyle.context].
  final bool isContext;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LineStyle) return false;
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
    return other.strokeWidth == strokeWidth &&
        other.interpolation == interpolation &&
        dashEqual &&
        other.color == color &&
        other.area == area &&
        other.isContext == isContext;
  }

  @override
  int get hashCode => Object.hash(
        strokeWidth,
        interpolation,
        dashPattern == null ? null : Object.hashAll(dashPattern!),
        color,
        area,
        isContext,
      );
}
