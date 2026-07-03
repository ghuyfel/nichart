import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/coordinate_space.dart';
import '../scales/scale.dart';
import '../series/area_fill.dart';
import '../series/bar_painter.dart';
import '../series/bar_style.dart';
import '../series/line_painter.dart';
import '../series/line_style.dart';
import '../style/chart_theme.dart';

/// Default sparkline size under unbounded constraints.
const Size _kDefaultSparklineSize = Size(160, 40);

enum _SparklineMode { line, bars }

/// An axis-less mini chart for stat cards, table cells and list tiles.
///
/// Renders a smooth gradient-filled line (or mini bars) from a plain list
/// of values — no axes, no labels, no interaction, one line of code:
///
/// ```dart
/// Sparkline(data: last30Days)
/// Sparkline.bars(data: weekCounts, emphasizeLast: true)
/// ```
///
/// The color defaults to the first palette color of the ambient
/// [ChartTheme]; size defaults to 160×40 when unconstrained.
class Sparkline extends StatelessWidget {
  /// Creates a line sparkline over [data] (drawn in index order).
  const Sparkline({
    super.key,
    required this.data,
    this.color,
    this.strokeWidth = 1.5,
    this.smooth = true,
    this.area = const AreaFill.gradient(opacity: 0.18),
    this.theme,
    this.semanticLabel,
  })  : _mode = _SparklineMode.line,
        emphasizeLast = false;

  /// Creates a mini bar sparkline over [data].
  ///
  /// With [emphasizeLast] true the last bar renders at full color and the
  /// rest are muted — the "this week so far" pattern.
  const Sparkline.bars({
    super.key,
    required this.data,
    this.color,
    this.emphasizeLast = false,
    this.theme,
    this.semanticLabel,
  })  : _mode = _SparklineMode.bars,
        strokeWidth = 0,
        smooth = false,
        area = null;

  final _SparklineMode _mode;

  /// The values to draw, in order.
  final List<double> data;

  /// Explicit color; defaults to the theme palette's first color.
  final Color? color;

  /// Stroke width of the line variant.
  final double strokeWidth;

  /// Whether the line variant uses monotone smoothing.
  final bool smooth;

  /// Fill under the line variant, or null for none.
  final AreaFill? area;

  /// Whether the bar variant highlights its last bar.
  final bool emphasizeLast;

  /// Explicit theme override; defaults to the ambient chart theme.
  final ChartTheme? theme;

  /// Override for the accessibility label. Defaults to 'Sparkline'.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Sparkline',
      child: _RawSparkline(
        values: data,
        mode: _mode,
        theme: theme ?? ChartTheme.of(context),
        color: color,
        strokeWidth: strokeWidth,
        smooth: smooth,
        area: area,
        emphasizeLast: emphasizeLast,
      ),
    );
  }
}

class _RawSparkline extends LeafRenderObjectWidget {
  const _RawSparkline({
    required this.values,
    required this.mode,
    required this.theme,
    required this.color,
    required this.strokeWidth,
    required this.smooth,
    required this.area,
    required this.emphasizeLast,
  });

  final List<double> values;
  final _SparklineMode mode;
  final ChartTheme theme;
  final Color? color;
  final double strokeWidth;
  final bool smooth;
  final AreaFill? area;
  final bool emphasizeLast;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSparkline(
      values: values,
      mode: mode,
      theme: theme,
      color: color,
      strokeWidth: strokeWidth,
      smooth: smooth,
      area: area,
      emphasizeLast: emphasizeLast,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSparkline renderObject,
  ) {
    renderObject
      ..values = values
      ..mode = mode
      ..theme = theme
      ..color = color
      ..strokeWidth = strokeWidth
      ..smooth = smooth
      ..area = area
      ..emphasizeLast = emphasizeLast;
  }
}

class _RenderSparkline extends RenderBox {
  _RenderSparkline({
    required List<double> values,
    required _SparklineMode mode,
    required ChartTheme theme,
    required Color? color,
    required double strokeWidth,
    required bool smooth,
    required AreaFill? area,
    required bool emphasizeLast,
  })  : _values = values,
        _mode = mode,
        _theme = theme,
        _color = color,
        _strokeWidth = strokeWidth,
        _smooth = smooth,
        _area = area,
        _emphasizeLast = emphasizeLast;

  List<double> _values;
  set values(List<double> value) {
    if (identical(value, _values)) return;
    _values = value;
    markNeedsPaint();
  }

  _SparklineMode _mode;
  set mode(_SparklineMode value) {
    if (value == _mode) return;
    _mode = value;
    markNeedsPaint();
  }

  ChartTheme _theme;
  set theme(ChartTheme value) {
    if (value == _theme) return;
    _theme = value;
    markNeedsPaint();
  }

  Color? _color;
  set color(Color? value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double _strokeWidth;
  set strokeWidth(double value) {
    if (value == _strokeWidth) return;
    _strokeWidth = value;
    markNeedsPaint();
  }

  bool _smooth;
  set smooth(bool value) {
    if (value == _smooth) return;
    _smooth = value;
    markNeedsPaint();
  }

  AreaFill? _area;
  set area(AreaFill? value) {
    if (value == _area) return;
    _area = value;
    markNeedsPaint();
  }

  bool _emphasizeLast;
  set emphasizeLast(bool value) {
    if (value == _emphasizeLast) return;
    _emphasizeLast = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : _kDefaultSparklineSize.width;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : _kDefaultSparklineSize.height;
    return constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final values = _values;
    if (values.isEmpty) return;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (!v.isFinite) continue;
      min = math.min(min, v);
      max = math.max(max, v);
    }
    final color = _color ?? _theme.palette.first;

    switch (_mode) {
      case _SparklineMode.line:
        if (min == max) {
          min -= 1;
          max += 1;
        }
        // Anchor the gradient at the data minimum, with a little vertical
        // breathing room so the stroke never clips.
        final pad = (max - min) * 0.05;
        final space = CoordinateSpace(
          plotArea: (Offset.zero & size).deflate(_strokeWidth + 1),
          xScale: NumericScale(
            min: 0,
            max: math.max(1, values.length - 1).toDouble(),
          ),
          yScale: NumericScale(min: min - pad, max: max + pad),
        );
        LineSeriesPainter(
          points: <Offset>[
            for (var i = 0; i < values.length; i++)
              Offset(i.toDouble(), values[i]),
          ],
          style: LineStyle(
            strokeWidth: _strokeWidth,
            interpolation:
                _smooth ? LineInterpolation.monotone : LineInterpolation.linear,
            area: _area,
          ),
          seriesColor: color,
        ).paint(canvas, space, _theme);
      case _SparklineMode.bars:
        final space = CoordinateSpace(
          plotArea: Offset.zero & size,
          xScale: NumericScale(min: -0.5, max: values.length - 0.5),
          yScale: NumericScale(
            min: math.min(0, min),
            max: math.max(math.min(0, min) + 1, math.max(0, max)),
          ),
        );
        BarSeriesPainter(
          entries: <BarEntry>[
            for (var i = 0; i < values.length; i++)
              BarEntry(x: i.toDouble(), from: 0, to: values[i], index: i),
          ],
          style: const BarStyle(cornerRadius: 2),
          seriesColor: color,
          slotIndex: 0,
          slotCount: 1,
          domainBand: 1,
          emphasizedIndex: _emphasizeLast ? values.length - 1 : null,
        ).paint(canvas, space, _theme);
    }
    canvas.restore();
  }
}
