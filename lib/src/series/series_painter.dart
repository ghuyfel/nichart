import 'dart:ui';

import '../core/coordinate_space.dart';
import '../style/chart_theme.dart';

/// Paints one series into the plot area.
///
/// Implementations are created by the chart's render object with the
/// series' data already resolved to domain-space points, and are invoked
/// each frame with the current (possibly morph-interpolated)
/// [CoordinateSpace] and [ChartTheme]. The canvas is pre-clipped to the
/// plot area (with a small margin for stroke width), so painters draw
/// freely in pixel space.
///
/// [entrance] and [morph] are eased animation progress values in `[0, 1]`;
/// both are `1` when the chart is at rest, so a painter that ignores them
/// simply renders the settled state.
abstract class SeriesPainter {
  /// Const constructor for subclasses.
  const SeriesPainter();

  /// Paints the series onto [canvas].
  void paint(
    Canvas canvas,
    CoordinateSpace space,
    ChartTheme theme, {
    double entrance = 1,
    double morph = 1,
  });
}
