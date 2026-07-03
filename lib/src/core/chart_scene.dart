// The chart's layout/paint/gesture authority. Internal — the public entry
// point is the Chart widget in widgets/chart.dart.
//
// A ChartScene is shared by three thin render objects (see
// chart_layers.dart), each a repaint boundary:
//
//   static layer      grid, axis lines, tick labels, titles
//   data layer        series
//   interaction layer crosshair, hover markers, tooltip
//
// The scene fires `layoutChanged` when everything must re-lay out
// (config/domain-window changes), `dataChanged` on animation ticks
// (static + data repaint), and `interactionChanged` on hover moves —
// which repaint ONLY the interaction layer, so moving the crosshair never
// re-rasterizes the series.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../axes/axis.dart';
import '../data/lttb.dart';
import '../interaction/chart_controller.dart';
import '../interaction/chart_interaction.dart';
import '../interaction/hover_info.dart';
import '../scales/category_scale.dart';
import '../scales/scale.dart';
import '../scales/tick_generator.dart';
import '../scales/time_scale.dart';
import '../series/bar_painter.dart';
import '../series/bar_style.dart';
import '../series/donut_painter.dart';
import '../series/line_painter.dart';
import '../series/scatter_painter.dart';
import '../series/series.dart';
import '../series/series_painter.dart';
import '../style/chart_theme.dart';
import '../style/emphasis.dart';
import 'coordinate_space.dart';

/// Fallback size when the parent gives unbounded constraints.
const Size kDefaultChartSize = Size(400, 225); // 16:9

/// Gap between the y tick labels and the plot area.
const double _kYLabelGap = 10;

/// Gap between the plot area and the x tick labels.
const double _kXLabelGap = 8;

/// Minimum horizontal gap between adjacent x tick labels.
const double _kXLabelMinSpacing = 12;

/// Headroom above the plot so the topmost grid label never clips.
const double _kTopInset = 12;

/// Hover marker geometry (spec: ≥8 px marker, 2 px surface ring).
const double _kMarkerRadius = 4.5;
const double _kMarkerRingWidth = 2.0;

/// Fraction of an edge overshoot that survives rubber-band resistance.
const double _kRubberBandFactor = 0.3;

class _Pulse extends ChangeNotifier {
  void pulse() => notifyListeners();
}

class _TickLabel {
  _TickLabel(this.value, this.painter);

  final double value;
  final TextPainter painter;
}

class _TooltipRow {
  _TooltipRow(this.color, this.label, this.value);

  final Color color;
  final TextPainter label;
  final TextPainter value;

  void dispose() {
    label.dispose();
    value.dispose();
  }
}

class _TooltipLayout {
  _TooltipLayout(this.header, this.rows);

  static const double pad = 10;
  static const double chip = 8;
  static const double chipGap = 6;
  static const double labelValueGap = 14;
  static const double rowGap = 5;

  final TextPainter header;
  final List<_TooltipRow> rows;

  Size get size {
    var width = header.width;
    var height = header.height;
    for (final row in rows) {
      width = math.max(
        width,
        chip + chipGap + row.label.width + labelValueGap + row.value.width,
      );
      height += rowGap + math.max(row.label.height, chip);
    }
    return Size(width + pad * 2, height + pad * 2);
  }

  void dispose() {
    header.dispose();
    for (final row in rows) {
      row.dispose();
    }
  }
}

/// Computes chart layout once per (size, config) revision and paints it as
/// three independent layers. Owns hover state, gesture recognizers and
/// pan/zoom windows.
class ChartScene {
  /// Creates an empty scene; configure via the setters.
  ChartScene();

  /// Fires when all layers must re-lay out (config or domain change).
  Listenable get layoutChanged => _layoutChanged;
  final _Pulse _layoutChanged = _Pulse();

  /// Fires on animation ticks — static and data layers repaint.
  Listenable get dataChanged => _dataChanged;
  final _Pulse _dataChanged = _Pulse();

  /// Fires on hover changes — only the interaction layer repaints.
  Listenable get interactionChanged => _interactionChanged;
  final _Pulse _interactionChanged = _Pulse();

  /// Notified when the hover/crosshair state changes (used by widget-built
  /// tooltips). Not a repaint trigger — painting reads state directly.
  void Function(ChartHoverInfo? info)? onHoverChanged;

  void _invalidateLayout() {
    _layoutDirty = true;
    _layoutChanged.pulse();
  }

  void _invalidateData() {
    _dataDirty = true;
    _invalidateLayout();
  }

  ChartTheme? _theme;

  /// The resolved theme to paint with.
  ChartTheme get theme => _theme!;
  set theme(ChartTheme value) {
    if (value == _theme) return;
    _theme = value;
    _invalidateLayout();
  }

  ChartAxes _axes = const ChartAxes.cartesian();

  /// Axis configuration.
  ChartAxes get axes => _axes;
  set axes(ChartAxes value) {
    if (identical(value, _axes)) return;
    _axes = value;
    _invalidateData();
  }

  List<Series<Object?>> _series = const [];

  /// The series to draw, in paint order.
  List<Series<Object?>> get series => _series;
  set series(List<Series<Object?>> value) {
    if (identical(value, _series)) return;
    _series = value;
    _setHover(null);
    _invalidateData();
  }

  TextDirection _textDirection = TextDirection.ltr;

  /// Ambient text direction for label layout.
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _invalidateLayout();
  }

  SeriesEmphasis? _emphasis;

  /// Highlight-one-mute-the-rest configuration, or null for none.
  SeriesEmphasis? get emphasis => _emphasis;
  set emphasis(SeriesEmphasis? value) {
    if (value == _emphasis) return;
    _emphasis = value;
    _invalidateLayout();
  }

  Animation<double>? _entranceAnimation;

  /// Eased entrance progress (0 → 1, null = settled).
  Animation<double>? get entranceAnimation => _entranceAnimation;
  set entranceAnimation(Animation<double>? value) {
    if (identical(value, _entranceAnimation)) return;
    _entranceAnimation?.removeListener(_onAnimationTick);
    _entranceAnimation = value;
    value?.addListener(_onAnimationTick);
    _dataChanged.pulse();
  }

  Animation<double>? _morphAnimation;

  /// Eased data-morph progress (0 → 1, null = settled).
  Animation<double>? get morphAnimation => _morphAnimation;
  set morphAnimation(Animation<double>? value) {
    if (identical(value, _morphAnimation)) return;
    _morphAnimation?.removeListener(_onAnimationTick);
    _morphAnimation = value;
    value?.addListener(_onAnimationTick);
    _dataChanged.pulse();
  }

  void _onAnimationTick() => _dataChanged.pulse();

  Crosshair? _crosshair;

  /// Crosshair configuration, or null when disabled.
  Crosshair? get crosshair => _crosshair;
  set crosshair(Crosshair? value) {
    if (identical(value, _crosshair)) return;
    _crosshair = value;
    if (value == null && _tooltip == null) _setHover(null);
    _interactionChanged.pulse();
  }

  ChartTooltip? _tooltip;

  /// Tooltip configuration, or null when disabled.
  ChartTooltip? get tooltip => _tooltip;
  set tooltip(ChartTooltip? value) {
    if (identical(value, _tooltip)) return;
    _tooltip = value;
    if (value == null && _crosshair == null) _setHover(null);
    _interactionChanged.pulse();
  }

  PanZoom? _panZoom;

  /// Pan/zoom configuration, or null when disabled.
  PanZoom? get panZoom => _panZoom;
  set panZoom(PanZoom? value) {
    if (identical(value, _panZoom)) return;
    _panZoom = value;
    _interactionChanged.pulse();
  }

  ChartController? _controller;

  /// Programmatic domain control, or null.
  ChartController? get controller => _controller;
  set controller(ChartController? value) {
    if (identical(value, _controller)) return;
    _controller?.removeListener(_onControllerChanged);
    _controller = value;
    value?.addListener(_onControllerChanged);
    if (value != null) {
      _xWindow = value.xDomain;
      _yWindow = value.yDomain;
    }
    _invalidateLayout();
  }

  void _onControllerChanged() {
    final c = _controller;
    if (c == null) return;
    _xWindow = c.xDomain;
    _yWindow = c.yDomain;
    _invalidateLayout();
  }

  double get _entranceT => (_entranceAnimation?.value ?? 1).clamp(0.0, 1.0);
  double get _morphT => (_morphAnimation?.value ?? 1).clamp(0.0, 1.0);

  /// Whether any interaction behavior is enabled.
  bool get interactive =>
      _crosshair != null || _tooltip != null || _panZoom != null;

  // Layout memoization.
  bool _layoutDirty = true;
  bool _dataDirty = true;
  Size _layoutSize = Size.zero;

  // Cached layout artifacts, rebuilt in _layoutChart.
  CoordinateSpace? _space;
  List<SeriesPainter> _painters = const [];
  List<_TickLabel> _xLabels = const [];
  List<_TickLabel> _yLabels = const [];
  int _xLabelStride = 1;
  TextPainter? _xTitle;
  TextPainter? _yTitle;
  List<Color> _seriesColors = const [];
  String Function(double)? _hoverXFormatter;

  // Data-derived state cached across pan/zoom relayouts, rebuilt only when
  // series/axes change (_prepareData). Resolving 100k points per pan frame
  // would sink 60 fps; this cache is what keeps pans cheap.
  List<List<Offset>> _resolved = const [];
  List<bool> _xSorted = const [];
  List<String>? _categories;
  List<int> _barIndices = const [];
  bool _stacked = false;
  double _domainBand = 1;
  Map<int, List<BarEntry>> _barEntries = const {};
  double? _stackMin, _stackMax;
  double? _xMin, _xMax, _yMin, _yMax;
  bool _zeroAnchored = false;

  // Radial (donut/pie) mode: no axes or grid; hover hits segments.
  bool _radial = false;
  List<String> _donutLabels = const [];
  List<double> _donutValues = const [];
  List<double>? _donutAlignedSource;
  Map<String, double>? _donutMorphSource;

  // Radial geometry captured at layout, for hit testing and the hover
  // highlight (mirrors the painter's math).
  Offset _donutCenter = Offset.zero;
  double _donutOuter = 0;
  double _donutInner = 0;
  double _donutStartAngle = 0;
  double _donutGap = 0;
  double _donutTotal = 0;
  // Cumulative sweep boundaries relative to the start angle, length n+1
  // (zero/negative segments contribute zero sweep).
  List<double> _donutBounds = const [];

  // Per-series display state (parallel to _series), kept so a data change
  // can capture exactly what is on screen as the morph starting point.
  List<String> _seriesKeys = const [];
  List<List<Offset>> _targetPoints = const [];
  List<List<Offset>?> _alignedPointSources = const [];
  Map<int, List<BarEntry>> _targetEntries = const {};
  Map<int, List<BarEntry>?> _alignedEntrySources = const {};

  // Morph sources captured on data change, consumed by the next layout.
  Map<String, List<Offset>>? _morphPointsSource;
  Map<String, List<BarEntry>>? _morphEntriesSource;
  Scale<double>? _morphXSource;
  NumericScale? _morphYSource;

  // Pan/zoom state: visible windows and the full data ("base") domains.
  DomainWindow? _xWindow;
  DomainWindow? _yWindow;
  DomainWindow? _baseX;
  DomainWindow? _baseY;
  bool _xWindowable = false; // False for category axes.

  // Gesture state.
  ScaleGestureRecognizer? _scaleRecognizer;
  LongPressGestureRecognizer? _longPressRecognizer;
  DoubleTapGestureRecognizer? _doubleTapRecognizer;
  DomainWindow? _gestureStartX;
  DomainWindow? _gestureStartY;
  Offset _gestureStartFocal = Offset.zero;
  bool _panning = false;

  // Hover state.
  ChartHoverInfo? _hover;
  _TooltipLayout? _tooltipLayout;

  /// Releases labels, recognizers and listeners.
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _entranceAnimation?.removeListener(_onAnimationTick);
    _morphAnimation?.removeListener(_onAnimationTick);
    _scaleRecognizer?.dispose();
    _longPressRecognizer?.dispose();
    _doubleTapRecognizer?.dispose();
    _tooltipLayout?.dispose();
    _tooltipLayout = null;
    _disposeLabels();
    _layoutChanged.dispose();
    _dataChanged.dispose();
    _interactionChanged.dispose();
  }

  // --------------------------------------------------------------------
  // Pointer + gesture handling (called by the interaction render box).
  // --------------------------------------------------------------------

  /// The cursor for the interaction layer's mouse annotation.
  MouseCursor get cursor {
    if (_panning) return SystemMouseCursors.grabbing;
    if (_crosshair != null || _tooltip != null) {
      return SystemMouseCursors.precise;
    }
    return MouseCursor.defer;
  }

  /// Clears the hover when the mouse leaves the chart.
  void handleMouseExit(PointerExitEvent event) => _setHover(null);

  /// Routes a hit-tested pointer event into hover/gesture handling.
  void handlePointerEvent(PointerEvent event) {
    if (!interactive) return;
    if (event is PointerHoverEvent) {
      _updateHover(event.localPosition);
      return;
    }
    if (event is PointerDownEvent) {
      _ensureRecognizers();
      _scaleRecognizer?.addPointer(event);
      if (_crosshair != null || _tooltip != null) {
        _longPressRecognizer?.addPointer(event);
      }
      if (_panZoom != null) {
        _doubleTapRecognizer?.addPointer(event);
      }
      return;
    }
    if (event is PointerPanZoomStartEvent) {
      // Trackpad pinch/pan.
      _ensureRecognizers();
      _scaleRecognizer?.addPointerPanZoom(event);
      return;
    }
    if (event is PointerScrollEvent) {
      if (_panZoom != null && _scrollZoomModifierPressed()) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (e) => _handleScrollZoom(e as PointerScrollEvent),
        );
      }
      return;
    }
  }

  void _ensureRecognizers() {
    _scaleRecognizer ??= ScaleGestureRecognizer(debugOwner: this)
      ..onStart = _handleScaleStart
      ..onUpdate = _handleScaleUpdate
      ..onEnd = _handleScaleEnd;
    _longPressRecognizer ??= LongPressGestureRecognizer(debugOwner: this)
      ..onLongPressStart = _handleLongPressStart
      ..onLongPressMoveUpdate = _handleLongPressMove
      ..onLongPressEnd = _handleLongPressEnd;
    _doubleTapRecognizer ??= DoubleTapGestureRecognizer(debugOwner: this)
      ..onDoubleTap = _resetWindows;
  }

  void _handleLongPressStart(LongPressStartDetails details) =>
      _updateHover(details.localPosition);

  void _handleLongPressMove(LongPressMoveUpdateDetails details) =>
      _updateHover(details.localPosition);

  void _handleLongPressEnd(LongPressEndDetails details) => _setHover(null);

  bool _scrollZoomModifierPressed() {
    switch (_panZoom!.scrollZoomModifier) {
      case ScrollZoomModifier.none:
        return true;
      case ScrollZoomModifier.ctrlOrCmd:
        final pressed = HardwareKeyboard.instance.logicalKeysPressed;
        return pressed.contains(LogicalKeyboardKey.controlLeft) ||
            pressed.contains(LogicalKeyboardKey.controlRight) ||
            pressed.contains(LogicalKeyboardKey.metaLeft) ||
            pressed.contains(LogicalKeyboardKey.metaRight);
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (_panZoom == null) {
      _updateHover(details.localFocalPoint);
      return;
    }
    _setHover(null);
    _panning = true;
    _gestureStartX = _xWindow ?? _baseX;
    _gestureStartY = _yWindow ?? _baseY;
    _gestureStartFocal = details.localFocalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final config = _panZoom;
    if (config == null) {
      // No pan/zoom: dragging scrubs the crosshair.
      _updateHover(details.localFocalPoint);
      return;
    }
    final plot = _space?.plotArea;
    if (plot == null || plot.isEmpty) return;
    final scale = details.scale <= 0 ? 1.0 : details.scale;
    final delta = details.localFocalPoint - _gestureStartFocal;

    if (config.axis != PanZoomAxis.y) {
      final start = _gestureStartX;
      final base = _baseX;
      if (start != null && base != null && _xWindowable) {
        _xWindow = _transformedWindow(
          start: start,
          base: base,
          scale: scale,
          maxZoom: config.maxZoom,
          focalFraction: (_gestureStartFocal.dx - plot.left) / plot.width,
          panFraction: -delta.dx / plot.width,
          rubberBand: true,
        );
      }
    }
    if (config.axis != PanZoomAxis.x) {
      final start = _gestureStartY;
      final base = _baseY;
      if (start != null && base != null) {
        _yWindow = _transformedWindow(
          start: start,
          base: base,
          scale: scale,
          maxZoom: config.maxZoom,
          // The y axis is pixel-flipped.
          focalFraction: (plot.bottom - _gestureStartFocal.dy) / plot.height,
          panFraction: delta.dy / plot.height,
          rubberBand: true,
        );
      }
    }
    _pushWindowsToController();
    _invalidateLayout();
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_panZoom == null) return;
    _panning = false;
    // Rubber band snaps back inside the data domain.
    final baseX = _baseX;
    if (_xWindow != null && baseX != null) {
      _xWindow = _clampWindow(_xWindow!, baseX);
      if (_windowEqualsBase(_xWindow!, baseX)) _xWindow = null;
    }
    final baseY = _baseY;
    if (_yWindow != null && baseY != null) {
      _yWindow = _clampWindow(_yWindow!, baseY);
      if (_windowEqualsBase(_yWindow!, baseY)) _yWindow = null;
    }
    _pushWindowsToController();
    _invalidateLayout();
  }

  void _handleScrollZoom(PointerScrollEvent event) {
    final config = _panZoom;
    final plot = _space?.plotArea;
    if (config == null || plot == null || plot.isEmpty) return;
    final factor = math.exp(-event.scrollDelta.dy * 0.0015);
    if (config.axis != PanZoomAxis.y && _xWindowable) {
      final start = _xWindow ?? _baseX;
      final base = _baseX;
      if (start != null && base != null) {
        _xWindow = _clampWindow(
          _transformedWindow(
            start: start,
            base: base,
            scale: factor,
            maxZoom: config.maxZoom,
            focalFraction: (event.localPosition.dx - plot.left) / plot.width,
            panFraction: 0,
            rubberBand: false,
          ),
          base,
        );
        if (_windowEqualsBase(_xWindow!, base)) _xWindow = null;
      }
    }
    if (config.axis != PanZoomAxis.x) {
      final start = _yWindow ?? _baseY;
      final base = _baseY;
      if (start != null && base != null) {
        _yWindow = _clampWindow(
          _transformedWindow(
            start: start,
            base: base,
            scale: factor,
            maxZoom: config.maxZoom,
            focalFraction: (plot.bottom - event.localPosition.dy) / plot.height,
            panFraction: 0,
            rubberBand: false,
          ),
          base,
        );
        if (_windowEqualsBase(_yWindow!, base)) _yWindow = null;
      }
    }
    _pushWindowsToController();
    _invalidateLayout();
  }

  void _resetWindows() {
    if (_xWindow == null && _yWindow == null) return;
    _xWindow = null;
    _yWindow = null;
    _controller?.reset();
    _invalidateLayout();
  }

  void _pushWindowsToController() {
    final c = _controller;
    if (c == null) return;
    final x = _xWindow;
    final y = _yWindow;
    if (x == null && y == null) {
      c.reset();
    } else {
      if (x != null) c.setXDomain(x.min, x.max);
      if (y != null) c.setYDomain(y.min, y.max);
    }
  }

  /// Applies zoom (about a focal point) and pan to a start window, with
  /// zoom clamped to `[base/maxZoom, base]` and optional rubber-band edge
  /// resistance.
  DomainWindow _transformedWindow({
    required DomainWindow start,
    required DomainWindow base,
    required double scale,
    required double maxZoom,
    required double focalFraction,
    required double panFraction,
    required bool rubberBand,
  }) {
    final startWidth = start.max - start.min;
    final baseWidth = base.max - base.min;
    var width = startWidth / scale;
    width = width.clamp(baseWidth / maxZoom, baseWidth);
    final focal = start.min + focalFraction * startWidth;
    var min = focal - (focal - start.min) * (width / startWidth);
    min += panFraction * width;
    var max = min + width;
    if (rubberBand) {
      if (min < base.min) {
        final overshoot = base.min - min;
        min = base.min - overshoot * _kRubberBandFactor;
        max = min + width;
      } else if (max > base.max) {
        final overshoot = max - base.max;
        max = base.max + overshoot * _kRubberBandFactor;
        min = max - width;
      }
    }
    return (min: min, max: max);
  }

  DomainWindow _clampWindow(DomainWindow window, DomainWindow base) {
    final width = math.min(window.max - window.min, base.max - base.min);
    var min = window.min;
    if (min < base.min) min = base.min;
    if (min + width > base.max) min = base.max - width;
    return (min: min, max: min + width);
  }

  bool _windowEqualsBase(DomainWindow window, DomainWindow base) {
    final epsilon = (base.max - base.min) * 1e-9;
    return (window.min - base.min).abs() <= epsilon &&
        (window.max - base.max).abs() <= epsilon;
  }

  // --------------------------------------------------------------------
  // Hover / crosshair.
  // --------------------------------------------------------------------

  /// Radial hit test: pointer → segment index, or null when outside the
  /// ring or over a gap.
  int? _donutSegmentAt(Offset position) {
    final v = position - _donutCenter;
    final distance = v.distance;
    if (distance < _donutInner - 2 || distance > _donutOuter + 6) return null;
    var relative = (math.atan2(v.dy, v.dx) - _donutStartAngle) % (2 * math.pi);
    if (relative < 0) relative += 2 * math.pi;
    for (var i = 0; i < _donutBounds.length - 1; i++) {
      if (relative >= _donutBounds[i] && relative < _donutBounds[i + 1]) {
        return _donutValues[i] > 0 ? i : null;
      }
    }
    return null;
  }

  void _updateHover(Offset position) {
    if (_radial) {
      if (_tooltip == null && _crosshair == null) return;
      final index = _donutSegmentAt(position);
      if (index == null) {
        _setHover(null);
        return;
      }
      // Sliding within one segment only moves the tooltip anchor — reuse
      // the built rows instead of rebuilding them every pointer move.
      if (_hover?.x == index.toDouble()) {
        _hover = ChartHoverInfo(
          position: position,
          x: index.toDouble(),
          xPixel: position.dx,
          xLabel: _donutLabels[index],
          points: _hover!.points,
        );
        onHoverChanged?.call(_hover);
        _interactionChanged.pulse();
        return;
      }
      _setHover(ChartHoverInfo(
        position: position,
        x: index.toDouble(),
        xPixel: position.dx,
        xLabel: _donutLabels[index],
        points: <HoveredPoint>[
          HoveredPoint(
            seriesIndex: 0,
            seriesId: _series.first.id,
            seriesLabel: _donutLabels[index],
            color: theme.palette[index % theme.palette.length],
            x: index.toDouble(),
            y: _donutValues[index],
            pixel: position,
          ),
        ],
      ));
      return;
    }
    if (_crosshair == null && _tooltip == null) return;
    final space = _space;
    if (space == null || !space.plotArea.contains(position)) {
      _setHover(null);
      return;
    }

    // Index mode: snap to the nearest data x across all series. Sorted
    // series are searched in O(log n) so hovering a 500k-point chart stays
    // instant; unsorted ones fall back to a scan.
    final cursorX = _pixelToDomainX(position.dx, space);
    double? bestX;
    var bestDistance = double.infinity;
    for (var i = 0; i < _targetPoints.length; i++) {
      final p = _nearestPointByX(i, cursorX);
      if (p == null) continue;
      final d = (space.xToPixel(p.dx) - position.dx).abs();
      if (d < bestDistance) {
        bestDistance = d;
        bestX = p.dx;
      }
    }
    if (bestX == null) {
      _setHover(null);
      return;
    }
    final snappedPixel = space.xToPixel(bestX);

    final points = <HoveredPoint>[];
    for (var i = 0; i < _series.length; i++) {
      final nearest = _nearestPointByX(i, bestX);
      // Only series that actually have a point at (or effectively at) the
      // snapped x participate.
      if (nearest == null ||
          (space.xToPixel(nearest.dx) - snappedPixel).abs() > 12) {
        continue;
      }
      points.add(HoveredPoint(
        seriesIndex: i,
        seriesId: _series[i].id,
        seriesLabel: _series[i].label,
        color: i < _seriesColors.length
            ? _seriesColors[i]
            : theme.palette[i % theme.palette.length],
        x: nearest.dx,
        y: nearest.dy,
        pixel: space.toPixel(nearest),
      ));
    }
    if (points.isEmpty) {
      _setHover(null);
      return;
    }

    _setHover(ChartHoverInfo(
      position: position,
      x: bestX,
      xPixel: snappedPixel,
      xLabel: (_hoverXFormatter ?? (v) => formatTickLabel(v, 0.01))(bestX),
      points: points,
    ));
  }

  double _pixelToDomainX(double px, CoordinateSpace space) {
    final plot = space.plotArea;
    final fraction = (px - plot.left) / plot.width;
    final xScale = space.xScale;
    if (xScale is NumericScale) {
      return xScale.min + fraction * xScale.range;
    }
    if (xScale is CategoryScale) {
      return fraction * xScale.length - 0.5;
    }
    return fraction;
  }

  /// The point of series [i] whose x is nearest [x] — binary search when
  /// the series is x-sorted, linear scan otherwise. Skips non-finite
  /// points in the scan path; sorted data is assumed finite.
  Offset? _nearestPointByX(int i, double x) {
    final points = _targetPoints[i];
    if (points.isEmpty) return null;
    if (_xSorted.length > i && _xSorted[i] && points.length > 8) {
      var lo = 0;
      var hi = points.length - 1;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (points[mid].dx < x) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      // lo is the first point ≥ x; its left neighbor may be closer.
      if (lo > 0 &&
          (points[lo - 1].dx - x).abs() <= (points[lo].dx - x).abs()) {
        lo--;
      }
      final p = points[lo];
      return p.dx.isFinite && p.dy.isFinite ? p : null;
    }
    Offset? nearest;
    var nearestDistance = double.infinity;
    for (final p in points) {
      if (!p.dx.isFinite || !p.dy.isFinite) continue;
      final d = (p.dx - x).abs();
      if (d < nearestDistance) {
        nearestDistance = d;
        nearest = p;
      }
    }
    return nearest;
  }

  void _setHover(ChartHoverInfo? info) {
    if (identical(info, _hover)) return;
    if (info == null && _hover == null) return;
    _hover = info;
    _tooltipLayout?.dispose();
    _tooltipLayout = null;
    if (info != null && _tooltip != null && _tooltip!.builder == null) {
      _tooltipLayout =
          _radial ? _buildDonutTooltipLayout(info) : _buildTooltipLayout(info);
    }
    onHoverChanged?.call(info);
    _interactionChanged.pulse();
  }

  /// Donut tooltip: segment name as the header, one row with the value
  /// and its share of the total.
  _TooltipLayout _buildDonutTooltipLayout(ChartHoverInfo info) {
    final style = theme.tooltipTextStyle;
    final headerStyle = style.copyWith(
      color: style.color?.withValues(alpha: (style.color?.a ?? 1) * 0.7),
    );
    final valueStyle = style.copyWith(fontWeight: FontWeight.w600);
    final format = _tooltip?.valueFormatter ?? (v) => formatTickLabel(v, 0.01);
    final point = info.points.first;
    final share = _donutTotal <= 0
        ? ''
        : '${(point.y / _donutTotal * 100).toStringAsFixed(
            point.y / _donutTotal < 0.1 ? 1 : 0,
          )}%';
    return _TooltipLayout(
      _layoutText(info.xLabel, headerStyle),
      <_TooltipRow>[
        _TooltipRow(
          point.color,
          _layoutText(format(point.y), style),
          _layoutText(share, valueStyle),
        ),
      ],
    );
  }

  _TooltipLayout _buildTooltipLayout(ChartHoverInfo info) {
    final style = theme.tooltipTextStyle;
    final headerStyle = style.copyWith(
      color: style.color?.withValues(alpha: (style.color?.a ?? 1) * 0.7),
    );
    final valueStyle = style.copyWith(fontWeight: FontWeight.w600);
    final format = _tooltip?.valueFormatter ?? (v) => formatTickLabel(v, 0.01);
    return _TooltipLayout(
      _layoutText(info.xLabel, headerStyle),
      <_TooltipRow>[
        for (final p in info.points)
          _TooltipRow(
            p.color,
            _layoutText(
              p.seriesLabel ?? 'Series ${p.seriesIndex + 1}',
              style,
            ),
            _layoutText(format(p.y), valueStyle),
          ),
      ],
    );
  }

  // --------------------------------------------------------------------
  // Layout.
  // --------------------------------------------------------------------

  /// Captures the currently displayed geometry (mid-morph if a morph is
  /// running) as the starting point for the next morph.
  ///
  /// The chart's state object calls this when `series` is about to change,
  /// *before* the morph controller restarts, so interrupted morphs
  /// continue from where they visually are instead of jumping.
  void prepareMorph() {
    final space = _space;
    if (space == null) return;
    final t = _morphT;

    if (_radial) {
      // Capture the currently displayed segment values, keyed by label.
      final source = _donutAlignedSource;
      _donutMorphSource = <String, double>{
        for (var i = 0; i < _donutLabels.length; i++)
          _donutLabels[i]: source == null || t >= 1
              ? _donutValues[i]
              : source[i] + (_donutValues[i] - source[i]) * t,
      };
      return;
    }

    final points = <String, List<Offset>>{};
    for (var i = 0; i < _seriesKeys.length; i++) {
      final target = _targetPoints[i];
      final source = _alignedPointSources[i];
      points[_seriesKeys[i]] = source == null || t >= 1
          ? target
          : <Offset>[
              for (var j = 0; j < target.length; j++)
                Offset.lerp(
                  j < source.length ? source[j] : target[j],
                  target[j],
                  t,
                )!,
            ];
    }
    final entries = <String, List<BarEntry>>{};
    for (final MapEntry(key: i, value: target) in _targetEntries.entries) {
      final source = _alignedEntrySources[i];
      entries[_seriesKeys[i]] = source == null || t >= 1
          ? target
          : <BarEntry>[
              for (var j = 0; j < target.length; j++)
                BarEntry(
                  x: target[j].x,
                  from: lerpDouble(
                    j < source.length ? source[j].from : target[j].from,
                    target[j].from,
                    t,
                  )!,
                  to: lerpDouble(
                    j < source.length ? source[j].to : target[j].to,
                    target[j].to,
                    t,
                  )!,
                  index: target[j].index,
                ),
            ];
    }

    final effective = _effectiveSpace(space);
    _morphPointsSource = points;
    _morphEntriesSource = entries;
    _morphXSource = effective.xScale;
    _morphYSource = effective.yScale;
  }

  /// Lays the chart out for [size]; memoized until the size or any
  /// configuration changes. Every layer calls this from performLayout —
  /// the first call computes, the rest return immediately.
  void ensureLayout(Size size) {
    if (!_layoutDirty && _layoutSize == size) return;
    _layoutSize = size;
    _layoutDirty = false;
    if (_dataDirty) {
      _prepareData();
      _dataDirty = false;
    }
    _layoutChart();
  }

  void _disposeLabels() {
    for (final label in _xLabels) {
      label.painter.dispose();
    }
    for (final label in _yLabels) {
      label.painter.dispose();
    }
    _xLabels = const [];
    _yLabels = const [];
    _xTitle?.dispose();
    _xTitle = null;
    _yTitle?.dispose();
    _yTitle = null;
  }

  /// Substitutes a [CategoryAxis] when the x axis is an untouched default
  /// and at least one series is purely categorical — so
  /// `Chart(series: [BarSeries(data: weekCounts)])` just works.
  ChartAxis _effectiveXAxis() {
    final x = _axes.x;
    if (x is NumericAxis &&
        x.label == null &&
        x.tickCount == null &&
        x.min == null &&
        x.max == null &&
        x.tickFormatter == null) {
      final categoricalOnly = _series.any(
        (s) => !s.hasXAccessor && s.hasCategoryAccessor,
      );
      if (categoricalOnly) return const CategoryAxis();
    }
    return x;
  }

  /// Resolves series data and everything derived only from it (categories,
  /// bar stacking, extents). Cached across pan/zoom relayouts.
  void _prepareData() {
    _radial = _series.any((s) => s is DonutSeries);
    if (_radial) {
      assert(
        _series.length == 1,
        'A DonutSeries renders radially and cannot be combined with other '
        'series in the same chart.',
      );
      final donut = _series.first;
      if (donut.hasCategoryAccessor) {
        final segments = donut.resolveCategoryPoints();
        _donutLabels = <String>[for (final (label, _) in segments) label];
        _donutValues = <double>[for (final (_, value) in segments) value];
      } else {
        _donutValues = donut.resolveValues();
        _donutLabels = <String>[
          for (var i = 0; i < _donutValues.length; i++) 'Segment ${i + 1}',
        ];
      }
      // Cartesian caches stay empty in radial mode.
      _resolved = <List<Offset>>[const []];
      _xSorted = const [true];
      _categories = null;
      _barIndices = const [];
      _stacked = false;
      _barEntries = const {};
      _stackMin = _stackMax = null;
      _xMin = _xMax = _yMin = _yMax = null;
      _zeroAnchored = false;
      return;
    }
    _donutLabels = const [];
    _donutValues = const [];

    final xAxis = _effectiveXAxis();

    // Resolve series data to domain-space points. Category axes resolve
    // categories to band indices; series with a numeric xAccessor on a
    // category axis are interpreted in index space (line-over-bars).
    List<String>? categories;
    final resolved = <List<Offset>>[];
    if (xAxis is CategoryAxis) {
      categories = List<String>.of(xAxis.categories ?? const <String>[]);
      final indexOf = <String, int>{
        for (var i = 0; i < categories.length; i++) categories[i]: i,
      };
      for (final s in _series) {
        if (!s.hasCategoryAccessor && s.hasXAccessor) {
          resolved.add(s.resolvePoints());
          continue;
        }
        final points = <Offset>[];
        for (final (category, y) in s.resolveCategoryPoints()) {
          var index = indexOf[category];
          if (index == null) {
            index = categories.length;
            categories.add(category);
            indexOf[category] = index;
          }
          points.add(Offset(index.toDouble(), y));
        }
        resolved.add(points);
      }
      if (categories.isEmpty) categories.add('');
    } else {
      for (final s in _series) {
        resolved.add(s.resolvePoints());
      }
    }
    _resolved = resolved;
    _categories = categories;

    _xSorted = <bool>[
      for (final points in resolved)
        () {
          for (var i = 1; i < points.length; i++) {
            if (points[i].dx < points[i - 1].dx) return false;
          }
          return true;
        }(),
    ];

    // Bar bookkeeping: arrangement, band width, stack segments.
    _barIndices = <int>[
      for (var i = 0; i < _series.length; i++)
        if (_series[i] is BarSeries) i,
    ];
    _stacked = _barIndices.isNotEmpty &&
        (_series[_barIndices.first] as BarSeries).arrangement ==
            BarArrangement.stacked;
    assert(
      _barIndices.every((i) =>
          ((_series[i] as BarSeries).arrangement == BarArrangement.stacked) ==
          _stacked),
      'All BarSeries in a chart must use the same BarArrangement.',
    );

    _domainBand = 1.0;
    if (_barIndices.isNotEmpty && xAxis is! CategoryAxis) {
      _domainBand = _smallestXGap(_barIndices, resolved);
    }

    final barEntries = <int, List<BarEntry>>{};
    _stackMin = null;
    _stackMax = null;
    if (_barIndices.isNotEmpty) {
      if (_stacked) {
        final (lo, hi) =
            _buildStackedEntries(_barIndices, resolved, into: barEntries);
        _stackMin = lo;
        _stackMax = hi;
      } else {
        for (final si in _barIndices) {
          barEntries[si] = <BarEntry>[
            for (var j = 0; j < resolved[si].length; j++)
              BarEntry(
                x: resolved[si][j].dx,
                from: 0,
                to: resolved[si][j].dy,
                index: j,
              ),
          ];
        }
      }
    }
    _barEntries = barEntries;

    // Data extents.
    double? xMin, xMax, yMin, yMax;
    for (final points in resolved) {
      for (final p in points) {
        if (!p.dx.isFinite || !p.dy.isFinite) continue;
        xMin = xMin == null ? p.dx : math.min(xMin, p.dx);
        xMax = xMax == null ? p.dx : math.max(xMax, p.dx);
        yMin = yMin == null ? p.dy : math.min(yMin, p.dy);
        yMax = yMax == null ? p.dy : math.max(yMax, p.dy);
      }
    }
    final stackMin = _stackMin;
    final stackMax = _stackMax;
    if (stackMin != null) yMin = math.min(yMin ?? stackMin, stackMin);
    if (stackMax != null) yMax = math.max(yMax ?? stackMax, stackMax);

    // Bars and areas are anchored at zero — their y domain must include it.
    _zeroAnchored = _series.any((s) => switch (s) {
          BarSeries() => true,
          AreaSeries() => true,
          LineSeries(:final style) => style.area != null,
          ScatterSeries() => false,
          DonutSeries() => false,
        });
    if (_zeroAnchored && yMin != null && yMax != null) {
      yMin = math.min(yMin, 0);
      yMax = math.max(yMax, 0);
    }

    // Bars on numeric/time axes need half a band of headroom on each side.
    if (_barIndices.isNotEmpty &&
        xAxis is! CategoryAxis &&
        xMin != null &&
        xMax != null) {
      xMin -= _domainBand / 2;
      xMax += _domainBand / 2;
    }
    _xMin = xMin;
    _xMax = xMax;
    _yMin = yMin;
    _yMax = yMax;
  }

  void _layoutChart() {
    _disposeLabels();
    final size = _layoutSize;

    if (_radial) {
      _layoutRadial(size);
      return;
    }

    final xAxis = _effectiveXAxis();
    final yAxis = _axes.y;
    if (yAxis is! NumericAxis) {
      throw UnsupportedError(
        'Only NumericAxis is supported on the y axis in this version.',
      );
    }
    final resolved = _resolved;
    final categories = _categories;
    final barIndices = _barIndices;
    final stacked = _stacked;
    final domainBand = _domainBand;
    final barEntries = _barEntries;

    // X scale + tick labels, by axis type. Pan/zoom windows override the
    // base (full data) domain.
    final xTickTarget = switch (xAxis.tickCount) {
      final count? => count,
      null => (size.width / 90).round().clamp(3, 10),
    };
    final Scale<double> xScaleD;
    switch (xAxis) {
      case NumericAxis(:final min, :final max, :final tickFormatter):
        var scale = NumericScale.fromExtent(
          _xMin ?? 0,
          _xMax ?? 1,
          nice: false,
          minOverride: min,
          maxOverride: max,
        );
        _baseX = (min: scale.min, max: scale.max);
        _xWindowable = true;
        final window = _xWindow;
        if (window != null) {
          scale = NumericScale(min: window.min, max: window.max);
        }
        xScaleD = scale;
        final formatter =
            tickFormatter ?? _defaultFormatter(scale, xTickTarget);
        _hoverXFormatter = formatter;
        _xLabels = _buildLabels(
          scale.ticks(targetTickCount: xTickTarget),
          formatter,
        );
      case TimeAxis(:final min, :final max, :final tickFormatter):
        var scale = NumericScale.fromExtent(
          _xMin ?? 0,
          _xMax ?? 1,
          nice: false,
          minOverride: min?.millisecondsSinceEpoch.toDouble(),
          maxOverride: max?.millisecondsSinceEpoch.toDouble(),
        );
        _baseX = (min: scale.min, max: scale.max);
        _xWindowable = true;
        final window = _xWindow;
        if (window != null) {
          scale = NumericScale(min: window.min, max: window.max);
        }
        xScaleD = scale;
        final (ticks: ticks, granularity: granularity) = timeTicks(
          DateTime.fromMillisecondsSinceEpoch(scale.min.round()),
          DateTime.fromMillisecondsSinceEpoch(scale.max.round()),
          targetTickCount: xTickTarget,
        );
        final format =
            tickFormatter ?? (DateTime t) => formatTimeTick(t, granularity);
        _hoverXFormatter = (v) => format(
              DateTime.fromMillisecondsSinceEpoch(v.round()),
            );
        _xLabels = <_TickLabel>[
          for (final tick in ticks)
            _TickLabel(
              tick.millisecondsSinceEpoch.toDouble(),
              _layoutText(format(tick), theme.tickLabelStyle),
            ),
        ];
      case CategoryAxis():
        final scale = CategoryScale(categories: categories!);
        _baseX = (min: -0.5, max: categories.length - 0.5);
        _xWindowable = false;
        xScaleD = scale;
        final resolvedCategories = categories;
        _hoverXFormatter = (v) {
          final index = v.round();
          return index >= 0 && index < resolvedCategories.length
              ? resolvedCategories[index]
              : '';
        };
        _xLabels = <_TickLabel>[
          for (var i = 0; i < categories.length; i++)
            _TickLabel(
              i.toDouble(),
              _layoutText(categories[i], theme.tickLabelStyle),
            ),
        ];
    }

    // Y scale + tick labels (numeric only).
    final yTickTarget = switch (yAxis.tickCount) {
      final count? => count,
      null => (size.height / 70).round().clamp(3, 8),
    };
    var yScale = NumericScale.fromExtent(
      _yMin ?? 0,
      _yMax ?? 1,
      targetTickCount: yTickTarget,
      minOverride: yAxis.min,
      maxOverride: yAxis.max,
    );
    _baseY = (min: yScale.min, max: yScale.max);
    final yWindow = _yWindow;
    if (yWindow != null) {
      yScale = NumericScale(min: yWindow.min, max: yWindow.max);
    }
    final yFormatter =
        yAxis.tickFormatter ?? _defaultFormatter(yScale, yTickTarget);
    _yLabels = _buildLabels(
      yScale.ticks(targetTickCount: yTickTarget),
      yFormatter,
    );

    // Axis titles.
    _xTitle = _buildTitle(xAxis.label);
    _yTitle = _buildTitle(yAxis.label);

    // Plot insets from measured labels.
    var maxYLabelWidth = 0.0;
    for (final label in _yLabels) {
      maxYLabelWidth = math.max(maxYLabelWidth, label.painter.width);
    }
    var xLabelHeight = 0.0;
    for (final label in _xLabels) {
      xLabelHeight = math.max(xLabelHeight, label.painter.height);
    }
    final left = (_yLabels.isEmpty ? 0.0 : maxYLabelWidth + _kYLabelGap) +
        (_yTitle == null ? 0.0 : _yTitle!.height + _kXLabelGap);
    final bottom = (_xLabels.isEmpty ? 0.0 : xLabelHeight + _kXLabelGap) +
        (_xTitle == null ? 0.0 : _xTitle!.height + 6);
    final right = math.max(
      8.0,
      _xLabels.isEmpty ? 8.0 : _xLabels.last.painter.width / 2,
    );

    var plot = Rect.fromLTRB(
      left,
      _kTopInset,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 10 || plot.height <= 10) {
      // Too small for labels — give the whole box to the data.
      plot = Offset.zero & size;
    }
    _space = CoordinateSpace(plotArea: plot, xScale: xScaleD, yScale: yScale);

    // Decimate x labels that would collide at this width.
    _xLabelStride = _computeXLabelStride(plot.width);

    // Align morph sources (captured by prepareMorph) to the new data.
    _seriesKeys = <String>[
      for (var i = 0; i < _series.length; i++) _series[i].id ?? '#$i',
    ];
    _targetPoints = resolved;
    _alignedPointSources = <List<Offset>?>[
      for (var i = 0; i < _series.length; i++)
        _alignPoints(_morphPointsSource?[_seriesKeys[i]], resolved[i]),
    ];
    _targetEntries = barEntries;
    _alignedEntrySources = <int, List<BarEntry>?>{
      for (final MapEntry(key: i, value: target) in barEntries.entries)
        i: _alignEntries(_morphEntriesSource?[_seriesKeys[i]], target),
    };

    // Series painters: palette colors in fixed order, emphasis muting,
    // emphasized series painted last (on top). Line/area series are sliced
    // to the visible window and LTTB-downsampled before painting.
    final emphasizedSeries = _resolveEmphasizedSeries();
    final palette = theme.palette;
    _seriesColors = <Color>[
      for (var i = 0; i < _series.length; i++)
        _displayColor(
          _series[i],
          _series[i].color ?? palette[i % palette.length],
        ),
    ];
    final order = <int>[
      for (var i = 0; i < _series.length; i++)
        if (i != emphasizedSeries) i,
      if (emphasizedSeries != null) emphasizedSeries,
    ];
    _painters = <SeriesPainter>[
      for (final i in order)
        () {
          final display = _displayPoints(i, plot.width);
          // Sliced/downsampled points no longer align index-wise with the
          // captured morph source — skip morphing for those series.
          final morphFrom =
              identical(display, resolved[i]) ? _alignedPointSources[i] : null;
          return _createPainter(
            _series[i],
            display,
            color: _seriesColors[i],
            opacityFactor: emphasizedSeries == null || i == emphasizedSeries
                ? 1.0
                : _emphasis!.mutedOpacity,
            morphFromPoints: morphFrom,
            barEntries: barEntries[i],
            morphFromEntries: _alignedEntrySources[i],
            slotIndex: stacked ? 0 : barIndices.indexOf(i),
            slotCount: stacked ? 1 : math.max(1, barIndices.length),
            domainBand: domainBand,
          );
        }(),
    ];
  }

  /// Radial layout: the donut fills the box, no axes or windows.
  void _layoutRadial(Size size) {
    _xLabels = const [];
    _yLabels = const [];
    _xLabelStride = 1;
    _baseX = null;
    _baseY = null;
    _xWindowable = false;
    _hoverXFormatter = null;
    final plot = (Offset.zero & size).deflate(4);
    _space = CoordinateSpace(
      plotArea: plot,
      xScale: const NumericScale(min: 0, max: 1),
      yScale: const NumericScale(min: 0, max: 1),
    );

    final donut = _series.first;
    final style = (donut as DonutSeries).style;

    // Segment geometry for hit testing and the hover highlight, mirroring
    // the painter (target values — hovering mid-morph snaps to targets).
    _donutCenter = plot.center;
    final maxOuter = math.max(1.0, plot.shortestSide / 2);
    _donutOuter =
        style.radius == null ? maxOuter : style.radius!.clamp(1.0, maxOuter);
    _donutInner = (_donutOuter * style.cutout).clamp(0.0, _donutOuter - 1);
    _donutStartAngle = style.startAngle;
    _donutGap = style.gap;
    var total = 0.0;
    for (final v in _donutValues) {
      if (v > 0 && v.isFinite) total += v;
    }
    _donutTotal = total;
    final bounds = <double>[0];
    var cursor = 0.0;
    for (final v in _donutValues) {
      if (v > 0 && v.isFinite && total > 0) {
        cursor += v / total * 2 * math.pi;
      }
      bounds.add(cursor);
    }
    _donutBounds = bounds;
    _seriesKeys = <String>[donut.id ?? '#0'];
    _targetPoints = _resolved;
    _alignedPointSources = const [null];
    _targetEntries = const {};
    _alignedEntrySources = const {};

    // Align the captured morph values to the new segments by label; new
    // segments sweep in from zero.
    final source = _donutMorphSource;
    _donutAlignedSource = source == null
        ? null
        : <double>[
            for (var i = 0; i < _donutLabels.length; i++)
              source[_donutLabels[i]] ?? 0,
          ];

    final palette = theme.palette;
    _seriesColors = <Color>[palette[0]];
    _painters = <SeriesPainter>[
      _createPainter(
        donut,
        const [],
        color: palette[0],
        opacityFactor: 1,
        morphFromPoints: null,
        barEntries: null,
        morphFromEntries: null,
        slotIndex: 0,
        slotCount: 1,
        domainBand: 1,
      ),
    ];
  }

  /// The points a line/area series actually paints: the raw resolution,
  /// sliced to the visible window (sorted series only) and downsampled per
  /// the series' [Downsampling] policy. Returns the raw list unchanged
  /// (identical) when nothing applies.
  List<Offset> _displayPoints(int i, double plotWidth) {
    final s = _series[i];
    var points = _resolved[i];
    if (s is! LineSeries && s is! AreaSeries) return points;
    final window = _xWindow;
    if (window != null && _xSorted[i] && points.length > 2) {
      points = _sliceByX(points, window);
    }
    final threshold = s.downsampling.thresholdFor(plotWidth);
    if (threshold != null && points.length > threshold) {
      points = lttbDownsample(points, threshold);
    }
    return points;
  }

  /// Slices x-sorted [points] to [window], keeping one point of margin on
  /// each side so the line runs off-plot instead of stopping at the edge.
  List<Offset> _sliceByX(List<Offset> points, DomainWindow window) {
    var lo = 0;
    var hi = points.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (points[mid].dx < window.min) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final start = math.max(0, lo - 1);
    lo = start;
    hi = points.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (points[mid].dx <= window.max) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final end = math.min(points.length, lo + 1);
    if (start == 0 && end == points.length) return points;
    return points.sublist(start, end);
  }

  /// Index-aligns a captured morph source to [target] (padding with the
  /// source's last point so extra target points grow out of the old end).
  List<Offset>? _alignPoints(List<Offset>? source, List<Offset> target) {
    if (source == null || source.isEmpty || target.isEmpty) return null;
    return <Offset>[
      for (var i = 0; i < target.length; i++)
        i < source.length ? source[i] : source.last,
    ];
  }

  /// X-aligns captured bar segments to [target]; bars at new x positions
  /// grow from a zero-height segment.
  List<BarEntry>? _alignEntries(
    List<BarEntry>? source,
    List<BarEntry> target,
  ) {
    if (source == null || target.isEmpty) return null;
    final byX = <double, BarEntry>{for (final e in source) e.x: e};
    return <BarEntry>[
      for (final e in target)
        byX[e.x] ?? BarEntry(x: e.x, from: 0, to: 0, index: e.index),
    ];
  }

  /// Smallest positive gap between distinct x values across bar series —
  /// the band width for bars on numeric/time axes.
  double _smallestXGap(List<int> barIndices, List<List<Offset>> resolved) {
    final xs = <double>{
      for (final si in barIndices)
        for (final p in resolved[si])
          if (p.dx.isFinite) p.dx,
    }.toList()
      ..sort();
    var gap = double.infinity;
    for (var i = 1; i < xs.length; i++) {
      final d = xs[i] - xs[i - 1];
      if (d > 0) gap = math.min(gap, d);
    }
    return gap.isFinite ? gap : 1.0;
  }

  /// Builds stacked segments: positives accumulate up, negatives down,
  /// only the outermost segment of each stack gets the rounded data end.
  /// Returns the (most negative, most positive) stack extents.
  (double?, double?) _buildStackedEntries(
    List<int> barIndices,
    List<List<Offset>> resolved, {
    required Map<int, List<BarEntry>> into,
  }) {
    final posTotals = <double, double>{};
    final negTotals = <double, double>{};
    // Temporary segments plus the owner of each stack's outermost segment.
    final temp = <int, List<(double, double, double, int)>>{};
    final topPos = <double, (int, int)>{};
    final topNeg = <double, (int, int)>{};
    for (final si in barIndices) {
      final list = <(double, double, double, int)>[];
      final points = resolved[si];
      for (var j = 0; j < points.length; j++) {
        final x = points[j].dx;
        final v = points[j].dy;
        if (!x.isFinite || !v.isFinite) continue;
        if (v >= 0) {
          final from = posTotals[x] ?? 0;
          final to = from + v;
          posTotals[x] = to;
          if (v > 0) topPos[x] = (si, list.length);
          list.add((x, from, to, j));
        } else {
          final from = negTotals[x] ?? 0;
          final to = from + v;
          negTotals[x] = to;
          topNeg[x] = (si, list.length);
          list.add((x, from, to, j));
        }
      }
      temp[si] = list;
    }
    for (final si in barIndices) {
      into[si] = <BarEntry>[
        for (var k = 0; k < temp[si]!.length; k++)
          BarEntry(
            x: temp[si]![k].$1,
            from: temp[si]![k].$2,
            to: temp[si]![k].$3,
            index: temp[si]![k].$4,
            dataEndRounded: topPos[temp[si]![k].$1] == (si, k) ||
                topNeg[temp[si]![k].$1] == (si, k),
            insetBase: temp[si]![k].$2 != 0,
          ),
      ];
    }
    double? lo, hi;
    for (final v in negTotals.values) {
      lo = lo == null ? v : math.min(lo, v);
    }
    for (final v in posTotals.values) {
      hi = hi == null ? v : math.max(hi, v);
    }
    return (lo, hi);
  }

  int? _resolveEmphasizedSeries() {
    final e = _emphasis;
    if (e == null) return null;
    if (e.id != null) {
      for (var i = 0; i < _series.length; i++) {
        if (_series[i].id == e.id) return i;
      }
    }
    final index = e.index;
    if (index != null && index >= 0 && index < _series.length) return index;
    return null;
  }

  /// The color a series is actually drawn with — style overrides and
  /// context-gray styling included — so hover markers and tooltip chips
  /// always match the stroke.
  Color _displayColor(Series<Object?> s, Color base) {
    switch (s) {
      case LineSeries(:final style):
        return style.color ?? (style.isContext ? theme.contextColor : base);
      case AreaSeries(:final style):
        return style.color ?? (style.isContext ? theme.contextColor : base);
      case BarSeries(:final style):
        return style.color ?? base;
      case ScatterSeries(:final style):
        return style.color ?? base;
      case DonutSeries():
        return base; // Donut segments are colored per datum, not per series.
    }
  }

  SeriesPainter _createPainter(
    Series<Object?> s,
    List<Offset> points, {
    required Color color,
    required double opacityFactor,
    required List<Offset>? morphFromPoints,
    required List<BarEntry>? barEntries,
    required List<BarEntry>? morphFromEntries,
    required int slotIndex,
    required int slotCount,
    required double domainBand,
  }) {
    switch (s) {
      case LineSeries(:final style):
        return LineSeriesPainter(
          points: points,
          style: style,
          seriesColor: color,
          opacityFactor: opacityFactor,
          morphFrom: morphFromPoints,
        );
      case AreaSeries(:final style):
        return LineSeriesPainter(
          points: points,
          style: style,
          seriesColor: color,
          opacityFactor: opacityFactor,
          morphFrom: morphFromPoints,
        );
      case ScatterSeries(:final style):
        return ScatterSeriesPainter(
          points: points,
          style: style,
          seriesColor: color,
          opacityFactor: opacityFactor,
          morphFrom: morphFromPoints,
        );
      case DonutSeries(:final style):
        return DonutSeriesPainter(
          values: _donutValues,
          colors: theme.palette,
          style: style,
          morphFrom: _donutAlignedSource,
          opacityFactor: opacityFactor,
        );
      case BarSeries(:final style, :final emphasizedIndex):
        return BarSeriesPainter(
          entries: barEntries ?? const <BarEntry>[],
          style: style,
          seriesColor: color,
          slotIndex: math.max(0, slotIndex),
          slotCount: slotCount,
          domainBand: domainBand,
          emphasizedIndex: emphasizedIndex,
          opacityFactor: opacityFactor,
          morphFrom: morphFromEntries,
        );
    }
  }

  String Function(double) _defaultFormatter(NumericScale scale, int target) {
    final step = scale.tickStep(targetTickCount: target);
    return (value) => formatTickLabel(value, step);
  }

  TextPainter _layoutText(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: _textDirection,
    )..layout();
  }

  List<_TickLabel> _buildLabels(
    List<double> ticks,
    String Function(double) formatter,
  ) {
    return <_TickLabel>[
      for (final tick in ticks)
        _TickLabel(tick, _layoutText(formatter(tick), theme.tickLabelStyle)),
    ];
  }

  TextPainter? _buildTitle(String? label) {
    if (label == null || label.isEmpty) return null;
    return _layoutText(label, theme.axisLabelStyle);
  }

  int _computeXLabelStride(double plotWidth) {
    if (_xLabels.length < 2) return 1;
    for (var stride = 1; stride < _xLabels.length; stride++) {
      var width = 0.0;
      var count = 0;
      for (var i = 0; i < _xLabels.length; i += stride) {
        width += _xLabels[i].painter.width;
        count++;
      }
      if (width + (count - 1) * _kXLabelMinSpacing <= plotWidth) {
        return stride;
      }
    }
    return _xLabels.length; // Only the first label fits.
  }

  // --------------------------------------------------------------------
  // Painting.
  // --------------------------------------------------------------------

  /// The space used for this frame: mid-morph the scale domains glide from
  /// the captured source to the layout target.
  CoordinateSpace _effectiveSpace(CoordinateSpace target) {
    final t = _morphT;
    if (t >= 1) return target;
    var xScale = target.xScale;
    final fromX = _morphXSource;
    if (fromX is NumericScale && xScale is NumericScale) {
      xScale = NumericScale(
        min: lerpDouble(fromX.min, xScale.min, t)!,
        max: lerpDouble(fromX.max, xScale.max, t)!,
      );
    }
    var yScale = target.yScale;
    final fromY = _morphYSource;
    if (fromY != null) {
      yScale = NumericScale(
        min: lerpDouble(fromY.min, yScale.min, t)!,
        max: lerpDouble(fromY.max, yScale.max, t)!,
      );
    }
    return CoordinateSpace(
      plotArea: target.plotArea,
      xScale: xScale,
      yScale: yScale,
    );
  }

  /// Paints grid, axis baseline, tick labels and titles.
  void paintStatic(Canvas canvas) {
    final target = _space;
    if (target == null || _radial) return; // Radial charts have no axes.
    final space = _effectiveSpace(target);
    final plot = space.plotArea;

    // Horizontal hairlines only — no vertical gridlines.
    final gridPaint = Paint()
      ..color = theme.gridLineColor
      ..strokeWidth = theme.gridLineWidth;
    for (final label in _yLabels) {
      final y = space.yToPixel(label.value);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    // Minimal x-axis baseline; the y axis draws no line at all.
    final axisPaint = Paint()
      ..color = theme.axisLineColor
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);

    // Y tick labels: right-aligned against the plot, centered on the tick.
    for (final label in _yLabels) {
      final painter = label.painter;
      final y = space.yToPixel(label.value) - painter.height / 2;
      painter.paint(
        canvas,
        Offset(plot.left - _kYLabelGap - painter.width, y),
      );
    }

    // X tick labels: centered under the tick, decimated to avoid collisions
    // and clamped so edge labels never overflow the chart box.
    for (var i = 0; i < _xLabels.length; i += _xLabelStride) {
      final painter = _xLabels[i].painter;
      final maxX = math.max(0.0, _layoutSize.width - painter.width);
      final x = math.max(
        0.0,
        math.min(space.xToPixel(_xLabels[i].value) - painter.width / 2, maxX),
      );
      painter.paint(canvas, Offset(x, plot.bottom + _kXLabelGap));
    }

    // Axis titles.
    final xTitle = _xTitle;
    if (xTitle != null) {
      xTitle.paint(
        canvas,
        Offset(
          plot.left + (plot.width - xTitle.width) / 2,
          _layoutSize.height - xTitle.height,
        ),
      );
    }
    final yTitle = _yTitle;
    if (yTitle != null) {
      canvas.save();
      canvas.translate(0, plot.top + (plot.height + yTitle.width) / 2);
      canvas.rotate(-math.pi / 2);
      yTitle.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  /// Paints the series.
  void paintData(Canvas canvas) {
    final target = _space;
    if (target == null || _painters.isEmpty) return;
    final space = _effectiveSpace(target);
    final entrance = _entranceT;
    final morph = _morphT;
    canvas.save();
    // Clip with a small margin so round caps at the domain edge survive.
    canvas.clipRect(space.plotArea.inflate(4));
    for (final painter in _painters) {
      painter.paint(canvas, space, theme, entrance: entrance, morph: morph);
    }
    canvas.restore();
  }

  /// Paints crosshair, hover markers and the built-in tooltip (or, in
  /// radial mode, the hovered segment's halo).
  void paintInteraction(Canvas canvas) {
    final target = _space;
    final hover = _hover;
    if (target == null || hover == null) return;

    if (_radial) {
      // Halo arc just outside the hovered segment — painted on this layer
      // so hovering never repaints the donut itself.
      final index = hover.x.round();
      if (index >= 0 && index < _donutBounds.length - 1) {
        final gapAngle = _donutOuter <= 0 ? 0.0 : _donutGap / 2 / _donutOuter;
        final a0 = _donutStartAngle + _donutBounds[index] + gapAngle;
        final a1 = _donutStartAngle + _donutBounds[index + 1] - gapAngle;
        if (a1 > a0) {
          canvas.drawArc(
            Rect.fromCircle(center: _donutCenter, radius: _donutOuter + 4),
            a0,
            a1 - a0,
            false,
            Paint()
              ..color = hover.points.first.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      final layout = _tooltipLayout;
      if (layout != null) {
        _paintTooltip(canvas, hover, layout);
      }
      return;
    }

    final space = _effectiveSpace(target);
    final plot = space.plotArea;
    final crosshair = _crosshair;

    if (crosshair != null && crosshair.showLine) {
      canvas.drawLine(
        Offset(hover.xPixel, plot.top),
        Offset(hover.xPixel, plot.bottom),
        Paint()
          ..color = theme.axisLineColor
          ..strokeWidth = 1,
      );
    }

    if (crosshair != null && crosshair.showMarkers) {
      for (final p in hover.points) {
        if (_series[p.seriesIndex] is BarSeries) continue;
        final center = space.toPixel(Offset(p.x, p.y));
        if (!plot.inflate(6).contains(center)) continue;
        // Surface-color ring around a series-color fill.
        canvas.drawCircle(
          center,
          _kMarkerRadius + _kMarkerRingWidth,
          Paint()..color = theme.surfaceColor,
        );
        canvas.drawCircle(center, _kMarkerRadius, Paint()..color = p.color);
      }
    }

    final layout = _tooltipLayout;
    if (layout != null) {
      _paintTooltip(canvas, hover, layout);
    }
  }

  void _paintTooltip(
    Canvas canvas,
    ChartHoverInfo hover,
    _TooltipLayout layout,
  ) {
    final size = _layoutSize;
    final tooltipSize = layout.size;
    // Right of the crosshair; flip left when it would overflow.
    var left = hover.xPixel + 14;
    if (left + tooltipSize.width > size.width - 4) {
      left = hover.xPixel - 14 - tooltipSize.width;
    }
    left = math.max(
      4.0,
      math.min(left, math.max(4.0, size.width - tooltipSize.width - 4)),
    );
    final top = math.max(
      4.0,
      math.min(
        hover.position.dy - tooltipSize.height - 14,
        math.max(4.0, size.height - tooltipSize.height - 4),
      ),
    );

    final rrect = RRect.fromRectAndRadius(
      Offset(left, top) & tooltipSize,
      const Radius.circular(8),
    );
    canvas.drawShadow(
      Path()..addRRect(rrect),
      const Color(0x55000000),
      4,
      true,
    );
    canvas.drawRRect(rrect, Paint()..color = theme.tooltipBackgroundColor);

    var y = top + _TooltipLayout.pad;
    final textLeft = left + _TooltipLayout.pad;
    layout.header.paint(canvas, Offset(textLeft, y));
    y += layout.header.height;
    for (final row in layout.rows) {
      y += _TooltipLayout.rowGap;
      final rowHeight = math.max(row.label.height, _TooltipLayout.chip);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            textLeft,
            y + (rowHeight - _TooltipLayout.chip) / 2,
            _TooltipLayout.chip,
            _TooltipLayout.chip,
          ),
          const Radius.circular(2.5),
        ),
        Paint()..color = row.color,
      );
      row.label.paint(
        canvas,
        Offset(
          textLeft + _TooltipLayout.chip + _TooltipLayout.chipGap,
          y + (rowHeight - row.label.height) / 2,
        ),
      );
      row.value.paint(
        canvas,
        Offset(
          left + tooltipSize.width - _TooltipLayout.pad - row.value.width,
          y + (rowHeight - row.value.height) / 2,
        ),
      );
      y += rowHeight;
    }
  }
}
