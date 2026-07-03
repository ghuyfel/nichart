import 'package:flutter/widgets.dart';

import '../series/series.dart';
import '../style/chart_theme.dart';

/// A legend for a chart's series (or a donut's segments).
///
/// Resolves labels and colors exactly like the chart does — palette by
/// position, explicit series colors and context-gray styles respected —
/// so passing the same `series` list keeps chart and legend in sync:
///
/// ```dart
/// Column(children: [
///   ChartLegend(series: mySeries),
///   Expanded(child: Chart(series: mySeries)),
/// ])
/// ```
///
/// For a single [DonutSeries], the legend lists its segments instead.
class ChartLegend extends StatelessWidget {
  /// Creates a legend describing [series].
  const ChartLegend({
    super.key,
    required this.series,
    this.theme,
    this.textStyle,
    this.spacing = 16,
    this.runSpacing = 8,
    this.alignment = WrapAlignment.start,
  });

  /// The series to describe — typically the same list passed to the chart.
  final List<Series<Object?>> series;

  /// Explicit theme override; defaults to the ambient chart theme.
  final ChartTheme? theme;

  /// Label style; defaults to the theme's axis label style.
  final TextStyle? textStyle;

  /// Horizontal gap between legend items.
  final double spacing;

  /// Vertical gap between wrapped rows.
  final double runSpacing;

  /// How items are placed along each row.
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final resolvedTheme = theme ?? ChartTheme.of(context);
    final style = textStyle ?? resolvedTheme.axisLabelStyle;
    final palette = resolvedTheme.palette;

    final items = <(String, Color)>[];
    final first = series.firstOrNull;
    if (series.length == 1 && first is DonutSeries) {
      // Donut: one item per segment, palette in display order.
      if (first.hasCategoryAccessor) {
        final segments = first.resolveCategoryPoints();
        for (var i = 0; i < segments.length; i++) {
          items.add((segments[i].$1, palette[i % palette.length]));
        }
      } else {
        for (var i = 0; i < first.data.length; i++) {
          items.add(('Segment ${i + 1}', palette[i % palette.length]));
        }
      }
    } else {
      for (var i = 0; i < series.length; i++) {
        final s = series[i];
        final base = s.color ?? palette[i % palette.length];
        final color = switch (s) {
          LineSeries(:final style) => style.color ??
              (style.isContext ? resolvedTheme.contextColor : base),
          AreaSeries(:final style) => style.color ??
              (style.isContext ? resolvedTheme.contextColor : base),
          BarSeries(:final style) => style.color ?? base,
          ScatterSeries(:final style) => style.color ?? base,
          DonutSeries() => base,
        };
        items.add((s.label ?? 'Series ${i + 1}', color));
      }
    }

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (label, color) in items)
          Semantics(
            label: label,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label, style: style),
              ],
            ),
          ),
      ],
    );
  }
}
