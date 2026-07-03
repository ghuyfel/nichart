import 'dart:ui';

import 'package:meta/meta.dart';

/// How multiple `BarSeries` share a category band.
enum BarArrangement {
  /// Series sit side by side within the band. The default.
  grouped,

  /// Series stack on top of each other, positives up and negatives down,
  /// with a 2 px gap between segments.
  stacked,
}

/// Visual style for a `BarSeries`.
///
/// Defaults are the product: bars at most 24 px thick with a small corner
/// radius on the data end only (square at the baseline).
@immutable
class BarStyle {
  /// Creates a bar style. Every parameter has an opinionated default.
  const BarStyle({
    this.maxThickness = 24,
    this.cornerRadius = 5,
    this.color,
    this.mutedOpacity = 0.3,
  });

  /// Maximum bar thickness in logical pixels. Bars shrink to fit their
  /// band but never grow beyond this.
  final double maxThickness;

  /// Corner radius on the data end of the bar (the baseline end is always
  /// square). Clamped to half the bar thickness.
  final double cornerRadius;

  /// Explicit bar color. When null the color comes from the series
  /// (`Series.color`) or the theme palette.
  final Color? color;

  /// Opacity multiplier applied to non-emphasized bars when
  /// `BarSeries.emphasizedIndex` (or `Sparkline.bars(emphasizeLast:)`)
  /// highlights one bar.
  final double mutedOpacity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarStyle &&
          other.maxThickness == maxThickness &&
          other.cornerRadius == cornerRadius &&
          other.color == color &&
          other.mutedOpacity == mutedOpacity;

  @override
  int get hashCode =>
      Object.hash(maxThickness, cornerRadius, color, mutedOpacity);
}
