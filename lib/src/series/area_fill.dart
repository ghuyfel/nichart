import 'dart:ui';

import 'package:meta/meta.dart';

/// How an area fill is painted.
enum AreaFillMode {
  /// Linear gradient: series color at [AreaFill.opacity] at the data edge,
  /// fading to fully transparent at the baseline. The default.
  gradient,

  /// Flat fill at [AreaFill.opacity].
  solid,
}

/// The fill under a line — used by `AreaSeries` and `LineStyle.area`.
///
/// ```dart
/// LineSeries(data: points, style: LineStyle(area: AreaFill.gradient()))
/// AreaSeries(data: points) // gradient fill by default
/// ```
@immutable
class AreaFill {
  /// A gradient fill: series color at [opacity] fading to transparent at
  /// the baseline. This is the signature nichart look.
  const AreaFill.gradient({this.opacity = 0.22, this.color})
      : mode = AreaFillMode.gradient;

  /// A flat fill at [opacity].
  const AreaFill.solid({this.opacity = 0.12, this.color})
      : mode = AreaFillMode.solid;

  /// How the fill is painted.
  final AreaFillMode mode;

  /// Peak fill opacity, applied to the series color.
  final double opacity;

  /// Explicit fill color. When null the fill uses the series color.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AreaFill &&
          other.mode == mode &&
          other.opacity == opacity &&
          other.color == color;

  @override
  int get hashCode => Object.hash(mode, opacity, color);
}
