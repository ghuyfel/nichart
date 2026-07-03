import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nichart/nichart.dart';

void main() => runApp(const GalleryApp());

/// nichart gallery — doubles as the package's living documentation.
///
/// M1: line charts, theming. M2: area, bars (grouped/stacked/emphasis),
/// scatter, time & category axes. More pages arrive with each milestone.
class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  ThemeMode _mode = ThemeMode.light;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B7CFA);
    return MaterialApp(
      title: 'nichart gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed)),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      themeMode: _mode,
      home: Builder(
        builder: (context) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            appBar: AppBar(
              title: const Text('nichart'),
              actions: [
                IconButton(
                  tooltip:
                      dark ? 'Switch to light mode' : 'Switch to dark mode',
                  icon: Icon(dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                  onPressed: () => setState(() {
                    _mode = _mode == ThemeMode.light
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  }),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Row(
              children: [
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height - 100,
                    ),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _page,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: (i) =>
                            setState(() => _page = i),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            label: Text('Dashboard'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.show_chart),
                            label: Text('Lines'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.bar_chart),
                            label: Text('Bars & parts'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.scatter_plot_outlined),
                            label: Text('Scatter'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.stacked_line_chart),
                            label: Text('Sparklines'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.animation),
                            label: Text('Motion'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.touch_app_outlined),
                            label: Text('Interact'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.speed_outlined),
                            label: Text('Stress'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.palette_outlined),
                            label: Text('Theming'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: switch (_page) {
                    0 => const DashboardPage(),
                    1 => const LinesPage(),
                    2 => const BarsPage(),
                    3 => const ScatterPage(),
                    4 => const SparklinesPage(),
                    5 => const MotionPage(),
                    6 => const InteractionPage(),
                    7 => const StressPage(),
                    _ => const ThemingPage(),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _thisWeek = [
  DataPoint(0, 120),
  DataPoint(1, 180),
  DataPoint(2, 95),
  DataPoint(3, 240),
  DataPoint(4, 205),
  DataPoint(5, 330),
  DataPoint(6, 290),
  DataPoint(7, 410),
];

const _lastWeek = [
  DataPoint(0, 140),
  DataPoint(1, 130),
  DataPoint(2, 160),
  DataPoint(3, 150),
  DataPoint(4, 235),
  DataPoint(5, 260),
  DataPoint(6, 305),
  DataPoint(7, 300),
];

const _weekdays = [
  CategoryPoint('Mon', 12),
  CategoryPoint('Tue', 18),
  CategoryPoint('Wed', 9),
  CategoryPoint('Thu', 24),
  CategoryPoint('Fri', 21),
  CategoryPoint('Sat', 30),
  CategoryPoint('Sun', 16),
];

const _weekdaysB = [
  CategoryPoint('Mon', 8),
  CategoryPoint('Tue', 11),
  CategoryPoint('Wed', 14),
  CategoryPoint('Thu', 10),
  CategoryPoint('Fri', 16),
  CategoryPoint('Sat', 12),
  CategoryPoint('Sun', 9),
];

/// KPI tiles with sparklines + a hero area chart with a custom legend.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return _PageList(
      children: [
        Row(
          children: [
            for (final (title, value, delta, spark, bars) in const [
              ('Active users', '4,812', '+12.4%',
                  [12.0, 18.0, 14.0, 24.0, 21.0, 33.0, 29.0, 41.0], false),
              ('Signups', '318', '+4.1%',
                  [8.0, 6.0, 12.0, 9.0, 14.0, 11.0, 16.0, 18.0], true),
              ('Churn', '1.9%', '−0.3%',
                  [22.0, 19.0, 21.0, 17.0, 18.0, 15.0, 14.0, 12.0], false),
            ]) ...[
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(value, style: textTheme.headlineSmall),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                delta,
                                style: textTheme.labelSmall
                                    ?.copyWith(color: scheme.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          width: double.infinity,
                          child: bars
                              ? Sparkline.bars(
                                  data: spark, emphasizeLast: true)
                              : Sparkline(data: spark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if ((title, value) != ('Churn', '1.9%'))
                const SizedBox(width: 12),
            ],
          ],
        ),
        ChartCard(
          title: 'Weekly active users',
          subtitle: 'Gradient area, context series, crosshair + tooltip — '
              'and a hand-rolled legend, because legends are just widgets.',
          chart: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final (label, color) in [
                    ('This week', ChartPalettes.categoricalLight[0]),
                    ('Last week', Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38)),
                  ]) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(label, style: textTheme.labelSmall),
                    const SizedBox(width: 16),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Chart(
                  axes: const ChartAxes.cartesian(
                    y: NumericAxis(min: 0),
                  ),
                  series: [
                    LineSeries<DataPoint>(
                      data: _thisWeek,
                      label: 'This week',
                      style:
                          const LineStyle.smooth(area: AreaFill.gradient()),
                    ),
                    LineSeries<DataPoint>(
                      data: _lastWeek,
                      label: 'Last week',
                      style: const LineStyle.context(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          source: '''
Chart(
  series: [
    LineSeries(
      data: thisWeek,
      style: const LineStyle.smooth(area: AreaFill.gradient()),
    ),
    LineSeries(data: lastWeek, style: const LineStyle.context()),
  ],
)''',
        ),
      ],
    );
  }
}

/// Stat cards with embedded sparklines.
class SparklinesPage extends StatelessWidget {
  const SparklinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const rows = [
      ('Revenue', '\$12.4k', [4.0, 6.0, 5.0, 9.0, 7.0, 12.0, 10.0, 14.0]),
      ('Orders', '862', [30.0, 28.0, 34.0, 31.0, 38.0, 35.0, 42.0, 40.0]),
      ('Sessions', '18.1k', [9.0, 12.0, 8.0, 14.0, 13.0, 11.0, 16.0, 19.0]),
      ('Errors', '23', [9.0, 7.0, 8.0, 5.0, 6.0, 4.0, 3.0, 2.0]),
    ];
    return _PageList(
      children: [
        for (final (title, value, values) in rows)
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(title, style: textTheme.bodyMedium),
              subtitle: Text(value, style: textTheme.headlineSmall),
              trailing: SizedBox(
                width: 160,
                height: 44,
                child: title == 'Orders'
                    ? Sparkline.bars(data: values, emphasizeLast: true)
                    : Sparkline(data: values),
              ),
            ),
          ),
        ChartCard(
          title: 'One line of code',
          subtitle: 'Sparklines take a plain List<double>. No axes, no '
              'configuration, theme-aware.',
          chart: const Center(
            child: SizedBox(
              width: 320,
              height: 64,
              child: Sparkline(
                data: [12, 18, 9, 24, 21, 33, 29, 41, 35, 48],
              ),
            ),
          ),
          source: '''
Sparkline(data: last30Days)
Sparkline.bars(data: weekCounts, emphasizeLast: true)''',
        ),
      ],
    );
  }
}

/// Automatic dark mode + white-label brand themes.
class ThemingPage extends StatelessWidget {
  const ThemingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brandScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Theme.of(context).brightness,
    );
    final brandTheme = ChartTheme.fromColorScheme(brandScheme).copyWith(
      palette: const [
        Color(0xFF0F766E),
        Color(0xFFD97706),
        Color(0xFF7C3AED),
        Color(0xFFDB2777),
        Color(0xFF2563EB),
        Color(0xFF65A30D),
        Color(0xFF0891B2),
        Color(0xFFEA580C),
      ],
    );
    return _PageList(
      children: [
        ChartCard(
          title: 'Automatic',
          subtitle: 'With zero configuration, charts derive everything from '
              'Theme.of(context) — flip the app theme (top right) and '
              'watch gridlines, labels, tooltips and palettes follow.',
          chart: Chart(
            series: [
              LineSeries<DataPoint>(
                data: _thisWeek,
                style: const LineStyle.smooth(area: AreaFill.gradient()),
              ),
              LineSeries<DataPoint>(
                data: _lastWeek,
                style: const LineStyle.context(),
              ),
            ],
          ),
          source: '''
// Nothing to do. ChartTheme.of(context) derives from the
// ambient ColorScheme, light or dark.
Chart(series: [...])''',
        ),
        ChartCard(
          title: 'White-label brand theme',
          subtitle: 'ChartThemeScope re-themes every chart below it; '
              'ChartTheme.fromColorScheme + copyWith for full control.',
          chart: ChartThemeScope(
            theme: brandTheme,
            child: Chart(
              series: [
                BarSeries<CategoryPoint>(data: _weekdays),
                BarSeries<CategoryPoint>(data: _weekdaysB),
              ],
            ),
          ),
          source: '''
final brand = ChartTheme.fromColorScheme(brandScheme)
    .copyWith(palette: brandPalette);

ChartThemeScope(
  theme: brand,
  child: DashboardGrid(),  // every chart inside is re-themed
)''',
        ),
      ],
    );
  }
}

/// Lines, areas, context series and time axes.
class LinesPage extends StatelessWidget {
  const LinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageList(
      children: [
        ChartCard(
          title: 'Area with context series',
          subtitle: 'The signature look: gradient fill, monotone smoothing, '
              'muted comparison — all defaults.',
          chart: Chart(
            axes: const ChartAxes.cartesian(
              y: NumericAxis(label: 'Users', min: 0),
            ),
            series: [
              LineSeries<DataPoint>(
                data: _thisWeek,
                style: const LineStyle.smooth(area: AreaFill.gradient()),
              ),
              LineSeries<DataPoint>(
                data: _lastWeek,
                style: const LineStyle.context(),
              ),
            ],
          ),
          source: '''
Chart(
  axes: const ChartAxes.cartesian(y: NumericAxis(label: 'Users', min: 0)),
  series: [
    LineSeries(
      data: thisWeek,
      style: const LineStyle.smooth(area: AreaFill.gradient()),
    ),
    LineSeries(data: lastWeek, style: const LineStyle.context()),
  ],
)''',
        ),
        ChartCard(
          title: 'Time axis',
          subtitle: 'Calendar-aware ticks: midnights, month starts. '
              'TimePoint data needs zero configuration.',
          chart: Chart(
            axes: const ChartAxes.cartesian(x: TimeAxis()),
            series: [
              AreaSeries<TimePoint>(
                data: [
                  for (var d = 0; d < 14; d++)
                    TimePoint(
                      DateTime(2026, 3, 1 + d),
                      100 + 40 * (d % 5) + 12.0 * d,
                    ),
                ],
              ),
            ],
          ),
          source: '''
Chart(
  axes: const ChartAxes.cartesian(x: TimeAxis()),
  series: [AreaSeries(data: dailyUsers)],
)''',
        ),
        ChartCard(
          title: 'Emphasis: highlight one, mute the rest',
          subtitle: 'SeriesEmphasis renders one series at full saturation '
              'and drops the others to 30%.',
          chart: Chart(
            series: [
              LineSeries<DataPoint>(data: _lastWeek, id: 'east'),
              LineSeries<DataPoint>(data: _thisWeek, id: 'west'),
              LineSeries<DataPoint>(
                id: 'north',
                data: const [
                  DataPoint(0, 60),
                  DataPoint(2, 150),
                  DataPoint(4, 120),
                  DataPoint(6, 280),
                  DataPoint(7, 350),
                ],
              ),
            ],
            emphasis: const SeriesEmphasis(id: 'north'),
          ),
          source: '''
Chart(
  series: [
    LineSeries(data: east, id: 'east'),
    LineSeries(data: west, id: 'west'),
    LineSeries(data: north, id: 'north'),
  ],
  emphasis: const SeriesEmphasis(id: 'north'),
)''',
        ),
        ChartCard(
          title: 'The one-liner',
          subtitle: 'Everything below is a single expression.',
          chart: Chart.line(data: _thisWeek),
          source: 'Chart.line(data: points)',
        ),
      ],
    );
  }
}

/// Bars: grouped, stacked, single-bar emphasis.
class BarsPage extends StatefulWidget {
  const BarsPage({super.key});

  @override
  State<BarsPage> createState() => _BarsPageState();
}

class _BarsPageState extends State<BarsPage> {
  bool _stacked = false;

  @override
  Widget build(BuildContext context) {
    final arrangement =
        _stacked ? BarArrangement.stacked : BarArrangement.grouped;
    return _PageList(
      children: [
        ChartCard(
          title: 'Weekday bars',
          subtitle: 'CategoryPoint data — the category axis is inferred. '
              'Rounded data ends, square baselines, max 24 px thick.',
          trailing: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Grouped')),
              ButtonSegment(value: true, label: Text('Stacked')),
            ],
            selected: {_stacked},
            onSelectionChanged: (s) => setState(() => _stacked = s.first),
          ),
          chart: Chart(
            series: [
              BarSeries<CategoryPoint>(
                data: _weekdays,
                arrangement: arrangement,
              ),
              BarSeries<CategoryPoint>(
                data: _weekdaysB,
                arrangement: arrangement,
              ),
            ],
          ),
          source: '''
Chart(
  series: [
    BarSeries(data: signups),   // arrangement: grouped | stacked
    BarSeries(data: upgrades),
  ],
)''',
        ),
        ChartCard(
          title: 'Single-bar emphasis',
          subtitle: 'emphasizedIndex highlights one bar and mutes its '
              'siblings — perfect for "today" in a week view.',
          chart: Chart(
            series: [
              BarSeries<CategoryPoint>(data: _weekdays, emphasizedIndex: 5),
            ],
          ),
          source: '''
Chart(
  series: [BarSeries(data: weekCounts, emphasizedIndex: 5)],
)''',
        ),
        ChartCard(
          title: 'Donut with a hero number',
          subtitle: '72% cutout, 2 px gaps, rounded segment ends, sweep '
              'entrance — and any widget in the center.',
          chart: DonutChart(
            style: DonutStyle(radius: 100),
            data: const [
              CategoryPoint('Direct', 44),
              CategoryPoint('Search', 31),
              CategoryPoint('Referral', 15),
              CategoryPoint('Other', 10),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('4,812',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text('visits', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          source: '''
DonutChart(
  data: trafficShares,           // CategoryPoint list
  center: Text('4,812'),         // any widget
)

// Or composed, pie included:
Chart(series: [DonutSeries(data: shares)])
Chart(series: [DonutSeries(data: shares, style: DonutStyle(cutout: 0))])''',
        ),
      ],
    );
  }
}

/// Scatter clouds.
class ScatterPage extends StatelessWidget {
  const ScatterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = <DataPoint>[
      for (var i = 0; i < 80; i++)
        DataPoint((i * 37 % 101) / 10, (i * 53 % 89) / 8 + (i * 37 % 101) / 16),
    ];
    return _PageList(
      children: [
        ChartCard(
          title: 'Scatter',
          subtitle: 'Slightly translucent markers so overlap reads as '
              'density.',
          chart: Chart(
            series: [ScatterSeries<DataPoint>(data: cloud)],
          ),
          source: 'Chart(series: [ScatterSeries(data: samples)])',
        ),
      ],
    );
  }
}

/// Entrance animation and data-change morphing.
class MotionPage extends StatefulWidget {
  const MotionPage({super.key});

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  var _generation = 0;
  var _entranceKey = 0;

  List<DataPoint> get _morphData => [
        for (var i = 0; i < 8; i++)
          DataPoint(
            i.toDouble(),
            // Deterministic pseudo-random walk per generation.
            60 + ((i * 37 + _generation * 53) % 89) * 4.0,
          ),
      ];

  List<CategoryPoint> get _morphBars => [
        for (final (i, day) in const [
          'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
        ].indexed)
          CategoryPoint(day, 4 + ((i * 29 + _generation * 41) % 31).toDouble()),
      ];

  @override
  Widget build(BuildContext context) {
    return _PageList(
      children: [
        ChartCard(
          title: 'Data-change morphing',
          subtitle: 'Change data and the chart lerps old → new, axes '
              'gliding along. No configuration — it is the default.',
          trailing: FilledButton.tonalIcon(
            onPressed: () => setState(() => _generation++),
            icon: const Icon(Icons.shuffle),
            label: const Text('Shuffle'),
          ),
          chart: Chart(
            series: [
              LineSeries<DataPoint>(
                data: _morphData,
                style: const LineStyle.smooth(area: AreaFill.gradient()),
              ),
            ],
          ),
          source: '''
// Just pass new data — the chart morphs.
Chart(series: [LineSeries(data: newData)])

// Opt out per chart:
Chart(series: [...], animation: const ChartAnimation.none())''',
        ),
        ChartCard(
          title: 'Bars morph too',
          subtitle: 'Bars grow, shrink and re-stack point-by-point.',
          trailing: FilledButton.tonalIcon(
            onPressed: () => setState(() => _generation++),
            icon: const Icon(Icons.shuffle),
            label: const Text('Shuffle'),
          ),
          chart: Chart(
            series: [BarSeries<CategoryPoint>(data: _morphBars)],
          ),
          source: 'Chart(series: [BarSeries(data: newCounts)])',
        ),
        ChartCard(
          title: 'Entrance',
          subtitle: 'Lines reveal along their path; bars rise from the '
              'baseline with a stagger. ~600 ms, easeOutCubic.',
          trailing: FilledButton.tonalIcon(
            onPressed: () => setState(() => _entranceKey++),
            icon: const Icon(Icons.replay),
            label: const Text('Replay'),
          ),
          chart: Chart(
            key: ValueKey(_entranceKey),
            series: [
              BarSeries<CategoryPoint>(
                data: const [
                  CategoryPoint('Mon', 12),
                  CategoryPoint('Tue', 18),
                  CategoryPoint('Wed', 9),
                  CategoryPoint('Thu', 24),
                  CategoryPoint('Fri', 21),
                  CategoryPoint('Sat', 30),
                  CategoryPoint('Sun', 16),
                ],
              ),
            ],
          ),
          source: '''
// Entrance runs on first layout, automatically.
// Respects MediaQuery.disableAnimations (reduced motion).
Chart(series: [BarSeries(data: weekCounts)])''',
        ),
      ],
    );
  }
}

/// Crosshair, tooltip, pan/zoom and the ChartController.
class InteractionPage extends StatefulWidget {
  const InteractionPage({super.key});

  @override
  State<InteractionPage> createState() => _InteractionPageState();
}

class _InteractionPageState extends State<InteractionPage> {
  final ChartController _controller = ChartController();

  List<DataPoint> get _dense => [
        for (var i = 0; i <= 120; i++)
          DataPoint(
            i.toDouble(),
            140 +
                ((i * 37) % 89) * 1.6 +
                ((i * 13) % 23) * 3.0 +
                i * 0.8,
          ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageList(
      children: [
        ChartCard(
          title: 'Crosshair & tooltip',
          subtitle: 'On by default: hover with a mouse, drag or long-press '
              'on touch. Index mode — the crosshair snaps to the nearest x '
              'across all series.',
          chart: Chart(
            series: [
              LineSeries<DataPoint>(data: _thisWeek, label: 'This week'),
              LineSeries<DataPoint>(
                data: _lastWeek,
                label: 'Last week',
                style: const LineStyle.context(),
              ),
            ],
          ),
          source: '''
// Crosshair + tooltip are the default interactions:
Chart(series: [...])

// Customize or disable:
Chart(series: [...], interactions: const [
  Crosshair(showMarkers: true),
  ChartTooltip(),        // or ChartTooltip(builder: ...)
])''',
        ),
        ChartCard(
          title: 'Pan & zoom playground',
          subtitle: 'Drag to pan, pinch or Ctrl/⌘+scroll to zoom, '
              'double-tap to reset. Clamped to the data with rubber-band '
              'edges.',
          trailing: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final window = _controller.xDomain;
              return FilledButton.tonalIcon(
                onPressed: window == null
                    ? null
                    : () => _controller.reset(),
                icon: const Icon(Icons.zoom_out_map),
                label: Text(
                  window == null
                      ? 'Full domain'
                      : '${window.min.toStringAsFixed(1)} – '
                          '${window.max.toStringAsFixed(1)}',
                ),
              );
            },
          ),
          chart: Chart(
            series: [
              LineSeries<DataPoint>(
                data: _dense,
                style: const LineStyle.smooth(area: AreaFill.gradient()),
              ),
            ],
            interactions: const [Crosshair(), ChartTooltip(), PanZoom()],
            controller: _controller,
          ),
          source: '''
final controller = ChartController();

Chart(
  series: [LineSeries(data: points)],
  interactions: const [Crosshair(), ChartTooltip(), PanZoom()],
  controller: controller,
);

controller.setXDomain(20, 60);  // programmatic zoom
controller.reset();             // back to full domain''',
        ),
        ChartCard(
          title: 'Custom tooltip builder',
          subtitle: 'ChartTooltip(builder: ...) swaps the built-in card for '
              'any widget.',
          chart: Chart(
            series: [
              BarSeries<CategoryPoint>(data: _weekdays, label: 'Signups'),
            ],
            interactions: [
              const Crosshair(showMarkers: false),
              ChartTooltip(
                builder: (context, info) => Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${info.xLabel}: '
                      '${info.points.first.y.toStringAsFixed(0)} signups',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
          source: '''
ChartTooltip(
  builder: (context, info) => MyCard(
    label: info.xLabel,
    points: info.points, // color, label, x, y per series
  ),
)''',
        ),
      ],
    );
  }
}

/// 100k points, live frame-time readout, LTTB toggle.
class StressPage extends StatefulWidget {
  const StressPage({super.key});

  @override
  State<StressPage> createState() => _StressPageState();
}

class _StressPageState extends State<StressPage> {
  static const _counts = [10000, 100000, 500000];
  int _count = 100000;
  bool _lttb = true;
  final Map<int, List<DataPoint>> _cache = {};
  final ValueNotifier<String> _frameStats = ValueNotifier('—');
  final List<Duration> _spans = [];
  late final TimingsCallback _timingsCallback;

  List<DataPoint> _data(int n) => _cache.putIfAbsent(n, () {
        final random = math.Random(42);
        var y = 500.0;
        return [
          for (var i = 0; i < n; i++)
            DataPoint(i.toDouble(), y += random.nextDouble() * 8 - 4),
        ];
      });

  @override
  void initState() {
    super.initState();
    _timingsCallback = (List<FrameTiming> timings) {
      _spans.addAll(timings.map((t) => t.totalSpan));
      if (_spans.length < 8) return;
      final avgMs =
          _spans.fold(0, (sum, d) => sum + d.inMicroseconds) /
              _spans.length /
              1000;
      _spans.clear();
      _frameStats.value =
          '${(1000 / avgMs).clamp(0, 999).toStringAsFixed(0)} fps · '
          '${avgMs.toStringAsFixed(1)} ms/frame';
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    _frameStats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageList(
      children: [
        ChartCard(
          title: 'Stress test',
          subtitle: 'A ${_count ~/ 1000}k-point random walk. Pan and zoom '
              'it (drag / pinch / Ctrl+scroll). LTTB keeps the painted '
              'point count near 2× the plot width; toggle it off to feel '
              'the difference.',
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SegmentedButton<int>(
                segments: [
                  for (final c in _counts)
                    ButtonSegment(value: c, label: Text('${c ~/ 1000}k')),
                ],
                selected: {_count},
                onSelectionChanged: (s) => setState(() => _count = s.first),
              ),
              const SizedBox(height: 8),
              FilterChip(
                label: const Text('LTTB'),
                selected: _lttb,
                onSelected: (v) => setState(() => _lttb = v),
              ),
            ],
          ),
          chart: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<String>(
                  valueListenable: _frameStats,
                  builder: (context, stats, _) => Text(
                    stats,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ),
              Expanded(
                child: Chart(
                  series: [
                    LineSeries<DataPoint>(
                      data: _data(_count),
                      downsampling: _lttb
                          ? const Downsampling.auto()
                          : const Downsampling.none(),
                      style: const LineStyle(
                        interpolation: LineInterpolation.linear,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ],
                  interactions: const [
                    Crosshair(),
                    ChartTooltip(),
                    PanZoom(),
                  ],
                  animation: const ChartAnimation.none(),
                ),
              ),
            ],
          ),
          source: '''
LineSeries(
  data: hundredKPoints,             // raw data stays untouched
  downsampling: const Downsampling.auto(),  // ~2× plot width (default)
)

// Layered repaint: the crosshair moves without repainting the series;
// pans re-slice the visible window and re-downsample per frame.''',
        ),
      ],
    );
  }
}

class _PageList extends StatelessWidget {
  const _PageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, i) => children[i],
        ),
      ),
    );
  }
}

/// A gallery card: title, live chart, expandable source snippet.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.chart,
    required this.source,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget chart;
  final String source;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 280, child: chart),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              title: Text('Source', style: textTheme.labelLarge),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    source,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
