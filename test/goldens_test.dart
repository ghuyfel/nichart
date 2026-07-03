@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

const Size _chartSize = Size(600, 400);
const Key _boundaryKey = Key('golden-boundary');

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

List<DataPoint> get _thisPeriod => const [
      DataPoint(0, 120),
      DataPoint(1, 180),
      DataPoint(2, 95),
      DataPoint(3, 240),
      DataPoint(4, 205),
      DataPoint(5, 330),
      DataPoint(6, 290),
      DataPoint(7, 410),
    ];

List<DataPoint> get _lastPeriod => const [
      DataPoint(0, 140),
      DataPoint(1, 130),
      DataPoint(2, 160),
      DataPoint(3, 150),
      DataPoint(4, 235),
      DataPoint(5, 260),
      DataPoint(6, 305),
      DataPoint(7, 300),
    ];

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

void main() {
  testWidgets('line chart — light', (tester) async {
    await _expectGolden(
      tester,
      Chart.line(data: _thisPeriod),
      Brightness.light,
      'line_light',
    );
  });

  testWidgets('line chart — dark', (tester) async {
    await _expectGolden(
      tester,
      Chart.line(data: _thisPeriod),
      Brightness.dark,
      'line_dark',
    );
  });

  testWidgets('multi-series with context style — light', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        axes: const ChartAxes.cartesian(
          x: NumericAxis(label: 'Day'),
          y: NumericAxis(label: 'Users', min: 0),
        ),
        series: [
          LineSeries<DataPoint>(data: _thisPeriod, label: 'This week'),
          LineSeries<DataPoint>(
            data: _lastPeriod,
            label: 'Last week',
            style: const LineStyle.context(),
          ),
        ],
      ),
      Brightness.light,
      'multi_series_context_light',
    );
  });

  testWidgets('multi-series with context style — dark', (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          LineSeries<DataPoint>(data: _thisPeriod),
          LineSeries<DataPoint>(
            data: _lastPeriod,
            style: const LineStyle.context(),
          ),
        ],
      ),
      Brightness.dark,
      'multi_series_context_dark',
    );
  });

  testWidgets('three palette series, linear interpolation — light',
      (tester) async {
    await _expectGolden(
      tester,
      Chart(
        series: [
          LineSeries<DataPoint>(data: _thisPeriod),
          LineSeries<DataPoint>(data: _lastPeriod),
          LineSeries<DataPoint>(
            data: const [
              DataPoint(0, 60),
              DataPoint(2, 220),
              DataPoint(4, 90),
              DataPoint(7, 200),
            ],
            style: const LineStyle(
              interpolation: LineInterpolation.linear,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
      Brightness.light,
      'palette_linear_light',
    );
  });

  testWidgets('narrow chart decimates x labels — light', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B7CFA),
          ),
        ),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                width: 180,
                height: 120,
                color: Colors.white,
                child: Chart.line(data: _thisPeriod),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_boundaryKey),
      matchesGoldenFile('goldens/narrow_light.png'),
    );
  });
}
