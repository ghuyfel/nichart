# Changelog

## 0.6.0

Milestone M6 — polish & ship.

- `DonutSeries` joins the sealed series hierarchy: 72% cutout by default
  (0 = pie), 2 px surface gaps between segments, small corner radius on
  segment ends, clockwise sweep entrance, value morphing aligned by
  category. Palette colors assign per segment in display order.
- `DonutChart` convenience widget with a `center:` slot for hero numbers.
  The slot is constrained to the cutout hole (scaling content down when it
  would not fit), and `DonutStyle.radius` pins the outer radius explicitly
  when the ring should leave more room.
- `Sparkline` / `Sparkline.bars`: axis-less mini charts from a plain
  `List<double>` — smooth gradient line or rounded mini bars with
  `emphasizeLast:`, theme-aware, zero configuration.
- Gallery completed: Dashboard (KPI tiles + hero chart + custom legend),
  Bars & parts (donut with center hero), Sparklines, Theming (automatic
  dark mode + white-label `ChartThemeScope` demo), alongside the existing
  Lines/Scatter/Motion/Interact/Stress pages.

## 0.5.0

Milestone M5 — scale.

- Layered repaint architecture: the chart renders as three
  compositor-isolated layers (grid/axes, series, interaction), each a
  repaint boundary. Moving the crosshair repaints only the interaction
  layer — never the series (covered by a regression test asserting the
  dirty flags).
- LTTB (Largest-Triangle-Three-Buckets) downsampling, on by default:
  line/area series beyond ~2× the plot width in points are reduced before
  painting. `Downsampling.auto()` / `.none()` / `.fixed(n)` per series;
  hover and tooltips always see the raw data. Exposed as `lttbDownsample`
  for direct use.
- Pan/zoom over large series stays cheap: point resolution, stacking and
  extents are cached across window changes; sorted series are sliced to
  the visible window (binary search) before downsampling, so zooming in
  reveals full detail.
- Scatter series above ~1500 points draw as a single
  `Canvas.drawRawPoints` batch into a reused `Float32List` — no per-frame
  allocations.
- Stress-test gallery page: up to 500k points with a live fps / frame-time
  readout and an LTTB toggle.

## 0.4.0

Milestone M4 — interaction.

- Hit testing and gesture recognition live on the chart's render box (the
  render object owns its gesture recognizers — no widget-tree gesture
  detector stacking).
- `Crosshair`: index-mode vertical hairline snapping to the nearest data x
  across all series, with hover markers (series-color fill, 2 px
  surface-color ring). Mouse hover, touch drag (when pan/zoom is off) and
  long-press-drag all scrub.
- `ChartTooltip`: dark rounded card with color chip + label + formatted
  value per series, flipping to stay in bounds; fully custom content via
  `builder:`. Crosshair + tooltip are now the **default** interactions —
  pass `interactions: const []` to opt out.
- `PanZoom`: drag to pan, pinch (touch/trackpad) and Ctrl/⌘+scroll-wheel to
  zoom (modifier configurable), double-tap to reset. Clamped to the data
  domain with rubber-band edge resistance; zoom on x, y or both.
- `ChartController`: programmatic domain windows (`setXDomain`,
  `setXDomainTime`, `setYDomain`, `reset`) with gesture write-back, so
  listeners always see the visible window.
- Desktop polish: precise cursor over inspectable charts, grabbing cursor
  while panning, hover states via `MouseTrackerAnnotation` on the render
  box.
- `ChartTheme` gains `tooltipBackgroundColor` and `tooltipTextStyle`
  (derived from the color scheme's inverse surface).

## 0.3.0

Milestone M3 — motion.

- Entrance animations on first layout: lines/areas reveal progressively
  along their path (via `PathMetrics`), bars grow from the baseline with a
  per-bar stagger, scatter markers pop in. Default 600 ms, `easeOutCubic`.
- Data-change morphing: when `data` changes the chart lerps old → new
  point-by-point (series matched by `id`, points by index; bars by x
  position) and the axis domains glide to their new extents. Interrupted
  morphs continue from the currently displayed state. Default 500 ms.
- `ChartAnimation` configuration on `Chart` (`duration`, `morphDuration`,
  `curve`, `entrance`, `morph`) with `ChartAnimation.none()` to disable.
- Reduced motion respected automatically via
  `MediaQuery.disableAnimations`.
- Animation ticks drive repaints only (`markNeedsPaint`), never widget
  rebuilds or relayouts.
- Breaking: `SeriesPainter.paint` gained `entrance` / `morph` named
  parameters; series painters gained `morphFrom` fields.

## 0.2.0

Milestone M2 — the full cartesian series set.

- `AreaSeries` and `LineStyle.smooth(area:)` / `AreaFill`: the signature
  gradient fill fading from the series color to transparent at the baseline.
- `BarSeries` with `BarArrangement.grouped` / `stacked`: max 24 px thick,
  rounded on the data end only, stacked segments separated by a 2 px gap
  (never a stroke), positives stack up and negatives down. `emphasizedIndex`
  highlights one bar and mutes its siblings.
- `ScatterSeries` with slightly translucent markers.
- `TimeAxis` + `TimeScale`: calendar-aware ticks (whole minutes, midnights,
  month starts) with granularity-matched labels (`14:30`, `Mar 5`, `2026`).
- `CategoryAxis` + `CategoryScale` band scale — inferred automatically for
  `CategoryPoint` data, so `Chart(series: [BarSeries(data: weekCounts)])`
  needs zero axis configuration.
- `SeriesEmphasis`: highlight one series at full saturation (painted on
  top), mute the rest to 30%.
- Bar/area charts automatically include zero in the y domain.
- Breaking: `Series.createPainter` removed (painter construction is
  internal); `Series.xAccessor` is now nullable (`hasXAccessor` /
  `hasCategoryAccessor` probe availability); `CoordinateSpace.xScale` is
  typed `Scale<double>`.

## 0.1.0

Initial release (milestone M1 — core).

- `Chart` widget backed by a custom `RenderBox` (no gesture-detector or
  CustomPaint stacking), with `Chart.line` one-liner convenience constructor.
- Cartesian coordinate system (`CoordinateSpace`) with `NumericScale` and
  nice-tick generation.
- `LineSeries` with Fritsch–Carlson monotone cubic interpolation (no
  overshoot), 2 px round-capped strokes by default, and `LineStyle.context()`
  for muted dashed comparison series.
- Horizontal-hairline-only grid, minimal axes (no y-axis line, no tick marks),
  11 px tabular-figure tick labels.
- `ChartTheme` with `light()` / `dark()` / `fromColorScheme()` factories,
  `ChartThemeScope` inherited override, and automatic adaptation to the
  ambient `Theme.of(context)` brightness with zero configuration.
- 8-color categorical palette assigned in fixed order.
- Golden and unit test suite (scales, ticks, monotone spline no-overshoot,
  theming, label overflow at narrow widths).
