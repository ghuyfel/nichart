import 'package:flutter/widgets.dart';

import 'hover_info.dart';

/// A chart interaction behavior.
///
/// Pass instances to `Chart.interactions`. The default is
/// `[Crosshair(), ChartTooltip()]` — hover/scrub inspection works out of
/// the box; pan and zoom are opt-in:
///
/// ```dart
/// Chart(
///   series: [...],
///   interactions: const [Crosshair(), ChartTooltip(), PanZoom()],
/// )
/// ```
sealed class ChartInteraction {
  /// Const constructor for subclasses.
  const ChartInteraction();
}

/// A vertical crosshair that snaps to the nearest data x across all series
/// (index mode), with hover markers on the matched points.
///
/// Mouse: follows hover. Touch: drag to scrub (when pan/zoom is off) or
/// long-press-drag (always).
final class Crosshair extends ChartInteraction {
  /// Creates a crosshair configuration.
  const Crosshair({this.showLine = true, this.showMarkers = true});

  /// Whether to draw the vertical hairline at the snapped x.
  final bool showLine;

  /// Whether to draw markers (series-color fill, surface-color ring) on
  /// the matched points.
  final bool showMarkers;
}

/// A tooltip listing every series' value at the crosshair position.
///
/// The default look is a dark rounded card with a color chip, label and
/// formatted value per series. Fully custom content via [builder]:
///
/// ```dart
/// ChartTooltip(
///   builder: (context, info) => MyCard(points: info.points),
/// )
/// ```
final class ChartTooltip extends ChartInteraction {
  /// Creates a tooltip configuration.
  const ChartTooltip({this.builder, this.valueFormatter});

  /// Custom tooltip widget, laid out near the crosshair. When null the
  /// built-in card is painted instead.
  final Widget Function(BuildContext context, ChartHoverInfo info)? builder;

  /// Formats row values in the built-in card. Defaults to a compact
  /// formatter (`1.5M`, `3.14`).
  final String Function(double value)? valueFormatter;
}

/// Which axes pan and zoom apply to.
enum PanZoomAxis {
  /// Horizontal only. The default.
  x,

  /// Vertical only.
  y,

  /// Both axes.
  both,
}

/// Keyboard modifier required for scroll-wheel zoom.
enum ScrollZoomModifier {
  /// Zoom on plain scroll. The chart claims scroll events, so avoid this
  /// inside scrollable pages.
  none,

  /// Zoom only while Ctrl (or ⌘ on macOS) is held — plain scroll keeps
  /// scrolling the page. The default.
  ctrlOrCmd,
}

/// Pan and zoom of the visible domain.
///
/// Drag pans; pinch (touch or trackpad) and modifier+scroll-wheel zoom;
/// double-tap resets. The window is clamped to the data domain with
/// rubber-band resistance at the edges. Pair with a `ChartController` for
/// programmatic control.
final class PanZoom extends ChartInteraction {
  /// Creates a pan/zoom configuration.
  const PanZoom({
    this.axis = PanZoomAxis.x,
    this.scrollZoomModifier = ScrollZoomModifier.ctrlOrCmd,
    this.maxZoom = 50,
  });

  /// Which axes respond.
  final PanZoomAxis axis;

  /// Modifier gating scroll-wheel zoom.
  final ScrollZoomModifier scrollZoomModifier;

  /// Maximum zoom-in factor relative to the full data domain.
  final double maxZoom;
}
