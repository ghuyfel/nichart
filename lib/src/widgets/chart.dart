import 'package:flutter/widgets.dart';

import '../animation/chart_animation.dart';
import '../axes/axis.dart';
import '../core/chart_layers.dart';
import '../core/chart_scene.dart';
import '../data/data_point.dart';
import '../interaction/chart_controller.dart';
import '../interaction/chart_interaction.dart';
import '../interaction/hover_info.dart';
import '../scales/tick_generator.dart';
import '../series/line_style.dart';
import '../series/series.dart';
import '../style/chart_theme.dart';
import '../style/emphasis.dart';

/// A beautiful, animated, interactive, theme-aware chart.
///
/// Renders via custom render objects — hit testing and gestures live on
/// the render box, not in widget-tree gesture detectors — split into three
/// compositor-isolated layers (grid/axes, series, interaction), so moving
/// the crosshair never repaints the series. Adapts to light/dark mode
/// automatically, animates in on first layout, morphs smoothly when data
/// changes, and shows a crosshair + tooltip on hover/scrub out of the box:
///
/// ```dart
/// Chart.line(data: [DataPoint(0, 2), DataPoint(1, 5), DataPoint(2, 3)])
/// Chart(series: [BarSeries(data: weekCounts)]) // category axis inferred
/// ```
///
/// Or fully composed:
///
/// ```dart
/// Chart(
///   axes: const ChartAxes.cartesian(x: TimeAxis(), y: NumericAxis(label: 'Users')),
///   series: [
///     LineSeries(data: thisPeriod, style: LineStyle.smooth(area: AreaFill.gradient())),
///     LineSeries(data: lastPeriod, style: const LineStyle.context()),
///   ],
///   interactions: const [Crosshair(), ChartTooltip(), PanZoom()],
/// )
/// ```
class Chart extends StatelessWidget {
  /// Creates a chart drawing [series] on the given [axes].
  const Chart({
    super.key,
    required this.series,
    this.axes = const ChartAxes.cartesian(),
    this.theme,
    this.emphasis,
    this.animation = const ChartAnimation(),
    this.interactions = const [Crosshair(), ChartTooltip()],
    this.controller,
    this.semanticLabel,
  });

  /// One-line convenience: a single line series over [data].
  ///
  /// ```dart
  /// Chart.line(data: points)
  /// ```
  Chart.line({
    Key? key,
    required List<DataPoint> data,
    String? label,
    Color? color,
    LineStyle style = const LineStyle(),
    ChartAxes axes = const ChartAxes.cartesian(),
    ChartTheme? theme,
    ChartAnimation animation = const ChartAnimation(),
    List<ChartInteraction> interactions = const [Crosshair(), ChartTooltip()],
    ChartController? controller,
    String? semanticLabel,
  }) : this(
          key: key,
          series: <Series<Object?>>[
            LineSeries<DataPoint>(
              data: data,
              label: label,
              color: color,
              style: style,
            ),
          ],
          axes: axes,
          theme: theme,
          animation: animation,
          interactions: interactions,
          controller: controller,
          semanticLabel: semanticLabel,
        );

  /// The series to draw, painted in list order. Palette colors are
  /// assigned by position, in fixed order.
  final List<Series<Object?>> series;

  /// Axis configuration. Defaults to fully automatic numeric axes, with a
  /// [CategoryAxis] substituted automatically for categorical data.
  final ChartAxes axes;

  /// Explicit theme override. When null the theme resolves via
  /// [ChartTheme.of] — a [ChartThemeScope] if present, otherwise derived
  /// from the ambient [Theme]'s color scheme.
  final ChartTheme? theme;

  /// Highlights one series at full saturation and mutes the rest.
  final SeriesEmphasis? emphasis;

  /// Motion configuration: entrance animation and data-change morphing.
  /// Respects the platform reduced-motion setting automatically.
  final ChartAnimation animation;

  /// Interaction behaviors. Defaults to `[Crosshair(), ChartTooltip()]` —
  /// hover/scrub inspection works out of the box. Add [PanZoom] for
  /// drag-pan, pinch/scroll zoom and double-tap reset; pass `const []` to
  /// disable interaction entirely.
  final List<ChartInteraction> interactions;

  /// Programmatic control of the visible domain (used with [PanZoom]).
  final ChartController? controller;

  /// Override for the accessibility label read by screen readers. When
  /// null a description is composed from the chart type and series labels
  /// (and, for donuts, segment names and values).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Crosshair? crosshair;
    ChartTooltip? tooltip;
    PanZoom? panZoom;
    for (final interaction in interactions) {
      switch (interaction) {
        case Crosshair():
          crosshair = interaction;
        case ChartTooltip():
          tooltip = interaction;
        case PanZoom():
          panZoom = interaction;
      }
    }
    return Semantics(
      container: true,
      label: semanticLabel ?? _describeChart(),
      child: _AnimatedChart(
        theme: theme ?? ChartTheme.of(context),
        axes: axes,
        series: series,
        textDirection: Directionality.of(context),
        emphasis: emphasis,
        animation: animation,
        crosshair: crosshair,
        tooltip: tooltip,
        panZoom: panZoom,
        controller: controller,
      ),
    );
  }

  /// Composes a screen-reader description from the series.
  String _describeChart() {
    if (series.isEmpty) return 'Empty chart';
    final first = series.first;
    if (first is DonutSeries && first.hasCategoryAccessor) {
      final segments = first.resolveCategoryPoints();
      return 'Donut chart: ${segments.map(
            (s) => '${s.$1} ${formatTickLabel(s.$2, 0.01)}',
          ).join(', ')}';
    }
    final kind = switch (first) {
      LineSeries() => 'Line chart',
      AreaSeries() => 'Area chart',
      BarSeries() => 'Bar chart',
      ScatterSeries() => 'Scatter chart',
      DonutSeries() => 'Donut chart',
    };
    final labels = <String>[
      for (final s in series)
        if (s.label != null) s.label!,
    ];
    if (labels.isEmpty) {
      return series.length == 1 ? kind : '$kind with ${series.length} series';
    }
    return '$kind: ${labels.join(', ')}';
  }
}

/// Owns the [ChartScene], the entrance/morph tickers and the hover
/// notifier. Animation ticks and hover moves reach the scene's layers as
/// targeted repaints — never widget rebuilds; the only thing that ever
/// rebuilds is the optional builder tooltip.
class _AnimatedChart extends StatefulWidget {
  const _AnimatedChart({
    required this.theme,
    required this.axes,
    required this.series,
    required this.textDirection,
    required this.emphasis,
    required this.animation,
    required this.crosshair,
    required this.tooltip,
    required this.panZoom,
    required this.controller,
  });

  final ChartTheme theme;
  final ChartAxes axes;
  final List<Series<Object?>> series;
  final TextDirection textDirection;
  final SeriesEmphasis? emphasis;
  final ChartAnimation animation;
  final Crosshair? crosshair;
  final ChartTooltip? tooltip;
  final PanZoom? panZoom;
  final ChartController? controller;

  @override
  State<_AnimatedChart> createState() => _AnimatedChartState();
}

class _AnimatedChartState extends State<_AnimatedChart>
    with TickerProviderStateMixin {
  final ChartScene _scene = ChartScene();
  late final AnimationController _entranceController;
  late final AnimationController _morphController;
  late final CurvedAnimation _entrance;
  late final CurvedAnimation _morph;
  final ValueNotifier<ChartHoverInfo?> _hoverInfo = ValueNotifier(null);
  var _reducedMotion = false;
  var _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    final config = widget.animation;
    _entranceController = AnimationController(
      vsync: this,
      duration: config.duration,
    );
    _morphController = AnimationController(
      vsync: this,
      duration: config.morphDuration,
      value: 1,
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: config.curve,
    );
    _morph = CurvedAnimation(parent: _morphController, curve: config.curve);
    _scene
      ..entranceAnimation = _entrance
      ..morphAnimation = _morph;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_entranceStarted) {
      _entranceStarted = true;
      if (widget.animation.entrance && !_reducedMotion) {
        _entranceController.forward();
      } else {
        _entranceController.value = 1;
      }
    }
  }

  @override
  void didUpdateWidget(_AnimatedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final config = widget.animation;
    _entranceController.duration = config.duration;
    _morphController.duration = config.morphDuration;
    if (!identical(oldWidget.series, widget.series)) {
      if (config.morph && !_reducedMotion) {
        // Capture what is currently on screen (mid-morph included) as the
        // morph source *before* resetting the controller. The scene still
        // holds the old series at this point.
        _scene.prepareMorph();
        _morphController.value = 0;
        _morphController.forward();
      } else {
        _morphController.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _hoverInfo.dispose();
    _scene.dispose();
    _entrance.dispose();
    _morph.dispose();
    _entranceController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltipBuilder = widget.tooltip?.builder;
    _scene
      ..theme = widget.theme
      ..axes = widget.axes
      ..series = widget.series
      ..textDirection = widget.textDirection
      ..emphasis = widget.emphasis
      ..crosshair = widget.crosshair
      ..tooltip = widget.tooltip
      ..panZoom = widget.panZoom
      ..controller = widget.controller
      ..onHoverChanged =
          tooltipBuilder == null ? null : (info) => _hoverInfo.value = info;
    return ChartViewport(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ChartLayerWidget(scene: _scene, kind: ChartLayerKind.background),
          ChartLayerWidget(scene: _scene, kind: ChartLayerKind.data),
          ChartInteractionWidget(scene: _scene),
          if (tooltipBuilder != null)
            ValueListenableBuilder<ChartHoverInfo?>(
              valueListenable: _hoverInfo,
              builder: (context, info, _) {
                if (info == null) return const SizedBox.shrink();
                return Positioned(
                  left: info.xPixel + 12,
                  top: info.position.dy - 12,
                  child: IgnorePointer(child: tooltipBuilder(context, info)),
                );
              },
            ),
        ],
      ),
    );
  }
}
