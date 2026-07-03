@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

const Size _chartSize = Size(600, 400);
const Key _boundaryKey = Key('golden-boundary-m3');

Widget _host(Widget chart) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B7CFA)),
    ),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: _chartSize.width,
            height: _chartSize.height,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: chart,
          ),
        ),
      ),
    ),
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

void main() {
  // Mid-animation states are deterministic in tests: the fake clock
  // advances exactly as far as pump() is told to.
  testWidgets('entrance mid-reveal — line with area', (tester) async {
    await tester.pumpWidget(_host(
      Chart(
        series: [AreaSeries<DataPoint>(data: _wave)],
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300)); // 50% of 600 ms.
    await expectLater(
      find.byKey(_boundaryKey),
      matchesGoldenFile('goldens/entrance_line_mid.png'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('entrance mid-growth — staggered bars', (tester) async {
    await tester.pumpWidget(_host(
      Chart(series: [BarSeries<CategoryPoint>(data: _weekdays)]),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byKey(_boundaryKey),
      matchesGoldenFile('goldens/entrance_bars_mid.png'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('morph mid-flight — line data change', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: _wave)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(Chart.line(
      data: const [
        DataPoint(0, 410),
        DataPoint(1, 95),
        DataPoint(2, 330),
        DataPoint(3, 120),
        DataPoint(4, 290),
        DataPoint(5, 180),
        DataPoint(6, 240),
        DataPoint(7, 205),
      ],
    )));
    await tester.pump(const Duration(milliseconds: 250)); // 50% of 500 ms.
    await expectLater(
      find.byKey(_boundaryKey),
      matchesGoldenFile('goldens/morph_line_mid.png'),
    );
    await tester.pumpAndSettle();
  });
}
