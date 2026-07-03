import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

Widget _host(Widget chart, {Size size = const Size(600, 400)}) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: size.width, height: size.height, child: chart),
      ),
    ),
  );
}

List<CategoryPoint> get _weekdays => const [
      CategoryPoint('Mon', 12),
      CategoryPoint('Tue', 18),
      CategoryPoint('Wed', 9),
      CategoryPoint('Thu', 24),
      CategoryPoint('Fri', 21),
    ];

void main() {
  group('accessors', () {
    test('CategoryPoint gets default category and y accessors', () {
      final series = BarSeries<CategoryPoint>(data: _weekdays);
      expect(series.xAccessor, isNull);
      expect(series.categoryAccessor, isNotNull);
      expect(series.resolveCategoryPoints().first, ('Mon', 12.0));
    });

    test('resolvePoints throws a helpful error for categorical data', () {
      final series = BarSeries<CategoryPoint>(data: _weekdays);
      expect(series.resolvePoints, throwsArgumentError);
    });

    test('custom categoryAccessor maps domain models', () {
      final series = BarSeries<({String region, int sales})>(
        data: const [(region: 'EU', sales: 10), (region: 'US', sales: 20)],
        categoryAccessor: (d) => d.region,
        yAccessor: (d) => d.sales.toDouble(),
      );
      expect(series.resolveCategoryPoints(), [('EU', 10.0), ('US', 20.0)]);
    });
  });

  group('bar charts', () {
    testWidgets('render with only CategoryPoint data (axis inferred)',
        (tester) async {
      await tester.pumpWidget(
        _host(Chart(series: [BarSeries<CategoryPoint>(data: _weekdays)])),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('grouped bars with two series render', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              BarSeries<CategoryPoint>(data: _weekdays),
              BarSeries<CategoryPoint>(
                data: const [
                  CategoryPoint('Mon', 8),
                  CategoryPoint('Tue', 14),
                  CategoryPoint('Wed', 16),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacked bars with negative values render', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              BarSeries<CategoryPoint>(
                data: _weekdays,
                arrangement: BarArrangement.stacked,
              ),
              BarSeries<CategoryPoint>(
                data: const [
                  CategoryPoint('Mon', -4),
                  CategoryPoint('Tue', 6),
                  CategoryPoint('Wed', -2),
                  CategoryPoint('Thu', 5),
                  CategoryPoint('Fri', 3),
                ],
                arrangement: BarArrangement.stacked,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('single-bar emphasis renders', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              BarSeries<CategoryPoint>(data: _weekdays, emphasizedIndex: 3),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('bars on a numeric axis use the smallest x gap as band',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              BarSeries<DataPoint>(
                data: const [
                  DataPoint(0, 3),
                  DataPoint(1, 5),
                  DataPoint(2, 2),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('line over category bars (combo) renders', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            axes: const ChartAxes.cartesian(x: CategoryAxis()),
            series: [
              BarSeries<CategoryPoint>(data: _weekdays),
              LineSeries<DataPoint>(
                data: const [
                  DataPoint(0, 10),
                  DataPoint(1, 15),
                  DataPoint(2, 12),
                  DataPoint(3, 20),
                  DataPoint(4, 18),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('area and scatter', () {
    testWidgets('area series renders with defaults', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              AreaSeries<DataPoint>(
                data: const [
                  DataPoint(0, 2),
                  DataPoint(1, 5),
                  DataPoint(2, 3),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scatter series renders with defaults', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              ScatterSeries<DataPoint>(
                data: const [
                  DataPoint(1, 2),
                  DataPoint(2, 4),
                  DataPoint(3, 1),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('time axis', () {
    testWidgets('TimePoint data on a TimeAxis renders', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            axes: const ChartAxes.cartesian(x: TimeAxis()),
            series: [
              LineSeries<TimePoint>(
                data: [
                  TimePoint(DateTime(2026, 3, 1), 10),
                  TimePoint(DateTime(2026, 3, 2), 14),
                  TimePoint(DateTime(2026, 3, 3), 12),
                  TimePoint(DateTime(2026, 3, 4), 18),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('emphasis', () {
    testWidgets('series emphasis by id renders', (tester) async {
      final data = [
        for (var i = 0; i < 5; i++) DataPoint(i.toDouble(), (i * i).toDouble())
      ];
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              LineSeries<DataPoint>(data: data, id: 'a'),
              LineSeries<DataPoint>(data: data, id: 'b'),
            ],
            emphasis: const SeriesEmphasis(id: 'b'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('SeriesEmphasis requires a target', () {
      expect(SeriesEmphasis.new, throwsAssertionError);
    });
  });
}
