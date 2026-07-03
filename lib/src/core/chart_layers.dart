// Internal render objects that paint a shared ChartScene as three
// compositor-isolated layers. Each layer IS a repaint boundary, so a
// crosshair move (interaction layer) never re-rasterizes the series (data
// layer) or the grid (static layer).

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'chart_scene.dart';

/// Which part of the scene a paint layer draws.
enum ChartLayerKind {
  /// Grid, axis baseline, tick labels, titles.
  background,

  /// Series.
  data,
}

/// A paint-only chart layer (background or data).
class ChartLayerWidget extends LeafRenderObjectWidget {
  /// Creates a layer painting [kind] of [scene].
  const ChartLayerWidget({super.key, required this.scene, required this.kind});

  /// The shared scene.
  final ChartScene scene;

  /// Which layer this widget paints.
  final ChartLayerKind kind;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderChartLayer(scene, kind);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderChartLayer renderObject,
  ) {
    renderObject.scene = scene;
  }
}

/// Renders one paint layer of a [ChartScene].
class RenderChartLayer extends RenderBox {
  /// Creates a layer render box.
  RenderChartLayer(this._scene, this.kind);

  /// Which layer this render box paints.
  final ChartLayerKind kind;

  ChartScene _scene;

  /// The shared scene.
  ChartScene get scene => _scene;
  set scene(ChartScene value) {
    if (identical(value, _scene)) return;
    if (attached) _unsubscribe(_scene);
    _scene = value;
    if (attached) _subscribe(value);
    markNeedsLayout();
  }

  void _subscribe(ChartScene scene) {
    scene.layoutChanged.addListener(markNeedsLayout);
    scene.dataChanged.addListener(markNeedsPaint);
  }

  void _unsubscribe(ChartScene scene) {
    scene.layoutChanged.removeListener(markNeedsLayout);
    scene.dataChanged.removeListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _subscribe(_scene);
  }

  @override
  void detach() {
    _unsubscribe(_scene);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    _scene.ensureLayout(size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    switch (kind) {
      case ChartLayerKind.background:
        _scene.paintStatic(canvas);
      case ChartLayerKind.data:
        _scene.paintData(canvas);
    }
    canvas.restore();
  }
}

/// The interaction layer: paints crosshair/markers/tooltip and owns all
/// pointer handling for the chart (hit testing lives here, on the render
/// box).
class ChartInteractionWidget extends LeafRenderObjectWidget {
  /// Creates the interaction layer for [scene].
  const ChartInteractionWidget({super.key, required this.scene});

  /// The shared scene.
  final ChartScene scene;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderChartInteraction(scene);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderChartInteraction renderObject,
  ) {
    renderObject.scene = scene;
  }
}

/// Renders the interaction layer and routes pointer events to the scene.
class RenderChartInteraction extends RenderBox
    implements MouseTrackerAnnotation {
  /// Creates the interaction render box.
  RenderChartInteraction(this._scene);

  ChartScene _scene;

  /// The shared scene.
  ChartScene get scene => _scene;
  set scene(ChartScene value) {
    if (identical(value, _scene)) return;
    if (attached) _unsubscribe(_scene);
    _scene = value;
    if (attached) _subscribe(value);
    markNeedsLayout();
  }

  void _subscribe(ChartScene scene) {
    scene.layoutChanged.addListener(markNeedsLayout);
    scene.interactionChanged.addListener(markNeedsPaint);
  }

  void _unsubscribe(ChartScene scene) {
    scene.layoutChanged.removeListener(markNeedsLayout);
    scene.interactionChanged.removeListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _subscribe(_scene);
  }

  @override
  void detach() {
    _unsubscribe(_scene);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    _scene.ensureLayout(size);
  }

  @override
  bool hitTestSelf(Offset position) => _scene.interactive;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    _scene.handlePointerEvent(event);
  }

  @override
  MouseCursor get cursor => _scene.cursor;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => _scene.handleMouseExit;

  @override
  bool get validForMouseTracker => attached && _scene.interactive;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _scene.paintInteraction(canvas);
    canvas.restore();
  }
}

/// Gives the chart a sensible default size (16:9 at 400 px) under
/// unbounded constraints, and passes tight constraints down so the layer
/// stack fills it exactly.
class ChartViewport extends SingleChildRenderObjectWidget {
  /// Creates a chart viewport around the layer stack.
  const ChartViewport({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderChartViewport();
}

/// Render object for [ChartViewport].
class RenderChartViewport extends RenderProxyBox {
  @override
  void performLayout() {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : kDefaultChartSize.width;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : width * kDefaultChartSize.height / kDefaultChartSize.width;
    size = constraints.constrain(Size(width, height));
    child?.layout(BoxConstraints.tight(size));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : kDefaultChartSize.width;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : width * kDefaultChartSize.height / kDefaultChartSize.width;
    return constraints.constrain(Size(width, height));
  }
}
