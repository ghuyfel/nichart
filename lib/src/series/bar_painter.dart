import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

import '../core/coordinate_space.dart';
import '../style/chart_theme.dart';
import 'bar_style.dart';
import 'series_painter.dart';

/// Pixel gap between stacked bar segments.
const double _kStackGap = 2;

/// Fraction of a band left as padding (split between both sides).
const double _kBandPadding = 0.2;

/// One bar segment in domain space, prepared by the chart's renderer.
///
/// For grouped bars [from] is the baseline (0) and [to] the value; for
/// stacked bars they are the cumulative range this series occupies at
/// that x position.
@immutable
class BarEntry {
  /// Creates a bar segment.
  const BarEntry({
    required this.x,
    required this.from,
    required this.to,
    required this.index,
    this.dataEndRounded = true,
    this.insetBase = false,
  });

  /// Domain x position (category index, numeric value, or epoch millis).
  final double x;

  /// Segment start in y-domain units (baseline side).
  final double from;

  /// Segment end in y-domain units (data side).
  final double to;

  /// Index of the datum within its series (used for per-bar emphasis).
  final int index;

  /// Whether the data end gets the corner radius — true for grouped bars
  /// and only the outermost segment of a stack.
  final bool dataEndRounded;

  /// Whether the baseline side is inset by the 2 px stack gap — true for
  /// every stacked segment except the one touching the baseline.
  final bool insetBase;
}

/// Paints a `BarSeries` as rounded-data-end bars.
class BarSeriesPainter extends SeriesPainter {
  /// Creates a painter for prepared bar [entries].
  ///
  /// [slotIndex]/[slotCount] position this series within its band when
  /// bar series are grouped; [domainBand] is the band width in x-domain
  /// units (1.0 for category indices, the smallest x gap otherwise).
  /// [morphFrom], when set, holds previous-data segments aligned
  /// index-wise with [entries] for morph interpolation.
  const BarSeriesPainter({
    required this.entries,
    required this.style,
    required this.seriesColor,
    required this.slotIndex,
    required this.slotCount,
    required this.domainBand,
    this.emphasizedIndex,
    this.opacityFactor = 1,
    this.morphFrom,
  });

  /// Bar segments in domain space.
  final List<BarEntry> entries;

  /// Previous-data segments aligned to [entries], or null when not
  /// morphing.
  final List<BarEntry>? morphFrom;

  /// The visual style to paint with.
  final BarStyle style;

  /// Resolved base color for this series.
  final Color seriesColor;

  /// This series' slot within the band (grouped arrangement).
  final int slotIndex;

  /// Total slots sharing the band.
  final int slotCount;

  /// Band width in x-domain units.
  final double domainBand;

  /// When set, bars at other indices are muted to 30% opacity.
  final int? emphasizedIndex;

  /// Opacity multiplier for the whole series (1 = full).
  final double opacityFactor;

  @override
  void paint(
    Canvas canvas,
    CoordinateSpace space,
    ChartTheme theme, {
    double entrance = 1,
    double morph = 1,
  }) {
    if (entries.isEmpty || entrance <= 0) return;

    final bandPixels = (space.xToPixel(domainBand) - space.xToPixel(0)).abs();
    if (bandPixels <= 0) return;
    final slotWidth = bandPixels * (1 - _kBandPadding) / slotCount;
    final thickness = math.min(style.maxThickness, slotWidth);

    var base = style.color ?? seriesColor;
    if (opacityFactor < 1) {
      base = base.withValues(alpha: base.a * opacityFactor);
    }
    final muted = base.withValues(alpha: base.a * style.mutedOpacity);

    // Entrance stagger: each bar starts slightly after the previous one.
    final n = entries.length;
    final delay = n <= 1 ? 0.0 : (0.5 / n).clamp(0.0, 0.06);
    final span = 1 - delay * (n - 1);

    final source = morphFrom;
    for (var k = 0; k < entries.length; k++) {
      final e = entries[k];
      if (!e.x.isFinite || !e.from.isFinite || !e.to.isFinite) continue;

      var from = e.from;
      var to = e.to;
      if (source != null && morph < 1 && k < source.length) {
        from = source[k].from + (from - source[k].from) * morph;
        to = source[k].to + (to - source[k].to) * morph;
      }
      if (entrance < 1) {
        // Grow from the baseline; scaling both ends keeps stacked
        // segments attached while the stack rises.
        final t = ((entrance - delay * e.index) / span).clamp(0.0, 1.0);
        if (t <= 0) continue;
        from *= t;
        to *= t;
      }
      if (from == to) continue;

      final cx =
          space.xToPixel(e.x) + (slotIndex - (slotCount - 1) / 2) * slotWidth;
      final positive = to >= from;
      var top = math.min(space.yToPixel(from), space.yToPixel(to));
      var bottom = math.max(space.yToPixel(from), space.yToPixel(to));
      if (e.insetBase) {
        // 2 px gap toward the data end; the background (surface) shows
        // through — never a stroke.
        if (positive) {
          bottom -= _kStackGap;
        } else {
          top += _kStackGap;
        }
      }
      if (bottom - top < 0.5) continue;

      final rect =
          Rect.fromLTRB(cx - thickness / 2, top, cx + thickness / 2, bottom);
      final radius = Radius.circular(math.min(
        style.cornerRadius,
        math.min(thickness / 2, bottom - top),
      ));

      final RRect rrect;
      if (!e.dataEndRounded) {
        rrect = RRect.fromRectAndCorners(rect);
      } else if (positive) {
        rrect =
            RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius);
      } else {
        rrect = RRect.fromRectAndCorners(rect,
            bottomLeft: radius, bottomRight: radius);
      }

      final emphasized = emphasizedIndex;
      final color = emphasized == null || e.index == emphasized ? base : muted;
      canvas.drawRRect(rrect, Paint()..color = color);
    }
  }
}
