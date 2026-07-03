import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../animation/chart_animation.dart';
import '../data/data_point.dart';
import '../interaction/chart_interaction.dart';
import '../series/donut_style.dart';
import '../series/series.dart';
import '../style/chart_theme.dart';
import 'chart.dart';

/// A donut chart with an optional hero widget in the cutout.
///
/// Sugar over `Chart(series: [DonutSeries(...)])` plus a centered overlay
/// — the classic "big number in a ring" composition:
///
/// ```dart
/// DonutChart(
///   data: const [
///     CategoryPoint('Direct', 44),
///     CategoryPoint('Search', 31),
///     CategoryPoint('Referral', 25),
///   ],
///   center: Text('84%', style: Theme.of(context).textTheme.headlineMedium),
/// )
/// ```
///
/// For custom data types, use `Chart` with a [DonutSeries] directly.
class DonutChart extends StatelessWidget {
  /// Creates a donut chart over [data].
  const DonutChart({
    super.key,
    required this.data,
    this.center,
    this.style = const DonutStyle(),
    this.theme,
    this.animation = const ChartAnimation(),
    this.interactions = const [ChartTooltip()],
    this.semanticLabel,
  });

  /// The segments, in display order. Palette colors are assigned in the
  /// same order — fold long tails into an "Other" segment rather than
  /// exceeding the 8-color palette.
  final List<CategoryPoint> data;

  /// Widget rendered in the cutout (a KPI number, an icon, …).
  ///
  /// The slot is constrained to the square inscribed in the cutout hole
  /// and scales its content down when it would not fit, so the center
  /// never collides with the ring. Shrink the ring itself with
  /// [DonutStyle.radius] when the content needs more room.
  final Widget? center;

  /// Visual style: cutout, gaps, corner radius, start angle.
  final DonutStyle style;

  /// Explicit theme override; defaults to the ambient chart theme.
  final ChartTheme? theme;

  /// Motion configuration; the entrance is a clockwise sweep.
  final ChartAnimation animation;

  /// Interaction behaviors. Defaults to `[ChartTooltip()]` — hovering (or
  /// long-pressing) a segment shows its value and share.
  final List<ChartInteraction> interactions;

  /// Override for the accessibility label. When null a description is
  /// composed from the segment names and values.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final chart = Chart(
      series: [DonutSeries<CategoryPoint>(data: data, style: style)],
      theme: theme,
      animation: animation,
      interactions: interactions,
      semanticLabel: semanticLabel,
    );
    if (center == null) return chart;
    return Stack(
      children: [
        chart, // Non-positioned: the chart sizes the stack.
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: style.cutout <= 0
                  // A pie has no hole — overlay the widget as-is.
                  ? center
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Mirror the painter's geometry: the chart's radial
                        // plot is the box deflated by 4 px on each side.
                        final maxOuter = math.max(
                          1.0,
                          (math.min(constraints.maxWidth,
                                      constraints.maxHeight) -
                                  8) /
                              2,
                        );
                        final radius = style.radius;
                        final outer = radius == null
                            ? maxOuter
                            : radius.clamp(1.0, maxOuter);
                        final inner = outer * style.cutout;
                        // Square inscribed in the hole, with a little
                        // margin so text clears the ring's inner edge.
                        final side = math.max(
                          0.0,
                          inner * math.sqrt2 * 0.92,
                        );
                        return SizedBox(
                          width: side,
                          height: side,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: center,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
