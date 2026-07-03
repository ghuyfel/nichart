# nichart

Beautiful, animated, theme-aware charts for Flutter — with gorgeous defaults.

nichart's differentiator is what you get for free: a smooth, theme-aware,
production-quality chart from three lines of code. Deep customization is
available, but never required.

```dart
import 'package:nichart/nichart.dart';

Chart.line(data: [DataPoint(0, 2), DataPoint(1, 5), DataPoint(2, 3)])
```

- **Pure Dart.** All rendering via `dart:ui` on a custom `RenderBox` — no
  platform channels, no native code. Android, iOS, Windows, macOS, Linux, Web.
- **Zero required configuration.** Every styling parameter has an opinionated
  default: 2 px round-capped strokes, monotone cubic smoothing (Fritsch–Carlson
  — no overshoot), horizontal hairline grid, minimal axes, 11 px tabular-figure
  labels, an 8-color palette.
- **Automatic dark mode.** Charts derive their theme from
  `Theme.of(context)` — gridlines, labels and palettes flip correctly with zero
  user code. Override per-subtree with `ChartThemeScope`, or white-label via
  `ChartTheme.fromColorScheme(scheme)`.
- **Motion built in.** Series animate in on first layout (path reveal,
  staggered bar growth), and data changes *morph* — points lerp old → new
  while the axes glide. Respects reduced-motion settings; opt out with
  `ChartAnimation.none()`.

## Usage

Composed form:

```dart
Chart(
  axes: const ChartAxes.cartesian(
    x: TimeAxis(),
    y: NumericAxis(label: 'Users'),
  ),
  series: [
    LineSeries(
      data: thisWeek,
      style: const LineStyle.smooth(area: AreaFill.gradient()),
    ),
    LineSeries(
      data: lastWeek,
      style: const LineStyle.context(), // muted, dashed comparison series
    ),
  ],
)
```

Every chart ships with a crosshair and tooltip (hover on desktop, drag or
long-press on touch). Pan/zoom is one line more:

```dart
Chart(
  series: [LineSeries(data: points)],
  interactions: const [Crosshair(), ChartTooltip(), PanZoom()],
  controller: controller, // optional ChartController for programmatic zoom
)
```

Bars need zero axis configuration — the category axis is inferred from the
data:

```dart
Chart(series: [BarSeries(data: weekCounts)])            // rounded weekday bars
Chart(series: [BarSeries(data: weekCounts, emphasizedIndex: 5)]) // highlight one
Chart(
  series: [/* ... */],
  emphasis: const SeriesEmphasis(id: 'north'),          // mute all but one series
)
```

Series accept any element type — pass your domain models directly:

```dart
LineSeries(
  data: signups,
  xAccessor: (s) => s.day.toDouble(),
  yAccessor: (s) => s.count.toDouble(),
)
```

`DataPoint`, `TimePoint` and `CategoryPoint` are provided out of the box and
need no accessors.

Donuts and sparklines are one-liners too:

```dart
DonutChart(data: shares, center: Text('84%'))   // 72% cutout, sweep entrance
Sparkline(data: last30Days)                     // gradient mini line
Sparkline.bars(data: weekCounts, emphasizeLast: true)
```

Large data just works: series beyond ~2× the plot width in points are
LTTB-downsampled automatically (shape-preserving, raw data untouched),
scatter clouds batch through `drawRawPoints`, and the chart paints in three
isolated layers so the crosshair never repaints your series. The example
app includes a 500k-point stress page with a live fps readout.

## Status

**Stable (1.0)** — the public API follows semantic versioning; breaking
changes only in major releases. Milestones built along the way:

| Milestone | Contents | Status |
|---|---|---|
| M1 — Core | `RenderBox` shell, cartesian coordinates, `NumericScale` + nice ticks, `LineSeries` with monotone splines, grid/axes, light/dark theming, goldens | ✅ |
| M2 — Series | Area (gradient), Bar (grouped/stacked), Scatter, Time/Category scales, emphasis pattern | ✅ |
| M3 — Motion | Entrance animations, data-change morphing | ✅ |
| M4 — Interaction | Crosshair, tooltip, hover markers, pan/zoom, `ChartController` | ✅ |
| M5 — Scale | Layered repaint, LTTB downsampling, 100k-point stress test | ✅ |
| M6 — Polish | Donut, Sparkline, full gallery, pub.dev readiness | ✅ |

Charts are screen-reader friendly out of the box (auto-composed semantic
labels, overridable via `semanticLabel:`), and `ChartLegend` renders a
legend from the same series list the chart uses.

Planned as additive releases: horizontal bars, `LogScale`, and
`PictureRecorder`-based PNG/SVG export (painting is already decoupled from
the widget layer by design).

## Example

The [example app](example/) is a gallery that doubles as the documentation —
each page shows its own source. Run it with `flutter run` from `example/`
(web, desktop and mobile).

## License

MIT © ghuyfel
