import 'dart:ui';

import 'package:meta/meta.dart';

/// Visual style for a `ScatterSeries`.
@immutable
class ScatterStyle {
  /// Creates a scatter style. Every parameter has an opinionated default.
  const ScatterStyle({
    this.radius = 4,
    this.opacity = 0.85,
    this.color,
  });

  /// Marker radius in logical pixels.
  final double radius;

  /// Marker opacity. Slightly translucent by default so overlapping points
  /// read as density instead of hiding each other.
  final double opacity;

  /// Explicit marker color. When null the color comes from the series
  /// (`Series.color`) or the theme palette.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScatterStyle &&
          other.radius == radius &&
          other.opacity == opacity &&
          other.color == color;

  @override
  int get hashCode => Object.hash(radius, opacity, color);
}
