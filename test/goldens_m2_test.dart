@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

const Size _chartSize = Size(600, 400);
const Key _boundaryKey = Key('golden-boundary-m2');

Widget _host(Widget chart, {required Brightness brightness}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B7CFA),
        brightness: brightness,
      ),
    ),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: _chartSize.width,
            height: _chartSize.height,
            color: brightness == Brightness.dark
                ? const Color(0xFF141218)
                : Colors.white,
            padding: const EdgeInsets.all(16),
            child: chart,
          ),
        ),
      ),
    ),
  );
}

Future<void> _expectGolden(
  WidgetTester tester,
  Widget chart,
  Brightness brightness,
  String name,
) async {
  await tester.pumpWidget(_host(chart, brightness: brightness));
  await tester.pumpAndSettle();
  await expectLater(
    find.byKey(_boundaryKey),
    matchesGoldenFile('goldens/$name.png'),
  );
}

List<DataPoint> get _wave => const [
      DataPoint(0, 120),
      DataPoint(1, 180),
      DataPoint(2, 95),
      DataPoint(3, 240),
      DataPoint(4, 205),
      DataPoint(5, 330),
      DataPoint(6, 290),
      DataPoint(7, 410),
    ];

List<CategoryPoint> get _weekdays => const [
      CategoryPoint('Mon', 12),
      CategoryPoint('Tue', 18),
      CategoryPoint('Wed', 9),
      CategoryPoint('Thu', 24),
      CategoryPoint('Fri', 21),
      CategoryPoint('Sat', 30),
      CategoryPoint('Sun', 16),
    ];

List<CategoryPoint> get _weekdaysB => const [
      CategoryPoint('Mon', 8),
      CategoryPoint('Tue', 11),
      CategoryPoint('Wed', 14),
      CategoryPoint('Thu', 10),
      CategoryPoint('Fri', 16),
      CategoryPoint('Sat', 12),
      CategoryPoint('Sun', 9),
    ];

List<DataPoint> get _cloud {
  // Deterministic pseudo-random cloud (no dart:math Random seed drift).
  final points = <DataPoint>[];
  for (var i = 0; i < 60; i++) {
    final x = (i * 37 % 101) / 10;
    final y = (i * 53 % 89) / 8 + x * 0.6;
    points.add(DataPoint(x, y));
  }
  return points;
}

void main() {
  testWidgets('area chart — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(series: [AreaSeries<DataPoint>(data: _wave)]),
      Brightness.light,
      'area_light',
    );
  });

  testWidgets('area chart — dark', (tester) async {
    await _expectGolden(
      tester,
      Chart(series: [AreaSeries<DataPoint>(data: _wave)]),
      Brightness.dark,
      'area_dark',
    );
  });

  testWidgets('grouped bars — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          BarSeries<CategoryPoint>(data: _weekdays),
          BarSeries<CategoryPoint>(data: _weekdaysB),
        ],
      ),
      Brightness.light,
      'bars_grouped_light',
    );
  });

  testWidgets('grouped bars — dark', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          BarSeries<CategoryPoint>(data: _weekdays),
          BarSeries<CategoryPoint>(data: _weekdaysB),
        ],
      ),
      Brightness.dark,
      'bars_grouped_dark',
    );
  });

  testWidgets('stacked bars — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          BarSeries<CategoryPoint>(
            data: _weekdays,
            arrangement: BarArrangement.stacked,
          ),
          BarSeries<CategoryPoint>(
            data: _weekdaysB,
            arrangement: BarArrangement.stacked,
          ),
        ],
      ),
      Brightness.light,
      'bars_stacked_light',
    );
  });

  testWidgets('stacked bars — dark', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          BarSeries<CategoryPoint>(
            data: _weekdays,
            arrangement: BarArrangement.stacked,
          ),
          BarSeries<CategoryPoint>(
            data: _weekdaysB,
            arrangement: BarArrangement.stacked,
          ),
        ],
      ),
      Brightness.dark,
      'bars_stacked_dark',
    );
  });

  testWidgets('single-bar emphasis — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          BarSeries<CategoryPoint>(data: _weekdays, emphasizedIndex: 5),
        ],
      ),
      Brightness.light,
      'bar_emphasis_light',
    );
  });

  testWidgets('scatter — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(series: [ScatterSeries<DataPoint>(data: _cloud)]),
      Brightness.light,
      'scatter_light',
    );
  });

  testWidgets('scatter — dark', (tester) async {
    await _expectGolden(
      tester,
      Chart(series: [ScatterSeries<DataPoint>(data: _cloud)]),
      Brightness.dark,
      'scatter_dark',
    );
  });

  testWidgets('time axis — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        axes: const ChartAxes.cartesian(x: TimeAxis()),
        series: [
          LineSeries<TimePoint>(
            data: [
              for (var d = 0; d < 14; d++)
                TimePoint(
                  DateTime(2026, 3, 1 + d),
                  100 + 40 * (d % 5) + 12.0 * d,
                ),
            ],
            style: const LineStyle(area: AreaFill.gradient()),
          ),
        ],
      ),
      Brightness.light,
      'time_axis_light',
    );
  });

  testWidgets('series emphasis mutes the rest — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          LineSeries<DataPoint>(data: _wave, id: 'a'),
          LineSeries<DataPoint>(
            id: 'b',
            data: const [
              DataPoint(0, 300),
              DataPoint(2, 180),
              DataPoint(4, 260),
              DataPoint(6, 150),
              DataPoint(7, 220),
            ],
          ),
          LineSeries<DataPoint>(
            id: 'c',
            data: const [
              DataPoint(0, 60),
              DataPoint(2, 120),
              DataPoint(4, 80),
              DataPoint(6, 240),
              DataPoint(7, 310),
            ],
          ),
        ],
        emphasis: const SeriesEmphasis(id: 'c'),
      ),
      Brightness.light,
      'series_emphasis_light',
    );
  });
}
